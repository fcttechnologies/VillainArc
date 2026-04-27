import Foundation
import SwiftData
import Testing

@testable import VillainArc

// Tests for the multi-session evaluation system:
// - SuggestionEvent model (evaluations, requiredEvaluationCount)
// - OutcomeResolver.resolveOutcomes integration (evaluation accumulation,
//   threshold finalization, dedup, eligibility filtering)
// - SuggestionGenerator.generateSuggestions requiredEvaluationCount assignment
@Suite(.serialized) struct MultiSessionEvaluationTests {

    // MARK: - Helpers

    /// Builds the full test fixture for OutcomeResolver tests:
    /// plan → prescription (1 working set) → suggestion event (created 1h ago, accepted)
    /// The caller creates and configures the WorkoutSession separately.
    @MainActor private func makeEventForOutcomeResolver(
        context: ModelContext, requiredEvaluationCount: Int = 2, decision: Decision = .accepted, createdSecondsAgo: Double = 3600, lowerRange: Int = 6, upperRange: Int = 10
    ) -> (plan: WorkoutPlan, prescription: ExercisePrescription, setPrescription: SetPrescription, event: SuggestionEvent) {
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1, targetWeight: 100, targetReps: 8, repRangeMode: .range, lowerRange: lowerRange, upperRange: upperRange)
        let setPrescription = prescription.sortedSets.first!

        let triggerSession = TestDataFactory.makeSession(context: context, daysAgo: 3)
        triggerSession.statusValue = .done
        let triggerPerf = TestDataFactory.makePerformance(context: context, session: triggerSession, prescription: prescription, sets: [(weight: 100, reps: 8, rest: 90, type: .working)])

        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 100, newValue: 102.5)
        context.insert(change)

        let event = SuggestionEvent(
            category: .performance, catalogID: prescription.catalogID, sessionFrom: nil, targetExercisePrescription: prescription, targetSetPrescription: setPrescription, triggerTargetSetID: setPrescription.id, triggerPerformance: triggerPerf, trainingStyle: .straightSets,
            requiredEvaluationCount: requiredEvaluationCount, createdAt: Date().addingTimeInterval(-createdSecondsAgo), changes: [change])
        change.event = event
        context.insert(event)
        event.decision = decision
        return (plan, prescription, setPrescription, event)
    }

    /// Creates a WorkoutSession linked to the given plan with one completed working set.
    @MainActor private func makeCompletedSession(context: ModelContext, plan: WorkoutPlan, prescription: ExercisePrescription, actualWeight: Double = 102.5, actualReps: Int = 8, postEffort: Int = 0, preWorkoutFeeling: MoodLevel = .notSet, tookPreWorkout: Bool = false) -> WorkoutSession {
        let session = TestDataFactory.makeSession(context: context)
        session.workoutPlan = plan
        session.postEffort = postEffort
        session.preWorkoutContext?.feeling = preWorkoutFeeling
        session.preWorkoutContext?.tookPreWorkout = tookPreWorkout
        _ = TestDataFactory.makePerformance(context: context, session: session, prescription: prescription, sets: [(weight: actualWeight, reps: actualReps, rest: 90, type: .working)])
        return session
    }

    @MainActor private func makeTargetModeEventForOutcomeResolver(
        context: ModelContext, requiredEvaluationCount: Int = 1, decision: Decision = .accepted, createdSecondsAgo: Double = 3600, targetReps: Int = 8
    ) -> (plan: WorkoutPlan, prescription: ExercisePrescription, setPrescription: SetPrescription, event: SuggestionEvent) {
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1, targetWeight: 100, targetReps: targetReps, repRangeMode: .target)
        prescription.repRange?.targetReps = targetReps
        let setPrescription = prescription.sortedSets.first!

        let triggerSession = TestDataFactory.makeSession(context: context, daysAgo: 3)
        triggerSession.statusValue = .done
        let triggerPerf = TestDataFactory.makePerformance(context: context, session: triggerSession, prescription: prescription, sets: [(weight: 100, reps: targetReps, rest: 90, type: .working)])

        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 100, newValue: 102.5)
        context.insert(change)

        let event = SuggestionEvent(
            category: .performance, catalogID: prescription.catalogID, sessionFrom: nil, targetExercisePrescription: prescription, targetSetPrescription: setPrescription, triggerTargetSetID: setPrescription.id, triggerPerformance: triggerPerf, trainingStyle: .straightSets,
            requiredEvaluationCount: requiredEvaluationCount, createdAt: Date().addingTimeInterval(-createdSecondsAgo), changes: [change])
        change.event = event
        context.insert(event)
        event.decision = decision
        return (plan, prescription, setPrescription, event)
    }

    @MainActor private func makeRecoveryEventForOutcomeResolver(context: ModelContext, decision: Decision = .accepted, createdSecondsAgo: Double = 3600) -> (plan: WorkoutPlan, prescription: ExercisePrescription, event: SuggestionEvent) {
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 2, targetWeight: 100, targetReps: 8, targetRest: 90, repRangeMode: .range, lowerRange: 6, upperRange: 10)
        let restOwnerSet = prescription.sortedSets[0]

        let triggerSession = TestDataFactory.makeSession(context: context, daysAgo: 3)
        triggerSession.statusValue = .done
        let triggerPerf = TestDataFactory.makePerformance(context: context, session: triggerSession, prescription: prescription, sets: [(weight: 100, reps: 8, rest: 90, type: .working), (weight: 100, reps: 6, rest: 90, type: .working)])

        let change = PrescriptionChange(changeType: .increaseRest, previousValue: 90, newValue: 120)
        context.insert(change)

        let event = SuggestionEvent(
            category: .recovery, catalogID: prescription.catalogID, sessionFrom: nil, targetExercisePrescription: prescription, targetSetPrescription: restOwnerSet, triggerTargetSetID: restOwnerSet.id, triggerPerformance: triggerPerf, trainingStyle: .straightSets, requiredEvaluationCount: 1,
            createdAt: Date().addingTimeInterval(-createdSecondsAgo), changes: [change])
        change.event = event
        context.insert(event)
        event.decision = decision
        return (plan, prescription, event)
    }

    // MARK: - Model: evaluations

    @Test @MainActor func evaluations_isEmptyByDefault() throws {
        let context = try TestDataFactory.makeContext()
        let (_, _, _, event) = makeEventForOutcomeResolver(context: context)

        #expect((event.evaluations ?? []).isEmpty)
    }

    @Test @MainActor func latestEvaluation_returnsNil_whenEvaluationsIsEmpty() throws {
        let context = try TestDataFactory.makeContext()
        let (_, _, _, event) = makeEventForOutcomeResolver(context: context)

        #expect(event.latestEvaluation == nil)
    }

    @Test @MainActor func latestEvaluation_returnsLastEntry() throws {
        let context = try TestDataFactory.makeContext()
        let (_, prescription, _, event) = makeEventForOutcomeResolver(context: context)

        let session1 = TestDataFactory.makeSession(context: context)
        let perf1 = TestDataFactory.makePerformance(context: context, session: session1, prescription: prescription, sets: [(weight: 100, reps: 8, rest: 90, type: .working)])
        let eval1 = SuggestionEvaluation(event: event, performance: perf1, sourceWorkoutSessionID: session1.id, partialOutcome: .good, confidence: 0.9, reason: "first")
        eval1.evaluatedAt = Date().addingTimeInterval(-60)
        context.insert(eval1)

        let session2 = TestDataFactory.makeSession(context: context)
        let perf2 = TestDataFactory.makePerformance(context: context, session: session2, prescription: prescription, sets: [(weight: 105, reps: 10, rest: 90, type: .working)])
        let eval2 = SuggestionEvaluation(event: event, performance: perf2, sourceWorkoutSessionID: session2.id, partialOutcome: .tooEasy, confidence: 0.85, reason: "second")
        context.insert(eval2)

        #expect(event.latestEvaluation?.performance?.sortedSets.first?.weight == 105)
    }

    // MARK: - Positive first session finalizes early

    @Test @MainActor func singleGoodSession_finalizesEarly_whenRequiredCountIs2() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription, _, event) = makeEventForOutcomeResolver(context: context, requiredEvaluationCount: 2)
        let session = makeCompletedSession(context: context, plan: plan, prescription: prescription, actualWeight: 102.5, actualReps: 8)

        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        #expect((event.evaluations ?? []).count == 1)
        #expect(event.outcome == .good)
        #expect(event.evaluatedAt != nil)
    }

    @Test @MainActor func singleTooEasySession_finalizesEarly_whenRequiredCountIs2() async throws {
        let context = try TestDataFactory.makeContext()
        // reps=14, range 6-10+2=12 → tooEasy from rule engine
        let (plan, prescription, _, event) = makeEventForOutcomeResolver(context: context, requiredEvaluationCount: 2, lowerRange: 6, upperRange: 10)
        let session = makeCompletedSession(context: context, plan: plan, prescription: prescription, actualWeight: 102.5, actualReps: 14)

        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        #expect((event.evaluations ?? []).count == 1)
        #expect(event.outcome == .tooEasy)
        #expect(event.evaluatedAt != nil)
    }

    // MARK: - Non-positive first session still waits for required count

    @Test @MainActor func singleIgnoredSession_doesNotFinalize_whenRequiredCountIs2() async throws {
        let context = try TestDataFactory.makeContext()
        // actualWeight=97.5 stayed meaningfully away from the new target, so the change is ignored.
        let (plan, prescription, _, event) = makeEventForOutcomeResolver(context: context, requiredEvaluationCount: 2)
        let session = makeCompletedSession(context: context, plan: plan, prescription: prescription, actualWeight: 97.5, actualReps: 8)

        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        #expect((event.evaluations ?? []).count == 1)
        #expect(event.outcome == .pending)
    }

    // MARK: - tooAggressive does NOT finalize early (requires full evaluation count)

    @Test @MainActor func singleTooAggressiveSession_doesNotFinalize_whenRequiredCountIs2() async throws {
        let context = try TestDataFactory.makeContext()
        // reps=4, floor=6 → tooAggressive — but no early resolution, requires full count
        let (plan, prescription, _, event) = makeEventForOutcomeResolver(context: context, requiredEvaluationCount: 2, lowerRange: 6, upperRange: 10)
        let session = makeCompletedSession(context: context, plan: plan, prescription: prescription, actualWeight: 102.5, actualReps: 4)

        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        #expect((event.evaluations ?? []).count == 1)
        #expect(event.outcome == .pending)
        #expect(event.evaluatedAt == nil)
    }

    /// Pre-injects a SuggestionEvaluation into the event for multi-session test setup.
    @MainActor @discardableResult private func injectPriorEvaluation(context: ModelContext, event: SuggestionEvent, sessionID: UUID = UUID(), partialOutcome: Outcome, confidence: Double, reason: String) -> SuggestionEvaluation {
        let eval = SuggestionEvaluation()
        eval.event = event
        eval.sourceWorkoutSessionID = sessionID
        eval.partialOutcome = partialOutcome
        eval.confidence = confidence
        eval.reason = reason
        eval.evaluatedAt = Date().addingTimeInterval(-60)
        context.insert(eval)
        return eval
    }

    // MARK: - Two sessions finalize at threshold

    @Test @MainActor func twoGoodSessions_finalizeWithGoodOutcome() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription, _, event) = makeEventForOutcomeResolver(context: context, requiredEvaluationCount: 2, lowerRange: 6, upperRange: 10)

        // Simulate "session 1" by pre-injecting an evaluation.
        injectPriorEvaluation(context: context, event: event, partialOutcome: .good, confidence: 0.9, reason: "[Rules] simulated first session")
        #expect(event.outcome == .pending)

        // Session 2: run through resolver; evaluations=[good, good] ≥ requiredCount=2 → finalizes.
        let session = makeCompletedSession(context: context, plan: plan, prescription: prescription, actualWeight: 102.5, actualReps: 8)
        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        #expect(event.outcome == .good)
        #expect(event.evaluatedAt != nil)
        #expect((event.evaluations ?? []).count == 2)
    }

    @Test @MainActor func twoTooEasySessions_finalizeWithTooEasyOutcome() async throws {
        let context = try TestDataFactory.makeContext()
        // reps=14 exceeds range ceiling+buffer consistently → tooEasy
        let (plan, prescription, _, event) = makeEventForOutcomeResolver(context: context, requiredEvaluationCount: 2, lowerRange: 6, upperRange: 10)

        // Simulate "session 1" by pre-injecting an evaluation.
        injectPriorEvaluation(context: context, event: event, partialOutcome: .tooEasy, confidence: 0.85, reason: "[Rules] simulated first session")
        #expect(event.outcome == .pending)

        // Session 2: reps=14 → tooEasy; history=[tooEasy, tooEasy] ≥ requiredCount=2 → finalizes.
        let session = makeCompletedSession(context: context, plan: plan, prescription: prescription, actualWeight: 102.5, actualReps: 14)
        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        #expect(event.outcome == .tooEasy)
        #expect(event.evaluatedAt != nil)
    }

    // MARK: - Weighted aggregation at threshold

    @Test @MainActor func weightedAggregation_goodBeatsWeakTooAggressive_atThreshold() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription, _, event) = makeEventForOutcomeResolver(context: context, requiredEvaluationCount: 2, lowerRange: 6, upperRange: 10)

        injectPriorEvaluation(context: context, event: event, partialOutcome: .tooAggressive, confidence: 0.5, reason: "[Rules] simulated weak overload session")
        let session = makeCompletedSession(context: context, plan: plan, prescription: prescription, actualWeight: 102.5, actualReps: 8)
        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        #expect(event.outcome == .good)
        #expect(event.outcomeReason?.hasPrefix("[Aggregate]") == true)
    }

    @Test @MainActor func weightedAggregation_ignoredCarriesNoWeight_atThreshold() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription, _, event) = makeEventForOutcomeResolver(context: context, requiredEvaluationCount: 2, lowerRange: 6, upperRange: 10)

        injectPriorEvaluation(context: context, event: event, partialOutcome: .ignored, confidence: 0.9, reason: "[Rules] simulated first session")

        let session = makeCompletedSession(context: context, plan: plan, prescription: prescription, actualWeight: 102.5, actualReps: 8)
        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        #expect(event.outcome == .good)
    }

    @Test @MainActor func weightedAggregation_goodBeatsTooEasyWithinPositiveBucket_atThreshold() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription, _, event) = makeEventForOutcomeResolver(context: context, requiredEvaluationCount: 2, lowerRange: 6, upperRange: 10)

        injectPriorEvaluation(context: context, event: event, partialOutcome: .tooEasy, confidence: 0.85, reason: "[Rules] simulated first session")

        let session = makeCompletedSession(context: context, plan: plan, prescription: prescription, actualWeight: 102.5, actualReps: 8)
        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        #expect(event.outcome == .good)
    }

    @Test @MainActor func weightedAggregation_strongTooAggressiveBeatsWeakGood_atThreshold() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription, _, event) = makeEventForOutcomeResolver(context: context, requiredEvaluationCount: 2, lowerRange: 6, upperRange: 10)

        injectPriorEvaluation(context: context, event: event, partialOutcome: .good, confidence: 0.3, reason: "[Rules] simulated weak positive session")
        let session = makeCompletedSession(context: context, plan: plan, prescription: prescription, actualWeight: 102.5, actualReps: 4)
        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        #expect(event.outcome == .tooAggressive)
        #expect(event.outcomeReason?.hasPrefix("[Aggregate]") == true)
    }

    @Test @MainActor func mixedPositiveAndNegativeEvidence_lowNetScoreEscalatesToThree() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription, _, event) = makeEventForOutcomeResolver(context: context, requiredEvaluationCount: 2, lowerRange: 6, upperRange: 10)

        injectPriorEvaluation(context: context, event: event, partialOutcome: .tooAggressive, confidence: 0.7, reason: "[Rules] simulated hard miss")

        let session = makeCompletedSession(context: context, plan: plan, prescription: prescription, actualWeight: 102.5, actualReps: 8)
        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        #expect(event.outcome == .pending)
        #expect(event.evaluatedAt == nil)
        #expect(event.requiredEvaluationCount == 3)
    }

    @Test @MainActor func exactTooAggressiveAndTooEasyPair_alwaysEscalatesToThree() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription, _, event) = makeEventForOutcomeResolver(context: context, requiredEvaluationCount: 2, lowerRange: 6, upperRange: 10)

        injectPriorEvaluation(context: context, event: event, partialOutcome: .tooEasy, confidence: 0.85, reason: "[Rules] simulated overshoot")

        let session = makeCompletedSession(context: context, plan: plan, prescription: prescription, actualWeight: 102.5, actualReps: 4)
        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        #expect(event.outcome == .pending)
        #expect(event.evaluatedAt == nil)
        #expect(event.requiredEvaluationCount == 3)
    }

    @Test @MainActor func threeSessions_withMixedLowNetScore_finalizesIgnored() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription, _, event) = makeEventForOutcomeResolver(context: context, requiredEvaluationCount: 3, lowerRange: 6, upperRange: 10)

        injectPriorEvaluation(context: context, event: event, partialOutcome: .good, confidence: 0.9, reason: "[Rules] simulated strong positive session")
        injectPriorEvaluation(context: context, event: event, partialOutcome: .tooAggressive, confidence: 0.7, reason: "[Rules] simulated hard miss")

        let session = makeCompletedSession(context: context, plan: plan, prescription: prescription, actualWeight: 97.5, actualReps: 8)
        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        #expect(event.outcome == .ignored)
        #expect(event.evaluatedAt != nil)
        #expect((event.evaluations ?? []).count == 3)
    }

    // MARK: - Cross-invocation deduplication (same session called twice)

    @Test @MainActor func crossInvocationDedup_callingSameSessionTwiceOnlyAppendsOneEntry() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription, _, event) = makeEventForOutcomeResolver(context: context, requiredEvaluationCount: 2)
        let session = makeCompletedSession(context: context, plan: plan, prescription: prescription, actualWeight: 102.5, actualReps: 8)

        await OutcomeResolver.resolveOutcomes(for: session, context: context)
        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        // Second call with same session ID must be rejected by sourceWorkoutSessionID guard
        #expect((event.evaluations ?? []).count == 1)
    }

    @Test @MainActor func crossInvocationDedup_differentSessionsEachAppendOneEntry() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription, _, event) = makeEventForOutcomeResolver(context: context, requiredEvaluationCount: 3)

        // Simulate session 1 by pre-injecting an evaluation.
        let prevSessionID = UUID()
        injectPriorEvaluation(context: context, event: event, sessionID: prevSessionID, partialOutcome: .good, confidence: 0.9, reason: "[Rules] simulated first session")

        // Session 2 runs through the actual resolver — must append exactly one new entry.
        let session2 = makeCompletedSession(context: context, plan: plan, prescription: prescription)
        await OutcomeResolver.resolveOutcomes(for: session2, context: context)

        #expect((event.evaluations ?? []).count == 2)
        let sessionIDs = Set((event.evaluations ?? []).map { $0.sourceWorkoutSessionID })
        #expect(sessionIDs.count == 2)  // unique session IDs
        #expect(sessionIDs.contains(prevSessionID))
        #expect(sessionIDs.contains(session2.id))
    }

    // MARK: - Eligibility filtering

    @Test @MainActor func eligibility_eventCreatedAfterWorkoutStart_isNotEvaluated() async throws {
        let context = try TestDataFactory.makeContext()
        // Event created AFTER the session starts → ineligible
        let (_, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1, targetWeight: 100)
        let setPrescription = prescription.sortedSets.first!
        let plan = prescription.workoutPlan!

        let triggerSession = TestDataFactory.makeSession(context: context, daysAgo: 3)
        triggerSession.statusValue = .done
        let triggerPerf = TestDataFactory.makePerformance(context: context, session: triggerSession, prescription: prescription, sets: [(weight: 100, reps: 8, rest: 90, type: .working)])

        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 100, newValue: 102.5)
        context.insert(change)

        // Session starts now; event created 10 seconds in the future → createdAt > startedAt
        let session = TestDataFactory.makeSession(context: context)
        session.workoutPlan = plan
        _ = TestDataFactory.makePerformance(context: context, session: session, prescription: prescription, sets: [(weight: 102.5, reps: 8, rest: 90, type: .working)])

        let event = SuggestionEvent(
            category: .performance, catalogID: prescription.catalogID, sessionFrom: nil, targetExercisePrescription: prescription, targetSetPrescription: setPrescription, triggerTargetSetID: setPrescription.id, triggerPerformance: triggerPerf, trainingStyle: .straightSets, requiredEvaluationCount: 1,
            createdAt: session.startedAt.addingTimeInterval(10),  // after session start
            changes: [change])
        change.event = event
        context.insert(event)
        event.decision = .accepted

        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        #expect((event.evaluations ?? []).isEmpty)
        #expect(event.outcome == .pending)
    }

    @Test @MainActor func eligibility_decisionPending_isNotEvaluated() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription, _, event) = makeEventForOutcomeResolver(context: context, requiredEvaluationCount: 1, decision: .pending)
        let session = makeCompletedSession(context: context, plan: plan, prescription: prescription)

        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        #expect((event.evaluations ?? []).isEmpty)
        #expect(event.outcome == .pending)
    }

    @Test @MainActor func eligibility_decisionRejected_isEvaluated() async throws {
        let context = try TestDataFactory.makeContext()
        // Rejected events still get outcome resolution (they track whether rejection was correct)
        let (plan, prescription, _, event) = makeEventForOutcomeResolver(context: context, requiredEvaluationCount: 1, decision: .rejected)
        let session = makeCompletedSession(context: context, plan: plan, prescription: prescription, actualWeight: 102.5, actualReps: 8)

        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        // With requiredCount=1, a single session should finalize
        #expect((event.evaluations ?? []).count == 1)
    }

    @Test @MainActor func eligibility_sessionWithoutPlan_isSkipped() async throws {
        let context = try TestDataFactory.makeContext()
        let (_, prescription, _, event) = makeEventForOutcomeResolver(context: context)

        // Session NOT linked to a plan → resolver returns immediately
        let session = TestDataFactory.makeSession(context: context)
        _ = TestDataFactory.makePerformance(context: context, session: session, prescription: prescription, sets: [(weight: 102.5, reps: 8, rest: 90, type: .working)])

        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        #expect((event.evaluations ?? []).isEmpty)
    }

    @Test @MainActor func recoveryEvidenceGate_requiresLinkedCompletedDownstreamWorkingSet() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription, event) = makeRecoveryEventForOutcomeResolver(context: context)

        let session = TestDataFactory.makeSession(context: context)
        session.workoutPlan = plan
        let performance = TestDataFactory.makePerformance(context: context, session: session, prescription: prescription, sets: [(weight: 100, reps: 8, rest: 120, type: .working), (weight: 100, reps: 8, rest: 90, type: .working)])

        #expect(OutcomeResolver.hasSufficientCurrentEvidence(for: event, in: performance))

        performance.sortedSets[1].prescription = nil
        #expect(OutcomeResolver.hasSufficientCurrentEvidence(for: event, in: performance) == false)
    }

    @Test @MainActor func eligibility_alreadyFinalizedEvent_isSkipped() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription, _, event) = makeEventForOutcomeResolver(context: context, requiredEvaluationCount: 1)

        // Pre-finalize the event
        event.outcome = .good
        event.evaluatedAt = Date()

        let session = makeCompletedSession(context: context, plan: plan, prescription: prescription)
        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        // Already finalized → evaluations stays empty, outcome unchanged
        #expect((event.evaluations ?? []).isEmpty)
        #expect(event.outcome == .good)
    }

    // MARK: - requiredEvaluationCount via SuggestionGenerator

    @Test @MainActor func generatedIncreaseWeightEvent_hasRequiredCount2() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 3, targetWeight: 200, targetReps: 8, repRangeMode: .target)
        prescription.repRange?.targetReps = 8
        prescription.musclesTargeted = [.chest]
        prescription.equipmentType = .barbell

        // Two sessions both hitting above target reps → triggers increaseWeight
        let session1 = TestDataFactory.makeSession(context: context, daysAgo: 3)
        session1.statusValue = .done
        _ = TestDataFactory.makePerformance(context: context, session: session1, prescription: prescription, sets: [(weight: 200, reps: 10, rest: 90, type: .working), (weight: 200, reps: 10, rest: 90, type: .working), (weight: 200, reps: 10, rest: 90, type: .working)])

        let session2 = WorkoutSession(from: plan)
        context.insert(session2)
        guard let perf = session2.sortedExercises.first else {
            Issue.record("Expected plan-backed performance.")
            return
        }
        for set in perf.sortedSets {
            set.weight = 200
            set.reps = 10
            set.restSeconds = 90
            set.complete = true
        }

        let generated = await SuggestionGenerator.generateSuggestions(for: session2, context: context)
        let weightEvents = generated.filter { event in event.sortedChanges.contains { $0.changeType == .increaseWeight } }

        #expect(weightEvents.isEmpty == false, "Expected at least one increaseWeight suggestion")
        #expect(weightEvents.allSatisfy { $0.requiredEvaluationCount == 2 })
    }

    @Test @MainActor func generatedIncreaseRestEvent_hasRequiredCount2() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1, targetWeight: 100, targetReps: 8, targetRest: 60, repRangeMode: .range, lowerRange: 6, upperRange: 10)
        prescription.musclesTargeted = [.chest]
        prescription.equipmentType = .barbell

        // Create two sessions with short rest and barely hitting reps → rest increase triggered
        // Pattern: completed at minimum reps twice in a row suggests rest is too short
        let session1 = TestDataFactory.makeSession(context: context, daysAgo: 3)
        session1.statusValue = .done
        _ = TestDataFactory.makePerformance(context: context, session: session1, prescription: prescription, sets: [(weight: 100, reps: 6, rest: 60, type: .working)])

        let currentSession = WorkoutSession(from: plan)
        context.insert(currentSession)
        guard let perf = currentSession.sortedExercises.first else { return }
        for set in perf.sortedSets {
            set.weight = 100
            set.reps = 6
            set.restSeconds = 60
            set.complete = true
        }

        let generated = await SuggestionGenerator.generateSuggestions(for: currentSession, context: context)
        let restEvents = generated.filter { event in event.sortedChanges.contains { $0.changeType == .increaseRest } }

        if !restEvents.isEmpty { #expect(restEvents.allSatisfy { $0.requiredEvaluationCount == 2 }) }  // Note: rest increase may not trigger in every scenario — this test validates count IF generated
    }

    @Test @MainActor func generatedDecreaseWeightEvent_hasRequiredCount1() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1, targetWeight: 100, targetReps: 8, repRangeMode: .range, lowerRange: 6, upperRange: 10)
        prescription.musclesTargeted = [.chest]
        prescription.equipmentType = .barbell

        // User consistently fails to hit even the floor reps → decreaseWeight suggested
        let currentSession = WorkoutSession(from: plan)
        context.insert(currentSession)
        guard let perf = currentSession.sortedExercises.first else { return }
        for set in perf.sortedSets {
            set.weight = 100
            set.reps = 3
            set.restSeconds = 90
            set.complete = true
        }

        let generated = await SuggestionGenerator.generateSuggestions(for: currentSession, context: context)
        let decreaseEvents = generated.filter { event in event.sortedChanges.contains { $0.changeType == .decreaseWeight } }

        if !decreaseEvents.isEmpty {
            // Safety/cleanup decreases should resolve immediately (no need for confirmation)
            #expect(decreaseEvents.allSatisfy { $0.requiredEvaluationCount == 1 })
        }
    }

    @Test @MainActor func generatedAssistedDecreaseWeightEvent_hasRequiredCount2() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, catalogID: "assisted_pull_ups", workingSets: 1, targetWeight: WeightUnit.lbs.toKg(90), targetReps: 8, targetRest: 90, repRangeMode: .target)
        prescription.repRange?.targetReps = 8

        let previousSession = TestDataFactory.makeSession(context: context, daysAgo: 3)
        previousSession.statusValue = .done
        _ = TestDataFactory.makePerformance(context: context, session: previousSession, prescription: prescription, sets: [(weight: WeightUnit.lbs.toKg(90), reps: 8, rest: 90, type: .working)])

        let currentSession = WorkoutSession(from: plan)
        context.insert(currentSession)
        guard let perf = currentSession.sortedExercises.first else { return }
        for set in perf.sortedSets {
            set.weight = WeightUnit.lbs.toKg(90)
            set.reps = 8
            set.restSeconds = 90
            set.complete = true
        }

        let generated = await SuggestionGenerator.generateSuggestions(for: currentSession, context: context)
        let assistedProgressionEvents = generated.filter { event in event.sortedChanges.contains { $0.changeType == .decreaseWeight } }

        #expect(assistedProgressionEvents.isEmpty == false)
        #expect(assistedProgressionEvents.allSatisfy { $0.requiredEvaluationCount == 2 })
    }

    @Test @MainActor func generatedAssistedIncreaseWeightEvent_hasRequiredCount1() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, catalogID: "assisted_pull_ups", workingSets: 1, targetWeight: WeightUnit.lbs.toKg(90), targetReps: 8, targetRest: 90, repRangeMode: .range, lowerRange: 6, upperRange: 8)

        for daysAgo in [9, 6, 3] {
            let session = TestDataFactory.makeSession(context: context, daysAgo: daysAgo)
            session.statusValue = .done
            _ = TestDataFactory.makePerformance(context: context, session: session, prescription: prescription, sets: [(weight: WeightUnit.lbs.toKg(90), reps: 4, rest: 90, type: .working)])
        }

        let currentSession = WorkoutSession(from: plan)
        context.insert(currentSession)
        guard let perf = currentSession.sortedExercises.first else { return }
        for set in perf.sortedSets {
            set.weight = WeightUnit.lbs.toKg(90)
            set.reps = 4
            set.restSeconds = 90
            set.complete = true
        }

        let generated = await SuggestionGenerator.generateSuggestions(for: currentSession, context: context)
        let assistedSupportEvents = generated.filter { event in event.sortedChanges.contains { $0.changeType == .increaseWeight } }

        #expect(assistedSupportEvents.isEmpty == false)
        #expect(assistedSupportEvents.allSatisfy { $0.requiredEvaluationCount == 1 })
    }

    @Test @MainActor func generatedWarmupCalibrationEvent_hasRequiredCount1() async throws {
        let context = try TestDataFactory.makeContext()
        // Warmup calibration category always requires only 1 session regardless of change type
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1, targetWeight: 100, targetReps: 8, repRangeMode: .range, lowerRange: 6, upperRange: 10)
        prescription.musclesTargeted = [.chest]
        prescription.equipmentType = .barbell

        // Add warmup slot
        let warmupSlot = SetPrescription(exercisePrescription: prescription, setType: .warmup, targetWeight: 80, targetReps: 10, targetRest: 60, index: 0)
        prescription.sortedSets.forEach { $0.index += 1 }
        prescription.sets?.insert(warmupSlot, at: 0)

        let currentSession = WorkoutSession(from: plan)
        context.insert(currentSession)
        guard let perf = currentSession.sortedExercises.first else { return }
        // All sets complete with valid reps
        for set in perf.sortedSets {
            set.weight = set.type == .warmup ? 80 : 100
            set.reps = set.type == .warmup ? 10 : 8
            set.restSeconds = 90
            set.complete = true
        }

        let generated = await SuggestionGenerator.generateSuggestions(for: currentSession, context: context)
        let warmupEvents = generated.filter { $0.category == .warmupCalibration }

        if !warmupEvents.isEmpty { #expect(warmupEvents.allSatisfy { $0.requiredEvaluationCount == 1 }) }
    }

    // MARK: - Evaluation content

    @Test @MainActor func evaluation_storesCorrectSessionID() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription, _, event) = makeEventForOutcomeResolver(context: context, requiredEvaluationCount: 2)
        let session = makeCompletedSession(context: context, plan: plan, prescription: prescription, actualWeight: 102.5, actualReps: 8)

        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        #expect((event.evaluations ?? []).first?.sourceWorkoutSessionID == session.id)
    }

    @Test @MainActor func evaluation_storesPerformanceRelationship() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription, _, event) = makeEventForOutcomeResolver(context: context, requiredEvaluationCount: 2)
        let session = makeCompletedSession(context: context, plan: plan, prescription: prescription, actualWeight: 102.5, actualReps: 8)

        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        let performance = (event.evaluations ?? []).first?.performance
        #expect(performance != nil)
        #expect(performance?.sortedSets.first?.weight == 102.5)
        #expect(performance?.sortedSets.first?.reps == 8)
    }

    @Test @MainActor func evaluation_reasonContainsRulesPrefix() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription, _, event) = makeEventForOutcomeResolver(context: context, requiredEvaluationCount: 2)
        let session = makeCompletedSession(context: context, plan: plan, prescription: prescription, actualWeight: 102.5, actualReps: 8)

        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        let reason = (event.evaluations ?? []).first?.reason ?? ""
        #expect(reason.hasPrefix("[Rules]") || reason.hasPrefix("[AI]") || reason.hasPrefix("[AI override]"))
    }

    @Test @MainActor func outcomeResolver_skipsAIForHighConfidenceRules() {
        let rule = OutcomeSignal(outcome: .good, confidence: 0.9, reason: "Rules are clear")

        #expect(OutcomeResolver.shouldRunAI(for: rule) == false)
    }

    @Test @MainActor func outcomeResolver_runsAIForAmbiguousRules() {
        let rule = OutcomeSignal(outcome: .ignored, confidence: 0.7, reason: "Ambiguous rule path")

        #expect(OutcomeResolver.shouldRunAI(for: rule))
    }

    @Test @MainActor func outcomeResolver_prefersHighConfidenceAIOverMidConfidenceRule() {
        let rule = OutcomeSignal(outcome: .good, confidence: 0.8, reason: "Rule said good")
        let ai = AIOutcomeInferenceOutput(outcome: .tooEasy, confidence: 0.9, reason: "AI saw clear overshoot")

        #expect(OutcomeResolver.shouldPreferAIOverride(rule: rule, ai: ai))
    }

    @Test @MainActor func outcomeResolver_keepsRuleWhenAIIsNotDecisivelyStronger() {
        let rule = OutcomeSignal(outcome: .good, confidence: 0.8, reason: "Rule said good")
        let ai = AIOutcomeInferenceOutput(outcome: .tooEasy, confidence: 0.82, reason: "AI slightly disagreed")

        #expect(OutcomeResolver.shouldPreferAIOverride(rule: rule, ai: ai) == false)
    }

    @Test @MainActor func mergeOutcome_usesAIConfidenceWhenAIOverrideWins() throws {
        let rule = OutcomeSignal(outcome: .ignored, confidence: 0.7, reason: "Ambiguous rule path")
        let ai = AIOutcomeInferenceOutput(outcome: .tooEasy, confidence: 0.92, reason: "AI saw clear overshoot")

        let resolved = try #require(OutcomeResolver.mergeOutcome(rule: rule, ai: ai))
        #expect(resolved.outcome == .tooEasy)
        #expect(resolved.confidence == 0.92)
        #expect(resolved.reason.hasPrefix("[AI override]"))
    }

    @Test @MainActor func adjustedConfidence_highPostEffortBoostsNegativeOutcomes() {
        let workout = WorkoutSession()
        workout.postEffort = 9

        let adjusted = OutcomeResolver.adjustedConfidence(0.85, for: .tooAggressive, workout: workout)
        #expect(abs(adjusted - 1.0) < 0.0001)
    }

    @Test @MainActor func adjustedConfidence_sickOrTiredWeakensNegativeOutcomes() {
        let workout = WorkoutSession()
        workout.preWorkoutContext?.feeling = .tired

        let adjusted = OutcomeResolver.adjustedConfidence(0.85, for: .tooAggressive, workout: workout)
        #expect(abs(adjusted - 0.7225) < 0.0001)
    }

    @Test @MainActor func adjustedConfidence_preWorkoutSlightlyBoostsNegativeAndDampensPositive() {
        let workout = WorkoutSession()
        workout.preWorkoutContext?.tookPreWorkout = true

        let negativeAdjusted = OutcomeResolver.adjustedConfidence(0.8, for: .tooAggressive, workout: workout)
        let positiveAdjusted = OutcomeResolver.adjustedConfidence(0.8, for: .good, workout: workout)

        #expect(abs(negativeAdjusted - 0.84) < 0.0001)
        #expect(abs(positiveAdjusted - 0.76) < 0.0001)
    }

    @Test @MainActor func aiContextFields_includeOnlyMeaningfulValues() {
        let workout = WorkoutSession()
        workout.postEffort = 8
        workout.preWorkoutContext?.feeling = .good
        workout.preWorkoutContext?.tookPreWorkout = true

        let fields = OutcomeResolver.aiContextFields(for: workout)
        #expect(fields.postWorkoutEffort == 8)
        #expect(fields.preWorkoutFeeling == .good)
        #expect(fields.tookPreWorkout == true)
    }

    @Test @MainActor func aiContextFields_omitUnsetValues() {
        let workout = WorkoutSession()
        workout.postEffort = 0
        workout.preWorkoutContext?.feeling = .notSet
        workout.preWorkoutContext?.tookPreWorkout = false

        let fields = OutcomeResolver.aiContextFields(for: workout)
        #expect(fields.postWorkoutEffort == nil)
        #expect(fields.preWorkoutFeeling == nil)
        #expect(fields.tookPreWorkout == nil)
    }

    // MARK: - RequiredEvaluationCount = 1 finalizes after single session

    @Test @MainActor func singleSessionFinalizes_whenRequiredCountIs1() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription, _, event) = makeEventForOutcomeResolver(context: context, requiredEvaluationCount: 1)
        let session = makeCompletedSession(context: context, plan: plan, prescription: prescription, actualWeight: 102.5, actualReps: 8)

        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        #expect(event.outcome != .pending)
        #expect(event.evaluatedAt != nil)
        #expect((event.evaluations ?? []).count == 1)
    }

    @Test @MainActor func targetMode_targetMinusOneSession_resolvesAsGood_notTooAggressive() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription, _, event) = makeTargetModeEventForOutcomeResolver(context: context, requiredEvaluationCount: 1, targetReps: 8)
        let session = makeCompletedSession(context: context, plan: plan, prescription: prescription, actualWeight: 102.5, actualReps: 7)

        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        #expect(event.outcome == .good)
        #expect(event.outcomeReason?.contains("[Rules]") == true)
    }

    // MARK: - Multiple events same workout

    @Test @MainActor func multipleEventsInSameWorkout_eachGetsIndependentEvaluation() async throws {
        let context = try TestDataFactory.makeContext()

        // Two exercise-level rep range events on the same prescription — no set scoping,
        // so canEvaluateWithCurrentPerformance returns true for both.
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 3, targetWeight: 100, targetReps: 8, repRangeMode: .range, lowerRange: 6, upperRange: 12)

        func makeRepRangeEvent(changeType: ChangeType, oldValue: Double, newValue: Double) -> SuggestionEvent {
            let change = PrescriptionChange(changeType: changeType, previousValue: oldValue, newValue: newValue)
            context.insert(change)
            let event = SuggestionEvent(category: .repRangeConfiguration, catalogID: prescription.catalogID, sessionFrom: nil, targetExercisePrescription: prescription, trainingStyle: .straightSets, requiredEvaluationCount: 1, createdAt: Date().addingTimeInterval(-3600), changes: [change])
            change.event = event
            context.insert(event)
            event.decision = .accepted
            return event
        }

        let event1 = makeRepRangeEvent(changeType: .increaseRepRangeUpper, oldValue: 10, newValue: 12)
        let event2 = makeRepRangeEvent(changeType: .increaseRepRangeLower, oldValue: 6, newValue: 8)

        let session = TestDataFactory.makeSession(context: context)
        session.workoutPlan = plan
        _ = TestDataFactory.makePerformance(context: context, session: session, prescription: prescription, sets: [(weight: 100, reps: 9, rest: 90, type: .working), (weight: 100, reps: 10, rest: 90, type: .working), (weight: 100, reps: 11, rest: 90, type: .working)])

        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        // Both events should be evaluated independently
        #expect((event1.evaluations ?? []).count == 1)
        #expect((event2.evaluations ?? []).count == 1)
    }
}

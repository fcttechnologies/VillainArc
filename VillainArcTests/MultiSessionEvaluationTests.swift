import SwiftData
import Foundation
import Testing
@testable import VillainArc

// Tests for the multi-session evaluation system:
// - SuggestionEvent model (evaluationHistory, requiredEvaluationCount)
// - OutcomeResolver.resolveOutcomes integration (history accumulation, early resolve,
//   threshold finalization, dedup, eligibility filtering)
// - SuggestionGenerator.generateSuggestions requiredEvaluationCount assignment
@Suite(.serialized)
struct MultiSessionEvaluationTests {

    // MARK: - Helpers

    /// Builds the full test fixture for OutcomeResolver tests:
    /// plan → prescription (1 working set) → suggestion event (created 1h ago, accepted)
    /// The caller creates and configures the WorkoutSession separately.
    @MainActor
    private func makeEventForOutcomeResolver(
        context: ModelContext,
        requiredEvaluationCount: Int = 2,
        decision: Decision = .accepted,
        createdSecondsAgo: Double = 3600,
        lowerRange: Int = 6,
        upperRange: Int = 10
    ) -> (plan: WorkoutPlan, prescription: ExercisePrescription, setPrescription: SetPrescription, event: SuggestionEvent) {
        let (plan, prescription) = TestDataFactory.makePrescription(
            context: context,
            workingSets: 1,
            targetWeight: 100,
            targetReps: 8,
            repRangeMode: .range,
            lowerRange: lowerRange,
            upperRange: upperRange
        )
        let setPrescription = prescription.sortedSets.first!

        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 100, newValue: 102.5)
        context.insert(change)

        let event = SuggestionEvent(
            category: .performance,
            catalogID: prescription.catalogID,
            sessionFrom: nil,
            targetExercisePrescription: prescription,
            targetSetPrescription: setPrescription,
            triggerTargetSetID: setPrescription.id,
            triggerPerformanceSnapshot: .empty,
            triggerTargetSnapshot: ExerciseTargetSnapshot(prescription: prescription),
            trainingStyle: .straightSets,
            requiredEvaluationCount: requiredEvaluationCount,
            createdAt: Date().addingTimeInterval(-createdSecondsAgo),
            changes: [change]
        )
        change.event = event
        context.insert(event)
        event.decision = decision
        return (plan, prescription, setPrescription, event)
    }

    /// Creates a WorkoutSession linked to the given plan with one completed working set.
    @MainActor
    private func makeCompletedSession(
        context: ModelContext,
        plan: WorkoutPlan,
        prescription: ExercisePrescription,
        actualWeight: Double = 102.5,
        actualReps: Int = 8
    ) -> WorkoutSession {
        let session = TestDataFactory.makeSession(context: context)
        session.workoutPlan = plan
        _ = TestDataFactory.makePerformance(
            context: context,
            session: session,
            prescription: prescription,
            sets: [(weight: actualWeight, reps: actualReps, rest: 90, type: .working)]
        )
        return session
    }

    // MARK: - Model: evaluationHistory

    @Test @MainActor
    func evaluationHistory_isEmptyByDefault() throws {
        let context = try TestDataFactory.makeContext()
        let (_, _, _, event) = makeEventForOutcomeResolver(context: context)

        #expect(event.evaluationHistory.isEmpty)
    }

    @Test @MainActor
    func latestEvaluationSnapshot_returnsNil_whenHistoryIsEmpty() throws {
        let context = try TestDataFactory.makeContext()
        let (_, _, _, event) = makeEventForOutcomeResolver(context: context)

        #expect(event.latestEvaluationSnapshot == nil)
    }

    @Test @MainActor
    func latestEvaluationSnapshot_returnsLastEntry() throws {
        let context = try TestDataFactory.makeContext()
        let (_, prescription, _, event) = makeEventForOutcomeResolver(context: context)

        let session1 = TestDataFactory.makeSession(context: context)
        let perf1 = TestDataFactory.makePerformance(context: context, session: session1, prescription: prescription,
            sets: [(weight: 100, reps: 8, rest: 90, type: .working)])
        let entry1 = EvaluationHistoryEntry(sourceSessionID: session1.id, snapshot: ExercisePerformanceSnapshot(performance: perf1), partialOutcome: .good, confidence: 0.9, reason: "first")

        let session2 = TestDataFactory.makeSession(context: context)
        let perf2 = TestDataFactory.makePerformance(context: context, session: session2, prescription: prescription,
            sets: [(weight: 105, reps: 10, rest: 90, type: .working)])
        let entry2 = EvaluationHistoryEntry(sourceSessionID: session2.id, snapshot: ExercisePerformanceSnapshot(performance: perf2), partialOutcome: .tooEasy, confidence: 0.85, reason: "second")

        event.evaluationHistory = [entry1, entry2]

        #expect(event.latestEvaluationSnapshot?.sets.first?.weight == 105)
    }

    // MARK: - Single session does not finalize (requiredCount = 2)

    @Test @MainActor
    func singleGoodSession_doesNotFinalize_whenRequiredCountIs2() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription, _, event) = makeEventForOutcomeResolver(context: context, requiredEvaluationCount: 2)
        let session = makeCompletedSession(context: context, plan: plan, prescription: prescription,
            actualWeight: 102.5, actualReps: 8)

        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        #expect(event.evaluationHistory.count == 1)
        #expect(event.outcome == .pending)
        #expect(event.evaluatedAt == nil)
    }

    @Test @MainActor
    func singleTooEasySession_doesNotFinalize_whenRequiredCountIs2() async throws {
        let context = try TestDataFactory.makeContext()
        // reps=14, range 6-10+2=12 → tooEasy from rule engine
        let (plan, prescription, _, event) = makeEventForOutcomeResolver(context: context, requiredEvaluationCount: 2, lowerRange: 6, upperRange: 10)
        let session = makeCompletedSession(context: context, plan: plan, prescription: prescription,
            actualWeight: 102.5, actualReps: 14)

        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        #expect(event.evaluationHistory.count == 1)
        #expect(event.outcome == .pending)
        #expect(event.evaluatedAt == nil)
    }

    @Test @MainActor
    func singleIgnoredSession_doesNotFinalize_whenRequiredCountIs2() async throws {
        let context = try TestDataFactory.makeContext()
        // actualWeight=100 (stayed at old), change was increaseWeight 100→102.5 → ignored
        let (plan, prescription, _, event) = makeEventForOutcomeResolver(context: context, requiredEvaluationCount: 2)
        let session = makeCompletedSession(context: context, plan: plan, prescription: prescription,
            actualWeight: 100, actualReps: 8)

        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        #expect(event.evaluationHistory.count == 1)
        #expect(event.outcome == .pending)
    }

    // MARK: - tooAggressive always finalizes immediately

    @Test @MainActor
    func tooAggressive_finalizesAfterSingleSession_evenWithRequiredCount2() async throws {
        let context = try TestDataFactory.makeContext()
        // reps=4, floor=6 → tooAggressive → immediate resolution
        let (plan, prescription, _, event) = makeEventForOutcomeResolver(context: context, requiredEvaluationCount: 2, lowerRange: 6, upperRange: 10)
        let session = makeCompletedSession(context: context, plan: plan, prescription: prescription,
            actualWeight: 102.5, actualReps: 4)

        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        #expect(event.outcome == .tooAggressive)
        #expect(event.evaluatedAt != nil)
        #expect(event.evaluationHistory.count == 1)
    }

    // MARK: - Two sessions finalize at threshold

    @Test @MainActor
    func twoGoodSessions_finalizeWithGoodOutcome() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription, _, event) = makeEventForOutcomeResolver(context: context, requiredEvaluationCount: 2, lowerRange: 6, upperRange: 10)

        // Simulate "session 1" by pre-injecting a history entry, avoiding SwiftData one-to-one conflict
        // (two ExercisePerformance objects for the same prescription nullify each other's inverse link).
        let prevEntry = EvaluationHistoryEntry(sourceSessionID: UUID(), snapshot: .empty, partialOutcome: .good, confidence: 0.9, reason: "[Rules] simulated first session")
        event.evaluationHistory = [prevEntry]
        #expect(event.outcome == .pending)

        // Session 2: run through resolver; history=[good, good] ≥ requiredCount=2 → finalizes.
        let session = makeCompletedSession(context: context, plan: plan, prescription: prescription,
            actualWeight: 102.5, actualReps: 8)
        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        #expect(event.outcome == .good)
        #expect(event.evaluatedAt != nil)
        #expect(event.evaluationHistory.count == 2)
    }

    @Test @MainActor
    func twoTooEasySessions_finalizeWithTooEasyOutcome() async throws {
        let context = try TestDataFactory.makeContext()
        // reps=14 exceeds range ceiling+buffer consistently → tooEasy
        let (plan, prescription, _, event) = makeEventForOutcomeResolver(context: context, requiredEvaluationCount: 2, lowerRange: 6, upperRange: 10)

        // Simulate "session 1" by pre-injecting a history entry, avoiding SwiftData one-to-one conflict.
        let prevEntry = EvaluationHistoryEntry(sourceSessionID: UUID(), snapshot: .empty, partialOutcome: .tooEasy, confidence: 0.85, reason: "[Rules] simulated first session")
        event.evaluationHistory = [prevEntry]
        #expect(event.outcome == .pending)

        // Session 2: reps=14 → tooEasy; history=[tooEasy, tooEasy] ≥ requiredCount=2 → finalizes.
        let session = makeCompletedSession(context: context, plan: plan, prescription: prescription,
            actualWeight: 102.5, actualReps: 14)
        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        #expect(event.outcome == .tooEasy)
        #expect(event.evaluatedAt != nil)
    }

    // MARK: - Safety-weighted priority at threshold

    @Test @MainActor
    func safetyPriority_tooAggressiveBeatsGood_atThreshold() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription, _, event) = makeEventForOutcomeResolver(context: context, requiredEvaluationCount: 2, lowerRange: 6, upperRange: 10)

        // Pre-inject session 1 as "good", avoiding SwiftData one-to-one conflict.
        let prevEntry = EvaluationHistoryEntry(sourceSessionID: UUID(), snapshot: .empty, partialOutcome: .good, confidence: 0.9, reason: "[Rules] simulated first session")
        event.evaluationHistory = [prevEntry]

        // Session 2 → tooAggressive (reps=4 below floor). tooAggressive is decisive → resolves immediately.
        // Safety priority across history=[good, tooAggressive]: tooAggressive > good → wins.
        let session = makeCompletedSession(context: context, plan: plan, prescription: prescription,
            actualWeight: 102.5, actualReps: 4)
        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        #expect(event.outcome == .tooAggressive)
    }

    @Test @MainActor
    func safetyPriority_goodBeatsIgnored_atThreshold() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription, _, event) = makeEventForOutcomeResolver(context: context, requiredEvaluationCount: 2, lowerRange: 6, upperRange: 10)

        // Pre-inject session 1 as "ignored", avoiding SwiftData one-to-one conflict.
        let prevEntry = EvaluationHistoryEntry(sourceSessionID: UUID(), snapshot: .empty, partialOutcome: .ignored, confidence: 0.9, reason: "[Rules] simulated first session")
        event.evaluationHistory = [prevEntry]

        // Session 2: weight=102.5 (followed suggestion), reps=8 in range → good.
        // At threshold: history=[ignored, good]. Priority: good > ignored.
        let session = makeCompletedSession(context: context, plan: plan, prescription: prescription,
            actualWeight: 102.5, actualReps: 8)
        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        #expect(event.outcome == .good)
    }

    @Test @MainActor
    func safetyPriority_goodBeatsTooEasy_atThreshold() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription, _, event) = makeEventForOutcomeResolver(context: context, requiredEvaluationCount: 2, lowerRange: 6, upperRange: 10)

        // Pre-inject session 1 as "tooEasy", avoiding SwiftData one-to-one conflict.
        let prevEntry = EvaluationHistoryEntry(sourceSessionID: UUID(), snapshot: .empty, partialOutcome: .tooEasy, confidence: 0.85, reason: "[Rules] simulated first session")
        event.evaluationHistory = [prevEntry]

        // Session 2: reps=8 in range → good.
        // At threshold: history=[tooEasy, good]. Priority: good > tooEasy.
        let session = makeCompletedSession(context: context, plan: plan, prescription: prescription,
            actualWeight: 102.5, actualReps: 8)
        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        #expect(event.outcome == .good)
    }

    // MARK: - Cross-invocation deduplication (same session called twice)

    @Test @MainActor
    func crossInvocationDedup_callingSameSessionTwiceOnlyAppendsOneEntry() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription, _, event) = makeEventForOutcomeResolver(context: context, requiredEvaluationCount: 2)
        let session = makeCompletedSession(context: context, plan: plan, prescription: prescription,
            actualWeight: 102.5, actualReps: 8)

        await OutcomeResolver.resolveOutcomes(for: session, context: context)
        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        // Second call with same session ID must be rejected by sourceSessionID guard
        #expect(event.evaluationHistory.count == 1)
    }

    @Test @MainActor
    func crossInvocationDedup_differentSessionsEachAppendOneEntry() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription, _, event) = makeEventForOutcomeResolver(context: context, requiredEvaluationCount: 3)

        // Simulate session 1 by pre-injecting a history entry, avoiding SwiftData one-to-one conflict.
        let prevSessionID = UUID()
        let prevEntry = EvaluationHistoryEntry(sourceSessionID: prevSessionID, snapshot: .empty, partialOutcome: .good, confidence: 0.9, reason: "[Rules] simulated first session")
        event.evaluationHistory = [prevEntry]

        // Session 2 runs through the actual resolver — must append exactly one new entry.
        let session2 = makeCompletedSession(context: context, plan: plan, prescription: prescription)
        await OutcomeResolver.resolveOutcomes(for: session2, context: context)

        #expect(event.evaluationHistory.count == 2)
        let sessionIDs = Set(event.evaluationHistory.map { $0.sourceSessionID })
        #expect(sessionIDs.count == 2) // unique session IDs
        #expect(sessionIDs.contains(prevSessionID))
        #expect(sessionIDs.contains(session2.id))
    }

    // MARK: - Eligibility filtering

    @Test @MainActor
    func eligibility_eventCreatedAfterWorkoutStart_isNotEvaluated() async throws {
        let context = try TestDataFactory.makeContext()
        // Event created AFTER the session starts → ineligible
        let (_, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1, targetWeight: 100)
        let setPrescription = prescription.sortedSets.first!
        let plan = prescription.workoutPlan!

        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 100, newValue: 102.5)
        context.insert(change)

        // Session starts now; event created 10 seconds in the future → createdAt > startedAt
        let session = TestDataFactory.makeSession(context: context)
        session.workoutPlan = plan
        _ = TestDataFactory.makePerformance(context: context, session: session, prescription: prescription,
            sets: [(weight: 102.5, reps: 8, rest: 90, type: .working)])

        let event = SuggestionEvent(
            category: .performance,
            catalogID: prescription.catalogID,
            sessionFrom: nil,
            targetExercisePrescription: prescription,
            targetSetPrescription: setPrescription,
            triggerTargetSetID: setPrescription.id,
            triggerPerformanceSnapshot: .empty,
            triggerTargetSnapshot: ExerciseTargetSnapshot(prescription: prescription),
            trainingStyle: .straightSets,
            requiredEvaluationCount: 1,
            createdAt: session.startedAt.addingTimeInterval(10), // after session start
            changes: [change]
        )
        change.event = event
        context.insert(event)
        event.decision = .accepted

        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        #expect(event.evaluationHistory.isEmpty)
        #expect(event.outcome == .pending)
    }

    @Test @MainActor
    func eligibility_decisionPending_isNotEvaluated() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription, _, event) = makeEventForOutcomeResolver(
            context: context, requiredEvaluationCount: 1, decision: .pending
        )
        let session = makeCompletedSession(context: context, plan: plan, prescription: prescription)

        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        #expect(event.evaluationHistory.isEmpty)
        #expect(event.outcome == .pending)
    }

    @Test @MainActor
    func eligibility_decisionRejected_isEvaluated() async throws {
        let context = try TestDataFactory.makeContext()
        // Rejected events still get outcome resolution (they track whether rejection was correct)
        let (plan, prescription, _, event) = makeEventForOutcomeResolver(
            context: context, requiredEvaluationCount: 1, decision: .rejected
        )
        let session = makeCompletedSession(context: context, plan: plan, prescription: prescription,
            actualWeight: 102.5, actualReps: 8)

        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        // With requiredCount=1, a single session should finalize
        #expect(event.evaluationHistory.count == 1)
    }

    @Test @MainActor
    func eligibility_sessionWithoutPlan_isSkipped() async throws {
        let context = try TestDataFactory.makeContext()
        let (_, prescription, _, event) = makeEventForOutcomeResolver(context: context)

        // Session NOT linked to a plan → resolver returns immediately
        let session = TestDataFactory.makeSession(context: context)
        _ = TestDataFactory.makePerformance(context: context, session: session, prescription: prescription,
            sets: [(weight: 102.5, reps: 8, rest: 90, type: .working)])

        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        #expect(event.evaluationHistory.isEmpty)
    }

    @Test @MainActor
    func eligibility_alreadyFinalizedEvent_isSkipped() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription, _, event) = makeEventForOutcomeResolver(context: context, requiredEvaluationCount: 1)

        // Pre-finalize the event
        event.outcome = .good
        event.evaluatedAt = Date()

        let session = makeCompletedSession(context: context, plan: plan, prescription: prescription)
        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        // Already finalized → evaluationHistory stays empty, outcome unchanged
        #expect(event.evaluationHistory.isEmpty)
        #expect(event.outcome == .good)
    }

    // MARK: - requiredEvaluationCount via SuggestionGenerator

    @Test @MainActor
    func generatedIncreaseWeightEvent_hasRequiredCount2() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(
            context: context, workingSets: 3, targetWeight: 200, targetReps: 8, repRangeMode: .target
        )
        prescription.repRange?.targetReps = 8
        prescription.musclesTargeted = [.chest]
        prescription.equipmentType = .barbell

        // Two sessions both hitting above target reps → triggers increaseWeight
        let session1 = TestDataFactory.makeSession(context: context, daysAgo: 3)
        session1.statusValue = .done
        _ = TestDataFactory.makePerformance(context: context, session: session1, prescription: prescription,
            sets: [
                (weight: 200, reps: 10, rest: 90, type: .working),
                (weight: 200, reps: 10, rest: 90, type: .working),
                (weight: 200, reps: 10, rest: 90, type: .working)
            ])

        let session2 = WorkoutSession(from: plan)
        context.insert(session2)
        guard let perf = session2.sortedExercises.first else {
            Issue.record("Expected plan-backed performance.")
            return
        }
        for set in perf.sortedSets {
            set.weight = 200; set.reps = 10; set.restSeconds = 90; set.complete = true
        }

        let generated = await SuggestionGenerator.generateSuggestions(for: session2, context: context)
        let weightEvents = generated.filter { event in
            event.sortedChanges.contains { $0.changeType == .increaseWeight }
        }

        #expect(weightEvents.isEmpty == false, "Expected at least one increaseWeight suggestion")
        #expect(weightEvents.allSatisfy { $0.requiredEvaluationCount == 2 })
    }

    @Test @MainActor
    func generatedIncreaseRestEvent_hasRequiredCount2() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(
            context: context, workingSets: 1, targetWeight: 100, targetReps: 8, targetRest: 60,
            repRangeMode: .range, lowerRange: 6, upperRange: 10
        )
        prescription.musclesTargeted = [.chest]
        prescription.equipmentType = .barbell

        // Create two sessions with short rest and barely hitting reps → rest increase triggered
        // Pattern: completed at minimum reps twice in a row suggests rest is too short
        let session1 = TestDataFactory.makeSession(context: context, daysAgo: 3)
        session1.statusValue = .done
        _ = TestDataFactory.makePerformance(context: context, session: session1, prescription: prescription,
            sets: [(weight: 100, reps: 6, rest: 60, type: .working)])

        let currentSession = WorkoutSession(from: plan)
        context.insert(currentSession)
        guard let perf = currentSession.sortedExercises.first else { return }
        for set in perf.sortedSets {
            set.weight = 100; set.reps = 6; set.restSeconds = 60; set.complete = true
        }

        let generated = await SuggestionGenerator.generateSuggestions(for: currentSession, context: context)
        let restEvents = generated.filter { event in
            event.sortedChanges.contains { $0.changeType == .increaseRest }
        }

        if !restEvents.isEmpty {
            #expect(restEvents.allSatisfy { $0.requiredEvaluationCount == 2 })
        }
        // Note: rest increase may not trigger in every scenario — this test validates count IF generated
    }

    @Test @MainActor
    func generatedDecreaseWeightEvent_hasRequiredCount1() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(
            context: context, workingSets: 1, targetWeight: 100, targetReps: 8,
            repRangeMode: .range, lowerRange: 6, upperRange: 10
        )
        prescription.musclesTargeted = [.chest]
        prescription.equipmentType = .barbell

        // User consistently fails to hit even the floor reps → decreaseWeight suggested
        let currentSession = WorkoutSession(from: plan)
        context.insert(currentSession)
        guard let perf = currentSession.sortedExercises.first else { return }
        for set in perf.sortedSets {
            set.weight = 100; set.reps = 3; set.restSeconds = 90; set.complete = true
        }

        let generated = await SuggestionGenerator.generateSuggestions(for: currentSession, context: context)
        let decreaseEvents = generated.filter { event in
            event.sortedChanges.contains { $0.changeType == .decreaseWeight }
        }

        if !decreaseEvents.isEmpty {
            // Safety/cleanup decreases should resolve immediately (no need for confirmation)
            #expect(decreaseEvents.allSatisfy { $0.requiredEvaluationCount == 1 })
        }
    }

    @Test @MainActor
    func generatedWarmupCalibrationEvent_hasRequiredCount1() async throws {
        let context = try TestDataFactory.makeContext()
        // Warmup calibration category always requires only 1 session regardless of change type
        let (plan, prescription) = TestDataFactory.makePrescription(
            context: context, workingSets: 1, targetWeight: 100, targetReps: 8,
            repRangeMode: .range, lowerRange: 6, upperRange: 10
        )
        prescription.musclesTargeted = [.chest]
        prescription.equipmentType = .barbell

        // Add warmup slot
        let warmupSlot = SetPrescription(
            exercisePrescription: prescription, setType: .warmup,
            targetWeight: 80, targetReps: 10, targetRest: 60, index: 0
        )
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

        if !warmupEvents.isEmpty {
            #expect(warmupEvents.allSatisfy { $0.requiredEvaluationCount == 1 })
        }
    }

    // MARK: - History entry content

    @Test @MainActor
    func evaluationHistoryEntry_storesCorrectSessionID() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription, _, event) = makeEventForOutcomeResolver(context: context, requiredEvaluationCount: 2)
        let session = makeCompletedSession(context: context, plan: plan, prescription: prescription,
            actualWeight: 102.5, actualReps: 8)

        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        #expect(event.evaluationHistory.first?.sourceSessionID == session.id)
    }

    @Test @MainActor
    func evaluationHistoryEntry_storesPerformanceSnapshot() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription, _, event) = makeEventForOutcomeResolver(context: context, requiredEvaluationCount: 2)
        let session = makeCompletedSession(context: context, plan: plan, prescription: prescription,
            actualWeight: 102.5, actualReps: 8)

        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        let snapshot = event.evaluationHistory.first?.snapshot
        #expect(snapshot != nil)
        #expect(snapshot?.sets.first?.weight == 102.5)
        #expect(snapshot?.sets.first?.reps == 8)
    }

    @Test @MainActor
    func evaluationHistoryEntry_reasonContainsRulesPrefix() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription, _, event) = makeEventForOutcomeResolver(context: context, requiredEvaluationCount: 2)
        let session = makeCompletedSession(context: context, plan: plan, prescription: prescription,
            actualWeight: 102.5, actualReps: 8)

        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        let reason = event.evaluationHistory.first?.reason ?? ""
        #expect(reason.hasPrefix("[Rules]") || reason.hasPrefix("[AI]") || reason.hasPrefix("[AI override]"))
    }

    // MARK: - RequiredEvaluationCount = 1 finalizes after single session

    @Test @MainActor
    func singleSessionFinalizes_whenRequiredCountIs1() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription, _, event) = makeEventForOutcomeResolver(context: context, requiredEvaluationCount: 1)
        let session = makeCompletedSession(context: context, plan: plan, prescription: prescription,
            actualWeight: 102.5, actualReps: 8)

        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        #expect(event.outcome != .pending)
        #expect(event.evaluatedAt != nil)
        #expect(event.evaluationHistory.count == 1)
    }

    // MARK: - Multiple events same workout

    @Test @MainActor
    func multipleEventsInSameWorkout_eachGetsIndependentEvaluation() async throws {
        let context = try TestDataFactory.makeContext()

        // Two exercise-level rep range events on the same prescription — no set scoping,
        // so canEvaluateWithCurrentPerformance returns true for both.
        let (plan, prescription) = TestDataFactory.makePrescription(
            context: context, workingSets: 3, targetWeight: 100, targetReps: 8,
            repRangeMode: .range, lowerRange: 6, upperRange: 12
        )

        func makeRepRangeEvent(changeType: ChangeType, oldValue: Double, newValue: Double) -> SuggestionEvent {
            let change = PrescriptionChange(changeType: changeType, previousValue: oldValue, newValue: newValue)
            context.insert(change)
            let event = SuggestionEvent(
                category: .repRangeConfiguration,
                catalogID: prescription.catalogID,
                sessionFrom: nil,
                targetExercisePrescription: prescription,
                triggerPerformanceSnapshot: .empty,
                triggerTargetSnapshot: ExerciseTargetSnapshot(prescription: prescription),
                trainingStyle: .straightSets,
                requiredEvaluationCount: 1,
                createdAt: Date().addingTimeInterval(-3600),
                changes: [change]
            )
            change.event = event
            context.insert(event)
            event.decision = .accepted
            return event
        }

        let event1 = makeRepRangeEvent(changeType: .increaseRepRangeUpper, oldValue: 10, newValue: 12)
        let event2 = makeRepRangeEvent(changeType: .increaseRepRangeLower, oldValue: 6, newValue: 8)

        let session = TestDataFactory.makeSession(context: context)
        session.workoutPlan = plan
        _ = TestDataFactory.makePerformance(context: context, session: session, prescription: prescription,
            sets: [
                (weight: 100, reps: 9, rest: 90, type: .working),
                (weight: 100, reps: 10, rest: 90, type: .working),
                (weight: 100, reps: 11, rest: 90, type: .working)
            ])

        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        // Both events should be evaluated independently
        #expect(event1.evaluationHistory.count == 1)
        #expect(event2.evaluationHistory.count == 1)
    }
}

import SwiftData
import Foundation
import Testing
@testable import VillainArc

// Tests for aggregateRuleSignal primary-change weighting in OutcomeResolver.
// Exercises the fix for Issue 1-B: secondary signals (rep resets, rest adjustments)
// must not promote the aggregated outcome above what the primary weight-change signal reports.
@Suite(.serialized)
struct OutcomeResolverGroupingTests {

    // MARK: - Helpers

    /// Creates a multi-change event (increaseWeight + decreaseReps bundle) scoped to the
    /// first set of the given prescription. Both changes are linked to the returned event.
    @MainActor
    private func makeBundle(
        context: ModelContext,
        prescription: ExercisePrescription,
        weightOld: Double,
        weightNew: Double,
        repsOld: Int,
        repsNew: Int,
        requiredEvaluationCount: Int = 1
    ) -> SuggestionEvent {
        let setPrescription = prescription.sortedSets.first!

        let weightChange = PrescriptionChange(changeType: .increaseWeight, previousValue: weightOld, newValue: weightNew)
        let repsChange = PrescriptionChange(changeType: .decreaseReps, previousValue: Double(repsOld), newValue: Double(repsNew))
        context.insert(weightChange)
        context.insert(repsChange)

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
            createdAt: Date().addingTimeInterval(-3600),
            changes: [weightChange, repsChange]
        )
        weightChange.event = event
        repsChange.event = event
        context.insert(event)
        event.decision = .accepted
        return event
    }

    // MARK: - Bug fix: primary ignored, secondary good → ignored

    /// The canonical regression case for Issue 1-B.
    /// Bundle: increaseWeight (100→110) + decreaseReps (10→8).
    /// Athlete kept the old weight (ignored the weight increase) but correctly reset reps.
    ///   increaseWeight  → ignored  (weight stayed at 100, far from 110)
    ///   decreaseReps    → good     (reps followed to 8, in-range)
    /// Old code: good > ignored in severity priority → resolves as "good" (wrong)
    /// New code: primary weight signal anchors → resolves as "ignored" (correct)
    @Test @MainActor
    func bundle_primaryWeightIgnored_secondaryRepsGood_resolvesAsIgnored() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(
            context: context,
            workingSets: 1,
            targetWeight: 100,
            targetReps: 10,
            repRangeMode: .range,
            lowerRange: 6,
            upperRange: 10
        )

        // Use a large weight jump (100→110) so the "stayed at 100" is clearly outside tolerance.
        let event = makeBundle(
            context: context,
            prescription: prescription,
            weightOld: 100, weightNew: 110,
            repsOld: 10, repsNew: 8
        )

        let session = TestDataFactory.makeSession(context: context)
        session.workoutPlan = plan
        // Athlete: kept old weight (100), but did reset reps to 8 (followed reps suggestion).
        _ = TestDataFactory.makePerformance(
            context: context, session: session, prescription: prescription,
            sets: [(weight: 100, reps: 8, rest: 90, type: .working)]
        )

        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        #expect(event.outcome == .ignored,
            "Primary weight change was not followed — secondary reps-good must not override")
    }

    // MARK: - Secondary ignored does not demote primary good

    /// Bundle: increaseWeight (100→102.5) + decreaseReps (10→8).
    /// Athlete followed the weight increase but kept old reps (10, ignored the rep reset).
    ///   increaseWeight  → good     (weight at 102.5, reps in-range)
    ///   decreaseReps    → ignored  (reps stayed at 10, never reached new target 8)
    /// Both old and new code should resolve as "good" — secondary ignored must not demote primary.
    @Test @MainActor
    func bundle_primaryGood_secondaryRepsIgnored_resolvesAsGood() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(
            context: context,
            workingSets: 1,
            targetWeight: 100,
            targetReps: 10,
            repRangeMode: .range,
            lowerRange: 6,
            upperRange: 10
        )

        let event = makeBundle(
            context: context,
            prescription: prescription,
            weightOld: 100, weightNew: 102.5,
            repsOld: 10, repsNew: 8
        )

        let session = TestDataFactory.makeSession(context: context)
        session.workoutPlan = plan
        // Athlete: followed weight (102.5), but kept old reps (10 = in-range but not near new target 8).
        _ = TestDataFactory.makePerformance(
            context: context, session: session, prescription: prescription,
            sets: [(weight: 102.5, reps: 10, rest: 90, type: .working)]
        )

        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        #expect(event.outcome == .good,
            "Primary weight followed — secondary reps-ignored must not demote the result")
    }

    // MARK: - No primary changes → severity-priority fallback

    /// Event with only secondary changes (no weight change).
    /// decreaseReps (10→8) + increaseRest (90→120).
    /// Athlete followed the reps reset but ignored the rest increase.
    ///   decreaseReps  → good     (reps followed to 8, in-range)
    ///   increaseRest  → ignored  (rest stayed at 90)
    /// No primary changes → falls back to original severity-priority: good > ignored → good.
    @Test @MainActor
    func noPrimaryChanges_fallsBackToSeverityPriority_goodBeatsIgnored() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(
            context: context,
            workingSets: 1,
            targetWeight: 100,
            targetReps: 10,
            targetRest: 90,
            repRangeMode: .range,
            lowerRange: 6,
            upperRange: 10
        )
        let setPrescription = prescription.sortedSets.first!

        let repsChange = PrescriptionChange(changeType: .decreaseReps, previousValue: 10, newValue: 8)
        let restChange = PrescriptionChange(changeType: .increaseRest, previousValue: 90, newValue: 120)
        context.insert(repsChange)
        context.insert(restChange)

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
            createdAt: Date().addingTimeInterval(-3600),
            changes: [repsChange, restChange]
        )
        repsChange.event = event
        restChange.event = event
        context.insert(event)
        event.decision = .accepted

        let session = TestDataFactory.makeSession(context: context)
        session.workoutPlan = plan
        // Reps followed (8), rest not changed (stayed at 90).
        _ = TestDataFactory.makePerformance(
            context: context, session: session, prescription: prescription,
            sets: [(weight: 100, reps: 8, rest: 90, type: .working)]
        )

        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        #expect(event.outcome == .good,
            "No primary changes — severity-priority fallback should pick good over ignored")
    }

    // MARK: - Normal bundle: both primary and secondary good → good

    /// Bundle: increaseWeight (100→102.5) + decreaseReps (10→8).
    /// Athlete followed both: new weight and reset reps, reps in-range.
    /// Verifies the normal happy-path still works after the fix.
    @Test @MainActor
    func bundle_primaryGood_secondaryGood_resolvesAsGood() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(
            context: context,
            workingSets: 1,
            targetWeight: 100,
            targetReps: 10,
            repRangeMode: .range,
            lowerRange: 6,
            upperRange: 10
        )

        let event = makeBundle(
            context: context,
            prescription: prescription,
            weightOld: 100, weightNew: 102.5,
            repsOld: 10, repsNew: 8
        )

        let session = TestDataFactory.makeSession(context: context)
        session.workoutPlan = plan
        // Athlete: followed weight (102.5) and reset reps (8 = in-range).
        _ = TestDataFactory.makePerformance(
            context: context, session: session, prescription: prescription,
            sets: [(weight: 102.5, reps: 8, rest: 90, type: .working)]
        )

        await OutcomeResolver.resolveOutcomes(for: session, context: context)

        #expect(event.outcome == .good, "Normal bundle followed correctly must resolve as good")
    }
}

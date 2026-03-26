import Foundation
import SwiftData
import Testing

@testable import VillainArc

// Tests for OutcomeRuleEngine: verifies that each change type produces the correct
// outcome signal across all outcome paths (good / tooAggressive / tooEasy / ignored / nil).
@Suite(.serialized) struct OutcomeRuleEngineTests {

    // MARK: - Helpers

    /// Creates a prescription with a single working set, a matching exercise performance
    /// with the given actual values, and a set-scoped SuggestionEvent targeting that set.
    @MainActor private func makeSetScopedContext(
        context: ModelContext, actualWeight: Double = 100, actualReps: Int = 8, actualRest: Int = 90, actualSetType: ExerciseSetType = .working, triggerWeight: Double? = nil, triggerReps: Int? = nil, triggerRest: Int? = nil, triggerSetType: ExerciseSetType? = nil, targetWeight: Double = 100,
        repRangeMode: RepRangeMode = .range, lowerRange: Int = 6, upperRange: Int = 10, targetReps: Int = 8, category: SuggestionCategory = .performance
    ) -> (event: SuggestionEvent, perf: ExercisePerformance, setPrescription: SetPrescription) {
        let (_, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1, targetWeight: targetWeight, targetReps: targetReps, repRangeMode: repRangeMode, lowerRange: lowerRange, upperRange: upperRange)
        let setPrescription = prescription.sortedSets.first!
        let triggerSession = TestDataFactory.makeSession(context: context, daysAgo: 3)
        triggerSession.statusValue = .done
        let triggerPerformance = TestDataFactory.makePerformance(context: context, session: triggerSession, prescription: prescription, sets: [(weight: triggerWeight ?? targetWeight, reps: triggerReps ?? targetReps, rest: triggerRest ?? actualRest, type: triggerSetType ?? actualSetType)])
        let session = TestDataFactory.makeSession(context: context)
        let perf = TestDataFactory.makePerformance(context: context, session: session, prescription: prescription, sets: [(weight: actualWeight, reps: actualReps, rest: actualRest, type: actualSetType)])
        let event = SuggestionEvent(category: category, catalogID: prescription.catalogID, sessionFrom: nil, targetExercisePrescription: prescription, targetSetPrescription: setPrescription, triggerTargetSetID: setPrescription.id, triggerPerformance: triggerPerformance, trainingStyle: .straightSets)

        context.insert(event)
        return (event, perf, setPrescription)
    }

    /// Creates a prescription with N working sets at the given actual rep counts,
    /// and a non-set-scoped exercise-level event for rep range change tests.
    @MainActor private func makeRepRangeContext(context: ModelContext, actualRepsPerSet: [Int], lowerRange: Int = 6, upperRange: Int = 10, repRangeMode: RepRangeMode = .range, targetRepsForTarget: Int = 10) -> (event: SuggestionEvent, perf: ExercisePerformance) {
        let (_, prescription) = TestDataFactory.makePrescription(context: context, workingSets: actualRepsPerSet.count, targetWeight: 100, targetReps: 8, repRangeMode: repRangeMode, lowerRange: lowerRange, upperRange: upperRange)
        if repRangeMode == .target { prescription.repRange?.targetReps = targetRepsForTarget }
        let triggerSession = TestDataFactory.makeSession(context: context, daysAgo: 3)
        triggerSession.statusValue = .done
        let triggerPerf = TestDataFactory.makePerformance(context: context, session: triggerSession, prescription: prescription, sets: actualRepsPerSet.map { (weight: 100.0, reps: $0, rest: 90, type: ExerciseSetType.working) })
        let session = TestDataFactory.makeSession(context: context)
        let perf = TestDataFactory.makePerformance(context: context, session: session, prescription: prescription, sets: actualRepsPerSet.map { (weight: 100.0, reps: $0, rest: 90, type: ExerciseSetType.working) })
        let event = SuggestionEvent(category: .repRangeConfiguration, catalogID: prescription.catalogID, sessionFrom: nil, targetExercisePrescription: prescription, triggerPerformance: triggerPerf, trainingStyle: .straightSets)
        context.insert(event)
        return (event, perf)
    }

    @MainActor private func makeRestChangeContext(
        context: ModelContext, oldRest: Int = 90, actualRestOwner: Int, actualDownstreamWeight: Double = 100, actualDownstreamReps: Int, triggerDownstreamWeight: Double = 100, triggerDownstreamReps: Int, repRangeMode: RepRangeMode = .range, lowerRange: Int = 6, upperRange: Int = 10, targetReps: Int = 8
    ) -> (event: SuggestionEvent, perf: ExercisePerformance, change: PrescriptionChange) {
        let (_, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 2, targetWeight: 100, targetReps: targetReps, targetRest: oldRest, repRangeMode: repRangeMode, lowerRange: lowerRange, upperRange: upperRange)
        if repRangeMode == .target { prescription.repRange?.targetReps = targetReps }

        let triggerSession = TestDataFactory.makeSession(context: context, daysAgo: 3)
        triggerSession.statusValue = .done
        let triggerPerf = TestDataFactory.makePerformance(context: context, session: triggerSession, prescription: prescription, sets: [(weight: 100, reps: targetReps, rest: oldRest, type: .working), (weight: triggerDownstreamWeight, reps: triggerDownstreamReps, rest: oldRest, type: .working)])

        let session = TestDataFactory.makeSession(context: context)
        let perf = TestDataFactory.makePerformance(context: context, session: session, prescription: prescription, sets: [(weight: 100, reps: targetReps, rest: actualRestOwner, type: .working), (weight: actualDownstreamWeight, reps: actualDownstreamReps, rest: oldRest, type: .working)])

        let event = SuggestionEvent(category: .recovery, catalogID: prescription.catalogID, sessionFrom: nil, targetExercisePrescription: prescription, targetSetPrescription: prescription.sortedSets[0], triggerTargetSetID: prescription.sortedSets[0].id, triggerPerformance: triggerPerf, trainingStyle: .straightSets)
        context.insert(event)

        let change = PrescriptionChange(changeType: .increaseRest, previousValue: Double(oldRest), newValue: 120)
        context.insert(change)

        return (event, perf, change)
    }

    // MARK: - Weight Change: Ignored

    @Test @MainActor func weightChange_ignored_whenActualWeightStaysAtOldTarget() throws {
        let context = try TestDataFactory.makeContext()
        // old=100, new=107.5 (3 increments away). actual=100: abs(100-107.5)=7.5 > tolerance(2.5),
        // not closer to new than old, not above new → not followed. abs(100-100)=0 ≤ 2.5 → "stayed near old".
        let (event, perf, _) = makeSetScopedContext(context: context, actualWeight: 100, targetWeight: 100)
        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 100, newValue: 107.5)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .ignored)
        #expect((signal?.confidence ?? 0) >= 0.85)
    }

    @Test @MainActor func weightChange_ignored_whenActualMovesAwayFromNewTarget() throws {
        let context = try TestDataFactory.makeContext()
        // actual=90 is farther from new (102.5) than from old (100) and below old → ignored
        let (event, perf, _) = makeSetScopedContext(context: context, actualWeight: 90, targetWeight: 100)
        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 100, newValue: 102.5)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .ignored)
    }

    // MARK: - Weight Change: Good

    @Test @MainActor func weightChange_good_whenAtNewWeightAndRepsInRange() throws {
        let context = try TestDataFactory.makeContext()
        // range 6-10, buffer=2; reps=8 in [6, 10] → good
        let (event, perf, _) = makeSetScopedContext(context: context, actualWeight: 102.5, actualReps: 8, targetWeight: 100, lowerRange: 6, upperRange: 10)
        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 100, newValue: 102.5)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .good)
        #expect((signal?.confidence ?? 0) >= 0.8)
    }

    @Test @MainActor func weightChange_good_whenRepsExactlyAtCeilingPlusBuffer() throws {
        let context = try TestDataFactory.makeContext()
        // range 6-10, span=4 → buffer=2; ceiling+buffer=12; reps=12 is still good (not above)
        let (event, perf, _) = makeSetScopedContext(context: context, actualWeight: 102.5, actualReps: 12, targetWeight: 100, lowerRange: 6, upperRange: 10)
        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 100, newValue: 102.5)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .good)
    }

    @Test @MainActor func weightChange_partialFollowThrough_inRange_returnsGoodWithLowerConfidence() throws {
        let context = try TestDataFactory.makeContext()
        let (event, perf, _) = makeSetScopedContext(context: context, actualWeight: 106.25, actualReps: 8, targetWeight: 100, lowerRange: 6, upperRange: 10)
        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 100, newValue: 110)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .good)
        #expect(signal?.confidence == 0.65)
    }

    @Test @MainActor func weightChange_usesPersistedWeightStepUsedInsteadOfLiveExerciseConfig() throws {
        let context = try TestDataFactory.makeContext()
        let (event, perf, setPrescription) = makeSetScopedContext(context: context, actualWeight: 106.25, actualReps: 8, targetWeight: 100, lowerRange: 6, upperRange: 10)
        event.weightStepUsed = 10
        setPrescription.exercise?.equipmentType = .machine
        perf.equipmentType = .machine
        event.targetExercisePrescription?.equipmentType = .machine
        event.triggerPerformance?.equipmentType = .machine

        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 100, newValue: 110)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .good)
        #expect(signal?.confidence == 0.9)
    }

    @Test @MainActor func weightChange_partialFollowThrough_belowFloor_returnsTooAggressiveWithLowerConfidence() throws {
        let context = try TestDataFactory.makeContext()
        let (event, perf, _) = makeSetScopedContext(context: context, actualWeight: 106.25, actualReps: 4, targetWeight: 100, lowerRange: 6, upperRange: 10)
        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 100, newValue: 110)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .tooAggressive)
        #expect(signal?.confidence == 0.65)
    }

    // MARK: - Weight Change: Too Aggressive

    @Test @MainActor func weightChange_tooAggressive_whenAtNewWeightAndRepsBelowFloor() throws {
        let context = try TestDataFactory.makeContext()
        // reps=4, floor=6 → can't hold even the lower bound of the range
        let (event, perf, _) = makeSetScopedContext(context: context, actualWeight: 102.5, actualReps: 4, targetWeight: 100, lowerRange: 6, upperRange: 10)
        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 100, newValue: 102.5)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .tooAggressive)
    }

    @Test @MainActor func weightChange_tooAggressive_targetMode_whenRepsBelowTarget() throws {
        let context = try TestDataFactory.makeContext()
        // target mode, target=8; reps=5 → tooAggressive
        let (event, perf, _) = makeSetScopedContext(context: context, actualWeight: 102.5, actualReps: 5, targetWeight: 100, repRangeMode: .target, targetReps: 8)
        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 100, newValue: 102.5)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .tooAggressive)
    }

    // MARK: - Weight Change: Too Easy

    @Test @MainActor func weightChange_tooEasy_whenAtNewWeightAndRepsAboveCeilingPlusBuffer() throws {
        let context = try TestDataFactory.makeContext()
        // range 6-10, buffer=2; reps=14 > 12 → tooEasy
        let (event, perf, _) = makeSetScopedContext(context: context, actualWeight: 102.5, actualReps: 14, targetWeight: 100, lowerRange: 6, upperRange: 10)
        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 100, newValue: 102.5)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .tooEasy)
    }

    // MARK: - Decrease Weight Change

    @Test @MainActor func decreaseWeightChange_ignored_whenActualStaysAtOldWeight() throws {
        let context = try TestDataFactory.makeContext()
        // old=100, new=90: abs(100-90)=10 > tolerance(2.5) → not followed.
        // abs(100-100)=0 ≤ 2.5 → "stayed near old" → .ignored(0.9)
        let (event, perf, _) = makeSetScopedContext(context: context, actualWeight: 100, targetWeight: 100)
        let change = PrescriptionChange(changeType: .decreaseWeight, previousValue: 100, newValue: 90)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .ignored)
    }

    @Test @MainActor func decreaseWeightChange_good_whenAtNewWeightAndRepsInRange() throws {
        let context = try TestDataFactory.makeContext()
        let (event, perf, _) = makeSetScopedContext(context: context, actualWeight: 97.5, actualReps: 8, targetWeight: 100, lowerRange: 6, upperRange: 10)
        let change = PrescriptionChange(changeType: .decreaseWeight, previousValue: 100, newValue: 97.5)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .good)
    }

    @Test @MainActor func decreaseWeightChange_insufficient_whenFollowedButStillBelowFloor() throws {
        let context = try TestDataFactory.makeContext()
        let (event, perf, _) = makeSetScopedContext(context: context, actualWeight: 95, actualReps: 4, triggerWeight: 100, triggerReps: 4, targetWeight: 100, lowerRange: 6, upperRange: 10)
        let change = PrescriptionChange(changeType: .decreaseWeight, previousValue: 100, newValue: 95)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .insufficient)
    }

    @Test @MainActor func decreaseWeightChange_insufficient_whenRepsDoNotImproveFromFloorTrigger() throws {
        let context = try TestDataFactory.makeContext()
        let (event, perf, _) = makeSetScopedContext(context: context, actualWeight: 95, actualReps: 6, triggerWeight: 100, triggerReps: 6, targetWeight: 100, lowerRange: 6, upperRange: 10)
        let change = PrescriptionChange(changeType: .decreaseWeight, previousValue: 100, newValue: 95)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .insufficient)
    }

    // MARK: - Weight Change: Not Set Scoped → nil

    @Test @MainActor func weightChange_returnsNil_whenEventNotSetScoped() throws {
        let context = try TestDataFactory.makeContext()
        let (_, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1, targetWeight: 100)
        let session = TestDataFactory.makeSession(context: context)
        let perf = TestDataFactory.makePerformance(context: context, session: session, prescription: prescription, sets: [(weight: 102.5, reps: 8, rest: 90, type: .working)])

        let event = SuggestionEvent(category: .performance, catalogID: prescription.catalogID, sessionFrom: nil, targetExercisePrescription: prescription, trainingStyle: .straightSets)
        context.insert(event)

        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 100, newValue: 102.5)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal == nil)
    }

    // MARK: - Reps Change

    @Test @MainActor func repsChange_ignored_whenActualRepsStayAtOldTarget() throws {
        let context = try TestDataFactory.makeContext()
        let (event, perf, _) = makeSetScopedContext(context: context, actualReps: 8)
        let change = PrescriptionChange(changeType: .increaseReps, previousValue: 8, newValue: 10)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .ignored)
    }

    @Test @MainActor func repsChange_good_whenFollowsNewTargetAndInRange() throws {
        let context = try TestDataFactory.makeContext()
        // increase to 10, range 6-12; reps=10 → in range → good
        let (event, perf, _) = makeSetScopedContext(context: context, actualReps: 10, lowerRange: 6, upperRange: 12)
        let change = PrescriptionChange(changeType: .increaseReps, previousValue: 8, newValue: 10)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .good)
    }

    @Test @MainActor func decreaseRepsChange_insufficient_whenFollowedButBelowRangeFloor() throws {
        let context = try TestDataFactory.makeContext()
        // decrease from 8 to 4; reps=4, floor=6 → below floor → tooAggressive
        let (event, perf, _) = makeSetScopedContext(context: context, actualReps: 4, lowerRange: 6, upperRange: 10)
        let change = PrescriptionChange(changeType: .decreaseReps, previousValue: 8, newValue: 4)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .insufficient)
    }

    @Test @MainActor func decreaseRepsChange_partialFollowThrough_inRange_returnsGoodWithLowerConfidence() throws {
        let context = try TestDataFactory.makeContext()
        let (event, perf, _) = makeSetScopedContext(context: context, actualReps: 10, lowerRange: 6, upperRange: 10)
        let change = PrescriptionChange(changeType: .decreaseReps, previousValue: 12, newValue: 8)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .good)
        #expect(signal?.confidence == 0.65)
    }

    @Test @MainActor func decreaseRepsChange_insufficient_whenRepsDoNotImproveFromBoundaryTrigger() throws {
        let context = try TestDataFactory.makeContext()
        let (event, perf, _) = makeSetScopedContext(context: context, actualReps: 6, triggerReps: 6, lowerRange: 6, upperRange: 10)
        let change = PrescriptionChange(changeType: .decreaseReps, previousValue: 8, newValue: 6)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .insufficient)
    }

    @Test @MainActor func repsChange_tooEasy_whenActualExceedsCeilingPlusBuffer() throws {
        let context = try TestDataFactory.makeContext()
        // increase to 10, range 6-10, buffer=2; reps=14 > 12 → tooEasy
        let (event, perf, _) = makeSetScopedContext(context: context, actualReps: 14, lowerRange: 6, upperRange: 10)
        let change = PrescriptionChange(changeType: .increaseReps, previousValue: 8, newValue: 10)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .tooEasy)
    }

    // MARK: - Rest Change

    @Test @MainActor func restChange_ignored_whenActualRestStaysAtOldTarget() throws {
        let context = try TestDataFactory.makeContext()
        let (event, perf, change) = makeRestChangeContext(context: context, oldRest: 90, actualRestOwner: 90, actualDownstreamReps: 8, triggerDownstreamReps: 6, lowerRange: 6, upperRange: 10)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .ignored)
    }

    @Test @MainActor func restChange_good_whenFollowedAndFollowingSetImprovesIntoRange() throws {
        let context = try TestDataFactory.makeContext()
        let (event, perf, change) = makeRestChangeContext(context: context, oldRest: 90, actualRestOwner: 120, actualDownstreamReps: 8, triggerDownstreamReps: 6, lowerRange: 6, upperRange: 10)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .good)
    }

    @Test @MainActor func restChange_partialFollowThrough_withoutImprovement_returnsInsufficientWithLowerConfidence() throws {
        let context = try TestDataFactory.makeContext()
        let (event, perf, _) = makeRestChangeContext(context: context, oldRest: 60, actualRestOwner: 91, actualDownstreamReps: 8, triggerDownstreamReps: 8, lowerRange: 6, upperRange: 10)
        let change = PrescriptionChange(changeType: .increaseRest, previousValue: 60, newValue: 120)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .insufficient)
        #expect(signal?.confidence == 0.65)
    }

    @Test @MainActor func restIncrease_largeOvershoot_returnsInsufficient() throws {
        let context = try TestDataFactory.makeContext()
        let (event, perf, _) = makeRestChangeContext(context: context, oldRest: 60, actualRestOwner: 150, actualDownstreamReps: 10, triggerDownstreamReps: 6, lowerRange: 6, upperRange: 10)
        let change = PrescriptionChange(changeType: .increaseRest, previousValue: 60, newValue: 120)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .insufficient)
        #expect(signal?.confidence == 0.8)
    }

    @Test @MainActor func restChange_insufficient_whenFollowedButFollowingSetStillBelowFloor() throws {
        let context = try TestDataFactory.makeContext()
        let (event, perf, change) = makeRestChangeContext(context: context, oldRest: 90, actualRestOwner: 120, actualDownstreamReps: 4, triggerDownstreamReps: 4, lowerRange: 6, upperRange: 10)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .insufficient)
    }

    @Test @MainActor func restChange_tooEasy_whenFollowedAndFollowingSetImprovesPastCeiling() throws {
        let context = try TestDataFactory.makeContext()
        let (event, perf, change) = makeRestChangeContext(context: context, oldRest: 90, actualRestOwner: 120, actualDownstreamReps: 14, triggerDownstreamReps: 10, lowerRange: 6, upperRange: 10)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .tooEasy)
    }

    @Test @MainActor func restDecrease_largeOvershoot_returnsTooEasy() throws {
        let context = try TestDataFactory.makeContext()
        let (event, perf, _) = makeRestChangeContext(context: context, oldRest: 90, actualRestOwner: 30, actualDownstreamReps: 8, triggerDownstreamReps: 8, lowerRange: 6, upperRange: 10)
        let change = PrescriptionChange(changeType: .decreaseRest, previousValue: 90, newValue: 60)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .tooEasy)
        #expect(signal?.confidence == 0.8)
    }

    @Test @MainActor func restChange_ignored_whenActualMovesAwayFromNewRestTarget() throws {
        let context = try TestDataFactory.makeContext()
        let (event, perf, change) = makeRestChangeContext(context: context, oldRest: 90, actualRestOwner: 60, actualDownstreamReps: 8, triggerDownstreamReps: 6, lowerRange: 6, upperRange: 10)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .ignored)
    }

    @Test @MainActor func restChange_usesEffectiveRestInterval_notRawStoredRest() throws {
        let context = try TestDataFactory.makeContext()
        let (_, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 3, targetWeight: 100, targetReps: 8, targetRest: 90, repRangeMode: .range, lowerRange: 6, upperRange: 10)
        prescription.sortedSets[1].type = .dropSet

        let triggerSession = TestDataFactory.makeSession(context: context, daysAgo: 3)
        triggerSession.statusValue = .done
        let triggerPerf = TestDataFactory.makePerformance(context: context, session: triggerSession, prescription: prescription, sets: [(weight: 100, reps: 8, rest: 90, type: .working), (weight: 80, reps: 8, rest: 60, type: .dropSet), (weight: 100, reps: 8, rest: 90, type: .working)])

        let session = TestDataFactory.makeSession(context: context)
        let perf = TestDataFactory.makePerformance(context: context, session: session, prescription: prescription, sets: [(weight: 100, reps: 8, rest: 120, type: .working), (weight: 80, reps: 8, rest: 60, type: .dropSet), (weight: 100, reps: 8, rest: 90, type: .working)])

        let event = SuggestionEvent(category: .recovery, catalogID: prescription.catalogID, sessionFrom: nil, targetExercisePrescription: prescription, targetSetPrescription: prescription.sortedSets[0], triggerTargetSetID: prescription.sortedSets[0].id, triggerPerformance: triggerPerf, trainingStyle: .straightSets)
        context.insert(event)

        let change = PrescriptionChange(changeType: .increaseRest, previousValue: 90, newValue: 120)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .ignored)
    }

    // MARK: - Set Type Change

    @Test @MainActor func setTypeChange_good_whenSetTypeMatchesNewTarget() throws {
        let context = try TestDataFactory.makeContext()
        // Suggestion was warmup→working; user performed it as working → good
        let (event, perf, _) = makeSetScopedContext(context: context, actualSetType: .working)
        let change = PrescriptionChange(changeType: .changeSetType, previousValue: Double(ExerciseSetType.warmup.rawValue), newValue: Double(ExerciseSetType.working.rawValue))
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .good)
        #expect((signal?.confidence ?? 0) >= 0.9)
    }

    @Test @MainActor func setTypeChange_ignored_whenSetTypeDoesNotMatchNewTarget() throws {
        let context = try TestDataFactory.makeContext()
        // Suggestion was warmup→working; user still performed it as warmup → ignored
        let (event, perf, _) = makeSetScopedContext(context: context, actualSetType: .warmup)
        let change = PrescriptionChange(changeType: .changeSetType, previousValue: Double(ExerciseSetType.warmup.rawValue), newValue: Double(ExerciseSetType.working.rawValue))
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .ignored)
    }

    // MARK: - Rep Range Change

    @Test @MainActor func repRangeUpperChange_good_whenMostSetsLandInNewRange() throws {
        let context = try TestDataFactory.makeContext()
        // New upper=10, lower=6; sets=[8, 9, 10] → 3/3 in range → good
        let (event, perf) = makeRepRangeContext(context: context, actualRepsPerSet: [8, 9, 10], lowerRange: 6, upperRange: 10)
        let change = PrescriptionChange(changeType: .increaseRepRangeUpper, previousValue: 8, newValue: 10)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .good)
    }

    @Test @MainActor func repRangeUpperChange_ignoresCloseUnlinkedWorkingSet() throws {
        let context = try TestDataFactory.makeContext()
        let (event, perf) = makeRepRangeContext(context: context, actualRepsPerSet: [8, 9, 10], lowerRange: 6, upperRange: 10)
        let manualSet = SetPerformance(exercise: perf, setType: .working, weight: 100, reps: 11, restSeconds: 90, index: 3, complete: true)
        context.insert(manualSet)
        perf.sets?.append(manualSet)

        let change = PrescriptionChange(changeType: .increaseRepRangeUpper, previousValue: 8, newValue: 10)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .good)
    }

    @Test @MainActor func repRangeUpperChange_downgradesWhenComparableUnlinkedSetMissesHard() throws {
        let context = try TestDataFactory.makeContext()
        let (event, perf) = makeRepRangeContext(context: context, actualRepsPerSet: [8, 9, 10], lowerRange: 6, upperRange: 10)
        let manualSet = SetPerformance(exercise: perf, setType: .working, weight: 100, reps: 3, restSeconds: 90, index: 3, complete: true)
        context.insert(manualSet)
        perf.sets?.append(manualSet)

        let change = PrescriptionChange(changeType: .increaseRepRangeUpper, previousValue: 8, newValue: 10)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .ignored)
        #expect(signal?.confidence == 0.65)
    }

    @Test @MainActor func repRangeLowerChange_tooAggressive_whenManySetsLandBelowNewFloor() throws {
        let context = try TestDataFactory.makeContext()
        // Raise lower from 6→10 (upper=14). sets=[8,8,8,8]: all < new floor 10.
        // abs(8-10)=2 ≤ 2 → near boundary → guard passes. belowFloor=4 ≥ 4/2=2 → tooAggressive.
        let (event, perf) = makeRepRangeContext(context: context, actualRepsPerSet: [8, 8, 8, 8], lowerRange: 6, upperRange: 14)
        let change = PrescriptionChange(changeType: .increaseRepRangeLower, previousValue: 6, newValue: 10)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .tooAggressive)
    }

    @Test @MainActor func repRangeUpperChange_tooEasy_whenManySetsExceedCeilingPlusBuffer() throws {
        let context = try TestDataFactory.makeContext()
        // lower=6, new upper=10; span=4 → buffer=2; ceiling+buffer=12.
        // sets=[10,10,13,13]: ratio=2/4=0.5 ≥ 0.5 → guard passes.
        // aboveCeiling=[13,13] (13>12), count=2 ≥ 4/2=2 → tooEasy.
        let (event, perf) = makeRepRangeContext(context: context, actualRepsPerSet: [10, 10, 13, 13], lowerRange: 6, upperRange: 10)
        let change = PrescriptionChange(changeType: .increaseRepRangeUpper, previousValue: 8, newValue: 10)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .tooEasy)
    }

    @Test @MainActor func repRangeLowerChange_tooAggressive_whenSetsFarBelowHarderFloor() throws {
        let context = try TestDataFactory.makeContext()
        // Raise lower from 6→10; upper=14; sets=[4,4,4] are clearly below the harder floor.
        let (event, perf) = makeRepRangeContext(context: context, actualRepsPerSet: [4, 4, 4], lowerRange: 6, upperRange: 14)
        let change = PrescriptionChange(changeType: .increaseRepRangeLower, previousValue: 6, newValue: 10)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .tooAggressive)
    }

    @Test @MainActor func repRangeLowerChange_insufficient_whenEasierFloorStillNotEnough() throws {
        let context = try TestDataFactory.makeContext()
        let (event, perf) = makeRepRangeContext(context: context, actualRepsPerSet: [4, 4, 4], lowerRange: 8, upperRange: 12)
        let change = PrescriptionChange(changeType: .decreaseRepRangeLower, previousValue: 8, newValue: 6)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .insufficient)
    }

    @Test @MainActor func repRangeTargetChange_good_whenSetsHitNewTarget() throws {
        let context = try TestDataFactory.makeContext()
        // Target mode, new target=10; sets=[10,10] → floor=10, ceiling=10; ratio=1.0 → good
        let (event, perf) = makeRepRangeContext(context: context, actualRepsPerSet: [10, 10], repRangeMode: .target, targetRepsForTarget: 10)
        let change = PrescriptionChange(changeType: .increaseRepRangeTarget, previousValue: 8, newValue: 10)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .good)
    }

    @Test @MainActor func repRangeTargetChange_tooAggressive_whenSetsBelowNewTarget() throws {
        let context = try TestDataFactory.makeContext()
        // Target mode, new target=10; sets=[8,8] → abs(8-10)=2 ≤ 2 → passes boundary guard.
        // belowFloor=[8,8] (both < 10), count=2 ≥ 2/2=1 → tooAggressive.
        let (event, perf) = makeRepRangeContext(context: context, actualRepsPerSet: [8, 8], repRangeMode: .target, targetRepsForTarget: 10)
        let change = PrescriptionChange(changeType: .increaseRepRangeTarget, previousValue: 8, newValue: 10)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .tooAggressive)
    }

    // MARK: - tooEasyBuffer Boundary Behavior

    @Test @MainActor func tooEasyBuffer_narrowRange_repsExactlyAtCeilingPlusOneIsGood() throws {
        let context = try TestDataFactory.makeContext()
        // range 8-10, span=2 ≤ 3 → buffer=1; ceiling+buffer=11; reps=11 → good (exactly at limit)
        let (event, perf, _) = makeSetScopedContext(context: context, actualWeight: 102.5, actualReps: 11, targetWeight: 100, lowerRange: 8, upperRange: 10)
        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 100, newValue: 102.5)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .good)
    }

    @Test @MainActor func tooEasyBuffer_narrowRange_repsAboveCeilingPlusOneIsTooEasy() throws {
        let context = try TestDataFactory.makeContext()
        // range 8-10, buffer=1; reps=12 > 11 → tooEasy
        let (event, perf, _) = makeSetScopedContext(context: context, actualWeight: 102.5, actualReps: 12, targetWeight: 100, lowerRange: 8, upperRange: 10)
        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 100, newValue: 102.5)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .tooEasy)
    }

    @Test @MainActor func tooEasyBuffer_wideRange_repsExactlyAtCeilingPlusThreeIsGood() throws {
        let context = try TestDataFactory.makeContext()
        // range 6-14, span=8 > 6 → buffer=3; ceiling+buffer=17; reps=17 → good
        let (event, perf, _) = makeSetScopedContext(context: context, actualWeight: 102.5, actualReps: 17, targetWeight: 100, lowerRange: 6, upperRange: 14)
        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 100, newValue: 102.5)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .good)
    }

    @Test @MainActor func tooEasyBuffer_wideRange_repsAboveCeilingPlusThreeIsTooEasy() throws {
        let context = try TestDataFactory.makeContext()
        // range 6-14, buffer=3; reps=18 > 17 → tooEasy
        let (event, perf, _) = makeSetScopedContext(context: context, actualWeight: 102.5, actualReps: 18, targetWeight: 100, lowerRange: 6, upperRange: 14)
        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 100, newValue: 102.5)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .tooEasy)
    }

    // MARK: - Warmup Weight Change (warmupCalibration category)

    @Test @MainActor func warmupWeightChange_ignored_whenWarmupLoadNotFollowed() throws {
        let context = try TestDataFactory.makeContext()
        // Warmup stayed at old load (60), suggestion was to increase to 70 → ignored
        let (event, perf, _) = makeSetScopedContext(context: context, actualWeight: 60, actualSetType: .warmup, targetWeight: 60, category: .warmupCalibration)
        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 60, newValue: 70)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .ignored)
    }

    @Test @MainActor func warmupWeightChange_good_whenWarmupFollowedAndLightRelativeToWorkingLoad() throws {
        let context = try TestDataFactory.makeContext()
        // Build prescription: 1 warmup + 1 working set
        let (_, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1, targetWeight: 100, targetReps: 8, lowerRange: 6, upperRange: 10)
        let warmupSlot = SetPrescription(exercisePrescription: prescription, setType: .warmup, targetWeight: 60, targetReps: 10, targetRest: 60, index: 0)
        // Reindex: warmup=0, working=1
        prescription.sortedSets.forEach { $0.index += 1 }
        prescription.sets?.insert(warmupSlot, at: 0)

        let triggerSession = TestDataFactory.makeSession(context: context, daysAgo: 3)
        triggerSession.statusValue = .done
        let triggerPerf = TestDataFactory.makePerformance(context: context, session: triggerSession, prescription: prescription, sets: [(weight: 60, reps: 10, rest: 60, type: .warmup), (weight: 100, reps: 8, rest: 90, type: .working)])

        let session = TestDataFactory.makeSession(context: context)
        // warmup=70, working=100 → 70 < 100*0.9=90 → good
        let perf = TestDataFactory.makePerformance(context: context, session: session, prescription: prescription, sets: [(weight: 70, reps: 10, rest: 60, type: .warmup), (weight: 100, reps: 8, rest: 90, type: .working)])

        let warmupSetPrescription = warmupSlot

        let event = SuggestionEvent(category: .warmupCalibration, catalogID: prescription.catalogID, sessionFrom: nil, targetExercisePrescription: prescription, targetSetPrescription: warmupSetPrescription, triggerTargetSetID: warmupSetPrescription.id, triggerPerformance: triggerPerf, trainingStyle: .straightSets)
        context.insert(event)

        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 60, newValue: 70)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .good)
    }

    @Test @MainActor func warmupWeightChange_tooAggressive_whenWarmupLoadTooCloseToWorkingLoad() throws {
        let context = try TestDataFactory.makeContext()
        // Build prescription: 1 warmup + 1 working set
        let (_, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1, targetWeight: 100, targetReps: 8, lowerRange: 6, upperRange: 10)
        let warmupSlot = SetPrescription(exercisePrescription: prescription, setType: .warmup, targetWeight: 80, targetReps: 10, targetRest: 60, index: 0)
        prescription.sortedSets.forEach { $0.index += 1 }
        prescription.sets?.insert(warmupSlot, at: 0)

        let triggerSession = TestDataFactory.makeSession(context: context, daysAgo: 3)
        triggerSession.statusValue = .done
        let triggerPerf = TestDataFactory.makePerformance(context: context, session: triggerSession, prescription: prescription, sets: [(weight: 80, reps: 10, rest: 60, type: .warmup), (weight: 100, reps: 8, rest: 90, type: .working)])

        let session = TestDataFactory.makeSession(context: context)
        // warmup=95, working=100 → 95 >= 100*0.9=90 → tooAggressive
        let perf = TestDataFactory.makePerformance(context: context, session: session, prescription: prescription, sets: [(weight: 95, reps: 10, rest: 60, type: .warmup), (weight: 100, reps: 8, rest: 90, type: .working)])

        let warmupSetPrescription = warmupSlot

        let event = SuggestionEvent(category: .warmupCalibration, catalogID: prescription.catalogID, sessionFrom: nil, targetExercisePrescription: prescription, targetSetPrescription: warmupSetPrescription, triggerTargetSetID: warmupSetPrescription.id, triggerPerformance: triggerPerf, trainingStyle: .straightSets)
        context.insert(event)

        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 80, newValue: 95)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .tooAggressive)
    }

    // MARK: - Issue 1-A: Frozen Rep Range (not live prescription)
    // These tests verify that outcome evaluation uses the rep range captured in
    // triggerTargetSnapshot at suggestion-creation time, NOT the current live
    // prescription range. A range accepted between suggestion creation and outcome
    // resolution must not retroactively change the outcome.

    /// Weight change: frozen range 8-12, live range mutated to 14-18 before evaluation.
    /// Reps=10 is good against [8-12] but tooAggressive against [14-18].
    /// Expect: good (frozen range wins).
    @Test @MainActor func weightChange_usesSnapshotRepRange_notLiveRange() throws {
        let context = try TestDataFactory.makeContext()
        // Create prescription with range 8-12 and capture the snapshot.
        let (_, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1, targetWeight: 100, targetReps: 8, repRangeMode: .range, lowerRange: 8, upperRange: 12)
        let setPrescription = prescription.sortedSets.first!
        let triggerSession = TestDataFactory.makeSession(context: context, daysAgo: 3)
        triggerSession.statusValue = .done
        let triggerPerf = TestDataFactory.makePerformance(context: context, session: triggerSession, prescription: prescription, sets: [(weight: 100, reps: 8, rest: 90, type: .working)])
        let session = TestDataFactory.makeSession(context: context)
        let perf = TestDataFactory.makePerformance(context: context, session: session, prescription: prescription, sets: [(weight: 102.5, reps: 10, rest: 90, type: .working)])
        // Event snapshot is frozen at 8-12.
        let event = SuggestionEvent(category: .performance, catalogID: prescription.catalogID, sessionFrom: nil, targetExercisePrescription: prescription, targetSetPrescription: setPrescription, triggerTargetSetID: setPrescription.id, triggerPerformance: triggerPerf, trainingStyle: .straightSets)
        context.insert(event)

        // Now mutate the live prescription range to 14-18 (simulating a separate accepted suggestion).
        prescription.repRange?.lowerRange = 14
        prescription.repRange?.upperRange = 18

        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 100, newValue: 102.5)
        context.insert(change)

        // Reps=10 against frozen [8-12] → good. Against live [14-18] → tooAggressive.
        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .good, "Should evaluate against frozen range 8-12, not live 14-18")
    }

    /// Reps change: frozen range 8-12, live range mutated to 14-18 before evaluation.
    /// User follows suggestion (reps=10) — good against frozen, tooAggressive against live.
    @Test @MainActor func repsChange_usesSnapshotRepRange_notLiveRange() throws {
        let context = try TestDataFactory.makeContext()
        let (_, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1, targetWeight: 100, targetReps: 8, repRangeMode: .range, lowerRange: 8, upperRange: 12)
        let setPrescription = prescription.sortedSets.first!
        let triggerSession = TestDataFactory.makeSession(context: context, daysAgo: 3)
        triggerSession.statusValue = .done
        let triggerPerf = TestDataFactory.makePerformance(context: context, session: triggerSession, prescription: prescription, sets: [(weight: 100, reps: 8, rest: 90, type: .working)])
        let session = TestDataFactory.makeSession(context: context)
        let perf = TestDataFactory.makePerformance(context: context, session: session, prescription: prescription, sets: [(weight: 100, reps: 10, rest: 90, type: .working)])
        let event = SuggestionEvent(category: .performance, catalogID: prescription.catalogID, sessionFrom: nil, targetExercisePrescription: prescription, targetSetPrescription: setPrescription, triggerTargetSetID: setPrescription.id, triggerPerformance: triggerPerf, trainingStyle: .straightSets)
        context.insert(event)

        // Mutate live range to 14-18 after snapshot is captured.
        prescription.repRange?.lowerRange = 14
        prescription.repRange?.upperRange = 18

        // Suggest increasing reps from 8 to 10; user follows.
        let change = PrescriptionChange(changeType: .increaseReps, previousValue: 8, newValue: 10)
        context.insert(change)

        // Reps=10 against frozen [8-12] → good. Against live [14-18] → tooAggressive.
        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .good, "Should evaluate against frozen range 8-12, not live 14-18")
    }

    /// Rest change: frozen range 8-12, live range mutated to 14-18 before evaluation.
    /// User follows the rest increase and the following set improves to 10 reps — good against
    /// frozen 8-12, tooAggressive against live 14-18.
    @Test @MainActor func restChange_usesSnapshotRepRange_notLiveRange() throws {
        let context = try TestDataFactory.makeContext()
        let (_, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 2, targetWeight: 100, targetReps: 8, targetRest: 90, repRangeMode: .range, lowerRange: 8, upperRange: 12)
        let setPrescription = prescription.sortedSets.first!
        // Create trigger performance BEFORE mutating the live range, so originalTargetSnapshot freezes 8-12.
        let triggerSession = TestDataFactory.makeSession(context: context, daysAgo: 3)
        triggerSession.statusValue = .done
        let triggerPerf = TestDataFactory.makePerformance(context: context, session: triggerSession, prescription: prescription, sets: [(weight: 100, reps: 8, rest: 90, type: .working), (weight: 100, reps: 6, rest: 90, type: .working)])

        let session = TestDataFactory.makeSession(context: context)
        let perf = TestDataFactory.makePerformance(context: context, session: session, prescription: prescription, sets: [(weight: 100, reps: 8, rest: 120, type: .working), (weight: 100, reps: 10, rest: 90, type: .working)])

        let event = SuggestionEvent(category: .recovery, catalogID: prescription.catalogID, sessionFrom: nil, targetExercisePrescription: prescription, targetSetPrescription: setPrescription, triggerTargetSetID: setPrescription.id, triggerPerformance: triggerPerf, trainingStyle: .straightSets)
        context.insert(event)

        // Mutate live range to 14-18 after snapshot is captured.
        prescription.repRange?.lowerRange = 14
        prescription.repRange?.upperRange = 18

        // Suggest increasing rest from 90s to 120s; user follows (actual rest=120).
        let change = PrescriptionChange(changeType: .increaseRest, previousValue: 90, newValue: 120)
        context.insert(change)

        // Reps=10 against frozen [8-12] → good. Against live [14-18] → tooAggressive.
        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .good, "Should evaluate reps against frozen range 8-12, not live 14-18")
    }

    // MARK: - Issue 1-C: Directional Overshoot
    // These tests verify that a large overshoot in either direction does not get credited as
    // normal adherence. Large upward overshoots mean the suggestion was too conservative;
    // large downward overshoots mean the decrease was still too aggressive.

    /// Weight increase 80→82.5; athlete actually loaded 87.5 (= new + 2×tol = cap boundary).
    /// Old code: proximity check |87.5-82.5|=5 < |87.5-80|=7.5 → "followed" → tooEasy only if reps bad.
    /// New code: early tooEasy exit fires before followedDirectionalTarget (87.5 >= 82.5+5) → tooEasy.
    @Test @MainActor func weightIncrease_largeOvershoot_atCapBoundary_returnsTooEasy() throws {
        let context = try TestDataFactory.makeContext()
        // barbell_bench_press → chest + barbell → increment = 2.5kg. cap = new + 5 = 87.5.
        // actual=87.5 exactly at cap → NOT followed → tooEasy (suggestion too conservative).
        let (event, perf, _) = makeSetScopedContext(context: context, actualWeight: 87.5, actualReps: 8, targetWeight: 80, repRangeMode: .range, lowerRange: 6, upperRange: 10)
        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 80, newValue: 82.5)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .tooEasy, "Athlete loaded 5kg above suggested new target — suggestion was too conservative")
    }

    /// Weight increase 80→82.5; athlete loaded 84 (= new + 1.5, within tolerance of new).
    /// Modest overshoot is within ±tolerance of the new target → still "followed".
    /// reps=8 in range [6-10] → good (normal path, not affected by overshoot cap).
    @Test @MainActor func weightIncrease_withinToleranceOvershoot_countsAsFollowed_returnsGood() throws {
        let context = try TestDataFactory.makeContext()
        // actual=84, new=82.5: |84-82.5|=1.5 <= tol=2.5 → within tolerance → followed → reps=8 in-range → good
        let (event, perf, _) = makeSetScopedContext(context: context, actualWeight: 84, actualReps: 8, targetWeight: 80, repRangeMode: .range, lowerRange: 6, upperRange: 10)
        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 80, newValue: 82.5)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .good, "Modest overshoot within tolerance should still count as followed")
    }

    /// Reps increase 8→10; athlete actually did 12 reps (= new + 2 = cap boundary).
    /// Old code: proximity |12-10|=2 < |12-8|=4 → "followed" → classified only by evaluateRepsInRange.
    /// New code: early tooEasy exit fires before followedDirectionalTarget (12 >= 10+2) → tooEasy.
    @Test @MainActor func repsIncrease_largeOvershoot_atCapBoundary_returnsTooEasy() throws {
        let context = try TestDataFactory.makeContext()
        let (event, perf, _) = makeSetScopedContext(context: context, actualReps: 12, lowerRange: 6, upperRange: 10)
        let change = PrescriptionChange(changeType: .increaseReps, previousValue: 8, newValue: 10)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .tooEasy, "Athlete did 2 reps above suggested new target — suggestion was too conservative")
    }

    /// Weight decrease 100→97.5; athlete actually loaded 92.5 (= new - 2×tol = cap boundary).
    /// Old code: any value beyond the new target in the suggested downward direction counted as followed,
    /// so in-range reps could still score as good. New code: large downward overshoot means the load reduction was insufficient.
    @Test @MainActor func weightDecrease_largeOvershoot_atCapBoundary_returnsInsufficient() throws {
        let context = try TestDataFactory.makeContext()
        let (event, perf, _) = makeSetScopedContext(context: context, actualWeight: 92.5, actualReps: 8, targetWeight: 100, repRangeMode: .range, lowerRange: 6, upperRange: 10)
        let change = PrescriptionChange(changeType: .decreaseWeight, previousValue: 100, newValue: 97.5)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .insufficient, "Athlete loaded far below the suggested decreased weight — the decrease was not enough")
    }

    @Test @MainActor func assistedWeightDecrease_largeOvershoot_atCapBoundary_returnsTooEasy() throws {
        let context = try TestDataFactory.makeContext()
        let (event, perf, setPrescription) = makeSetScopedContext(context: context, actualWeight: 80, actualReps: 8, targetWeight: 100, repRangeMode: .range, lowerRange: 6, upperRange: 10)
        setPrescription.exercise?.equipmentType = .machineAssisted
        perf.equipmentType = .machineAssisted
        event.targetExercisePrescription?.equipmentType = .machineAssisted
        event.triggerPerformance?.equipmentType = .machineAssisted

        let change = PrescriptionChange(changeType: .decreaseWeight, previousValue: 100, newValue: 90)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .tooEasy, "On assisted movements, going well below the suggested assistance means the harder change was too conservative.")
    }

    /// Reps decrease 10→8; athlete actually did 6 reps (= new - 2 = cap boundary).
    /// Old code: this still counted as followed and could score as good when 6 was in-range.
    /// New code: large downward overshoot means the rep reduction was insufficient.
    @Test @MainActor func repsDecrease_largeOvershoot_atCapBoundary_returnsInsufficient() throws {
        let context = try TestDataFactory.makeContext()
        let (event, perf, _) = makeSetScopedContext(context: context, actualReps: 6, lowerRange: 6, upperRange: 12)
        let change = PrescriptionChange(changeType: .decreaseReps, previousValue: 10, newValue: 8)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .insufficient, "Athlete performed far below the suggested decreased rep target — the decrease was not enough")
    }

    @Test @MainActor func weightChange_targetMode_oneBelowTarget_isStillGood() throws {
        let context = try TestDataFactory.makeContext()
        let (event, perf, _) = makeSetScopedContext(context: context, actualWeight: 102.5, actualReps: 7, targetWeight: 100, repRangeMode: .target, targetReps: 8)
        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 100, newValue: 102.5)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .good, "Target mode should treat target-1 reps as acceptable outcome evidence")
    }

    @Test @MainActor func repsChange_targetMode_oneBelowTarget_isStillGood() throws {
        let context = try TestDataFactory.makeContext()
        let (event, perf, _) = makeSetScopedContext(context: context, actualReps: 7, repRangeMode: .target, targetReps: 8)
        let change = PrescriptionChange(changeType: .increaseReps, previousValue: 6, newValue: 8)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .good, "Target mode reps changes should not mark target-1 execution as too aggressive")
    }

    @Test @MainActor func restChange_targetMode_oneBelowTarget_isStillGood() throws {
        let context = try TestDataFactory.makeContext()
        let (event, perf, _) = makeRestChangeContext(context: context, oldRest: 90, actualRestOwner: 120, actualDownstreamReps: 7, triggerDownstreamReps: 5, repRangeMode: .target, targetReps: 8)
        let change = PrescriptionChange(changeType: .increaseRest, previousValue: 90, newValue: 120)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .good, "Target mode rest changes should stay aligned with target-1 outcome softening")
    }

    @Test @MainActor func weightChange_targetMode_twoBelowTarget_remainsTooAggressive() throws {
        let context = try TestDataFactory.makeContext()
        let (event, perf, _) = makeSetScopedContext(context: context, actualWeight: 102.5, actualReps: 6, targetWeight: 100, repRangeMode: .target, targetReps: 8)
        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 100, newValue: 102.5)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .tooAggressive, "Target mode should still treat target-2 reps as too aggressive")
    }

    /// Rep range lower-bound change: frozen upper=12, live upper mutated to 20 before evaluation.
    /// Sets at 14 reps — tooEasy against frozen ceiling 12 (14 > 12+buffer), good against live ceiling 20.
    @Test @MainActor func repRangeLowerChange_usesFrozenCeiling_notLiveCeiling() throws {
        let context = try TestDataFactory.makeContext()
        // Prescription: range 8-12. Will suggest raising floor to 10.
        let (event, perf) = makeRepRangeContext(context: context, actualRepsPerSet: [14, 14, 14], lowerRange: 8, upperRange: 12)

        // Mutate live upper to 20 after snapshot capture.
        // The event's prescription still has the same repRange object, so we mutate via perf.
        perf.prescription?.repRange?.upperRange = 20

        // Change: raise floor from 8 → 10. effectiveNewRepRange should use frozen ceiling=12, not live 20.
        let change = PrescriptionChange(changeType: .increaseRepRangeLower, previousValue: 8, newValue: 10)
        context.insert(change)

        // With frozen ceiling=12, span=2, buffer=1: 14 > 12+1=13 → tooEasy.
        // With live ceiling=20, span=10, buffer=3: 14 ≤ 20+3=23 → good.
        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .tooEasy, "Should use frozen ceiling 12, not live ceiling 20")
    }
}

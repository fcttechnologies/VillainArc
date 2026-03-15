import SwiftData
import Foundation
import Testing
@testable import VillainArc

// Tests for OutcomeRuleEngine: verifies that each change type produces the correct
// outcome signal across all outcome paths (good / tooAggressive / tooEasy / ignored / nil).
@Suite(.serialized)
struct OutcomeRuleEngineTests {

    // MARK: - Helpers

    /// Creates a prescription with a single working set, a matching exercise performance
    /// with the given actual values, and a set-scoped SuggestionEvent targeting that set.
    @MainActor
    private func makeSetScopedContext(
        context: ModelContext,
        actualWeight: Double = 100,
        actualReps: Int = 8,
        actualRest: Int = 90,
        actualSetType: ExerciseSetType = .working,
        targetWeight: Double = 100,
        repRangeMode: RepRangeMode = .range,
        lowerRange: Int = 6,
        upperRange: Int = 10,
        targetReps: Int = 8,
        category: SuggestionCategory = .performance
    ) -> (event: SuggestionEvent, perf: ExercisePerformance, setPrescription: SetPrescription) {
        let (_, prescription) = TestDataFactory.makePrescription(
            context: context,
            workingSets: 1,
            targetWeight: targetWeight,
            targetReps: targetReps,
            repRangeMode: repRangeMode,
            lowerRange: lowerRange,
            upperRange: upperRange
        )
        let setPrescription = prescription.sortedSets.first!
        let session = TestDataFactory.makeSession(context: context)
        let perf = TestDataFactory.makePerformance(
            context: context,
            session: session,
            prescription: prescription,
            sets: [(weight: actualWeight, reps: actualReps, rest: actualRest, type: actualSetType)]
        )
        let event = SuggestionEvent(
            category: category,
            catalogID: prescription.catalogID,
            sessionFrom: nil,
            targetExercisePrescription: prescription,
            targetSetPrescription: setPrescription,
            triggerTargetSetID: setPrescription.id,
            triggerPerformanceSnapshot: .empty,
            triggerTargetSnapshot: ExerciseTargetSnapshot(prescription: prescription),
            trainingStyle: .straightSets
        )
        context.insert(event)
        return (event, perf, setPrescription)
    }

    /// Creates a prescription with N working sets at the given actual rep counts,
    /// and a non-set-scoped exercise-level event for rep range change tests.
    @MainActor
    private func makeRepRangeContext(
        context: ModelContext,
        actualRepsPerSet: [Int],
        lowerRange: Int = 6,
        upperRange: Int = 10,
        repRangeMode: RepRangeMode = .range,
        targetRepsForTarget: Int = 10
    ) -> (event: SuggestionEvent, perf: ExercisePerformance) {
        let (_, prescription) = TestDataFactory.makePrescription(
            context: context,
            workingSets: actualRepsPerSet.count,
            targetWeight: 100,
            targetReps: 8,
            repRangeMode: repRangeMode,
            lowerRange: lowerRange,
            upperRange: upperRange
        )
        if repRangeMode == .target {
            prescription.repRange?.targetReps = targetRepsForTarget
        }
        let session = TestDataFactory.makeSession(context: context)
        let perf = TestDataFactory.makePerformance(
            context: context,
            session: session,
            prescription: prescription,
            sets: actualRepsPerSet.map { (weight: 100.0, reps: $0, rest: 90, type: ExerciseSetType.working) }
        )
        let event = SuggestionEvent(
            category: .repRangeConfiguration,
            catalogID: prescription.catalogID,
            sessionFrom: nil,
            targetExercisePrescription: prescription,
            triggerPerformanceSnapshot: .empty,
            triggerTargetSnapshot: ExerciseTargetSnapshot(prescription: prescription),
            trainingStyle: .straightSets
        )
        context.insert(event)
        return (event, perf)
    }

    // MARK: - Weight Change: Ignored

    @Test @MainActor
    func weightChange_ignored_whenActualWeightStaysAtOldTarget() throws {
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

    @Test @MainActor
    func weightChange_ignored_whenActualMovesAwayFromNewTarget() throws {
        let context = try TestDataFactory.makeContext()
        // actual=90 is farther from new (102.5) than from old (100) and below old → ignored
        let (event, perf, _) = makeSetScopedContext(context: context, actualWeight: 90, targetWeight: 100)
        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 100, newValue: 102.5)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .ignored)
    }

    // MARK: - Weight Change: Good

    @Test @MainActor
    func weightChange_good_whenAtNewWeightAndRepsInRange() throws {
        let context = try TestDataFactory.makeContext()
        // range 6-10, buffer=2; reps=8 in [6, 10] → good
        let (event, perf, _) = makeSetScopedContext(context: context, actualWeight: 102.5, actualReps: 8, targetWeight: 100, lowerRange: 6, upperRange: 10)
        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 100, newValue: 102.5)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .good)
        #expect((signal?.confidence ?? 0) >= 0.8)
    }

    @Test @MainActor
    func weightChange_good_whenRepsExactlyAtCeilingPlusBuffer() throws {
        let context = try TestDataFactory.makeContext()
        // range 6-10, span=4 → buffer=2; ceiling+buffer=12; reps=12 is still good (not above)
        let (event, perf, _) = makeSetScopedContext(context: context, actualWeight: 102.5, actualReps: 12, targetWeight: 100, lowerRange: 6, upperRange: 10)
        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 100, newValue: 102.5)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .good)
    }

    // MARK: - Weight Change: Too Aggressive

    @Test @MainActor
    func weightChange_tooAggressive_whenAtNewWeightAndRepsBelowFloor() throws {
        let context = try TestDataFactory.makeContext()
        // reps=4, floor=6 → can't hold even the lower bound of the range
        let (event, perf, _) = makeSetScopedContext(context: context, actualWeight: 102.5, actualReps: 4, targetWeight: 100, lowerRange: 6, upperRange: 10)
        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 100, newValue: 102.5)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .tooAggressive)
    }

    @Test @MainActor
    func weightChange_tooAggressive_targetMode_whenRepsBelowTarget() throws {
        let context = try TestDataFactory.makeContext()
        // target mode, target=8; reps=5 → tooAggressive
        let (event, perf, _) = makeSetScopedContext(
            context: context, actualWeight: 102.5, actualReps: 5, targetWeight: 100,
            repRangeMode: .target, targetReps: 8
        )
        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 100, newValue: 102.5)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .tooAggressive)
    }

    // MARK: - Weight Change: Too Easy

    @Test @MainActor
    func weightChange_tooEasy_whenAtNewWeightAndRepsAboveCeilingPlusBuffer() throws {
        let context = try TestDataFactory.makeContext()
        // range 6-10, buffer=2; reps=14 > 12 → tooEasy
        let (event, perf, _) = makeSetScopedContext(context: context, actualWeight: 102.5, actualReps: 14, targetWeight: 100, lowerRange: 6, upperRange: 10)
        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 100, newValue: 102.5)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .tooEasy)
    }

    // MARK: - Decrease Weight Change

    @Test @MainActor
    func decreaseWeightChange_ignored_whenActualStaysAtOldWeight() throws {
        let context = try TestDataFactory.makeContext()
        // old=100, new=90: abs(100-90)=10 > tolerance(2.5) → not followed.
        // abs(100-100)=0 ≤ 2.5 → "stayed near old" → .ignored(0.9)
        let (event, perf, _) = makeSetScopedContext(context: context, actualWeight: 100, targetWeight: 100)
        let change = PrescriptionChange(changeType: .decreaseWeight, previousValue: 100, newValue: 90)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .ignored)
    }

    @Test @MainActor
    func decreaseWeightChange_good_whenAtNewWeightAndRepsInRange() throws {
        let context = try TestDataFactory.makeContext()
        let (event, perf, _) = makeSetScopedContext(context: context, actualWeight: 97.5, actualReps: 8, targetWeight: 100, lowerRange: 6, upperRange: 10)
        let change = PrescriptionChange(changeType: .decreaseWeight, previousValue: 100, newValue: 97.5)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .good)
    }

    // MARK: - Weight Change: Not Set Scoped → nil

    @Test @MainActor
    func weightChange_returnsNil_whenEventNotSetScoped() throws {
        let context = try TestDataFactory.makeContext()
        let (_, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1, targetWeight: 100)
        let session = TestDataFactory.makeSession(context: context)
        let perf = TestDataFactory.makePerformance(context: context, session: session, prescription: prescription,
            sets: [(weight: 102.5, reps: 8, rest: 90, type: .working)])

        let event = SuggestionEvent(
            category: .performance,
            catalogID: prescription.catalogID,
            sessionFrom: nil,
            targetExercisePrescription: prescription,
            triggerPerformanceSnapshot: .empty,
            triggerTargetSnapshot: ExerciseTargetSnapshot(prescription: prescription),
            trainingStyle: .straightSets
        )
        context.insert(event)

        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 100, newValue: 102.5)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal == nil)
    }

    // MARK: - Reps Change

    @Test @MainActor
    func repsChange_ignored_whenActualRepsStayAtOldTarget() throws {
        let context = try TestDataFactory.makeContext()
        let (event, perf, _) = makeSetScopedContext(context: context, actualReps: 8)
        let change = PrescriptionChange(changeType: .increaseReps, previousValue: 8, newValue: 10)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .ignored)
    }

    @Test @MainActor
    func repsChange_good_whenFollowsNewTargetAndInRange() throws {
        let context = try TestDataFactory.makeContext()
        // increase to 10, range 6-12; reps=10 → in range → good
        let (event, perf, _) = makeSetScopedContext(context: context, actualReps: 10, lowerRange: 6, upperRange: 12)
        let change = PrescriptionChange(changeType: .increaseReps, previousValue: 8, newValue: 10)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .good)
    }

    @Test @MainActor
    func decreaseRepsChange_tooAggressive_whenFollowedButBelowRangeFloor() throws {
        let context = try TestDataFactory.makeContext()
        // decrease from 8 to 4; reps=4, floor=6 → below floor → tooAggressive
        let (event, perf, _) = makeSetScopedContext(context: context, actualReps: 4, lowerRange: 6, upperRange: 10)
        let change = PrescriptionChange(changeType: .decreaseReps, previousValue: 8, newValue: 4)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .tooAggressive)
    }

    @Test @MainActor
    func repsChange_tooEasy_whenActualExceedsCeilingPlusBuffer() throws {
        let context = try TestDataFactory.makeContext()
        // increase to 10, range 6-10, buffer=2; reps=14 > 12 → tooEasy
        let (event, perf, _) = makeSetScopedContext(context: context, actualReps: 14, lowerRange: 6, upperRange: 10)
        let change = PrescriptionChange(changeType: .increaseReps, previousValue: 8, newValue: 10)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .tooEasy)
    }

    // MARK: - Rest Change

    @Test @MainActor
    func restChange_ignored_whenActualRestStaysAtOldTarget() throws {
        let context = try TestDataFactory.makeContext()
        // actual=90, old=90, new=120: within 15s of old → ignored
        let (event, perf, _) = makeSetScopedContext(context: context, actualReps: 8, actualRest: 90, lowerRange: 6, upperRange: 10)
        let change = PrescriptionChange(changeType: .increaseRest, previousValue: 90, newValue: 120)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .ignored)
    }

    @Test @MainActor
    func restChange_good_whenFollowedAndRepsInRange() throws {
        let context = try TestDataFactory.makeContext()
        let (event, perf, _) = makeSetScopedContext(context: context, actualReps: 8, actualRest: 120, lowerRange: 6, upperRange: 10)
        let change = PrescriptionChange(changeType: .increaseRest, previousValue: 90, newValue: 120)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .good)
    }

    @Test @MainActor
    func restChange_tooAggressive_whenFollowedButRepsBelowFloor() throws {
        let context = try TestDataFactory.makeContext()
        // rest increased but user still failed to hit reps
        let (event, perf, _) = makeSetScopedContext(context: context, actualReps: 4, actualRest: 120, lowerRange: 6, upperRange: 10)
        let change = PrescriptionChange(changeType: .increaseRest, previousValue: 90, newValue: 120)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .tooAggressive)
    }

    @Test @MainActor
    func restChange_tooEasy_whenFollowedAndRepsAboveCeilingPlusBuffer() throws {
        let context = try TestDataFactory.makeContext()
        // rest increased, user easily exceeds range
        let (event, perf, _) = makeSetScopedContext(context: context, actualReps: 14, actualRest: 120, lowerRange: 6, upperRange: 10)
        let change = PrescriptionChange(changeType: .increaseRest, previousValue: 90, newValue: 120)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .tooEasy)
    }

    @Test @MainActor
    func restChange_ignored_whenActualMovesAwayFromNewRestTarget() throws {
        let context = try TestDataFactory.makeContext()
        // actual=60, old=90, new=120: moved away from both (farther from new than old)
        let (event, perf, _) = makeSetScopedContext(context: context, actualReps: 8, actualRest: 60, lowerRange: 6, upperRange: 10)
        let change = PrescriptionChange(changeType: .increaseRest, previousValue: 90, newValue: 120)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .ignored)
    }

    // MARK: - Set Type Change

    @Test @MainActor
    func setTypeChange_good_whenSetTypeMatchesNewTarget() throws {
        let context = try TestDataFactory.makeContext()
        // Suggestion was warmup→working; user performed it as working → good
        let (event, perf, _) = makeSetScopedContext(context: context, actualSetType: .working)
        let change = PrescriptionChange(
            changeType: .changeSetType,
            previousValue: Double(ExerciseSetType.warmup.rawValue),
            newValue: Double(ExerciseSetType.working.rawValue)
        )
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .good)
        #expect((signal?.confidence ?? 0) >= 0.9)
    }

    @Test @MainActor
    func setTypeChange_ignored_whenSetTypeDoesNotMatchNewTarget() throws {
        let context = try TestDataFactory.makeContext()
        // Suggestion was warmup→working; user still performed it as warmup → ignored
        let (event, perf, _) = makeSetScopedContext(context: context, actualSetType: .warmup)
        let change = PrescriptionChange(
            changeType: .changeSetType,
            previousValue: Double(ExerciseSetType.warmup.rawValue),
            newValue: Double(ExerciseSetType.working.rawValue)
        )
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .ignored)
    }

    // MARK: - Rep Range Change

    @Test @MainActor
    func repRangeUpperChange_good_whenMostSetsLandInNewRange() throws {
        let context = try TestDataFactory.makeContext()
        // New upper=10, lower=6; sets=[8, 9, 10] → 3/3 in range → good
        let (event, perf) = makeRepRangeContext(context: context, actualRepsPerSet: [8, 9, 10], lowerRange: 6, upperRange: 10)
        let change = PrescriptionChange(changeType: .increaseRepRangeUpper, previousValue: 8, newValue: 10)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .good)
    }

    @Test @MainActor
    func repRangeLowerChange_tooAggressive_whenManySetsLandBelowNewFloor() throws {
        let context = try TestDataFactory.makeContext()
        // Raise lower from 6→10 (upper=14). sets=[8,8,8,8]: all < new floor 10.
        // abs(8-10)=2 ≤ 2 → near boundary → guard passes. belowFloor=4 ≥ 4/2=2 → tooAggressive.
        let (event, perf) = makeRepRangeContext(context: context, actualRepsPerSet: [8, 8, 8, 8], lowerRange: 6, upperRange: 14)
        let change = PrescriptionChange(changeType: .increaseRepRangeLower, previousValue: 6, newValue: 10)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .tooAggressive)
    }

    @Test @MainActor
    func repRangeUpperChange_tooEasy_whenManySetsExceedCeilingPlusBuffer() throws {
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

    @Test @MainActor
    func repRangeLowerChange_ignored_whenSetsNotInRangeAndNotNearBoundary() throws {
        let context = try TestDataFactory.makeContext()
        // Raise lower from 6→10; upper=14; sets=[4,4,4]: ratio=0, abs(4-10)=6>2, abs(4-14)=10>2 → ignored
        let (event, perf) = makeRepRangeContext(context: context, actualRepsPerSet: [4, 4, 4], lowerRange: 6, upperRange: 14)
        let change = PrescriptionChange(changeType: .increaseRepRangeLower, previousValue: 6, newValue: 10)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .ignored)
    }

    @Test @MainActor
    func repRangeTargetChange_good_whenSetsHitNewTarget() throws {
        let context = try TestDataFactory.makeContext()
        // Target mode, new target=10; sets=[10,10] → floor=10, ceiling=10; ratio=1.0 → good
        let (event, perf) = makeRepRangeContext(
            context: context,
            actualRepsPerSet: [10, 10],
            repRangeMode: .target,
            targetRepsForTarget: 10
        )
        let change = PrescriptionChange(changeType: .increaseRepRangeTarget, previousValue: 8, newValue: 10)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .good)
    }

    @Test @MainActor
    func repRangeTargetChange_tooAggressive_whenSetsBelowNewTarget() throws {
        let context = try TestDataFactory.makeContext()
        // Target mode, new target=10; sets=[8,8] → abs(8-10)=2 ≤ 2 → passes boundary guard.
        // belowFloor=[8,8] (both < 10), count=2 ≥ 2/2=1 → tooAggressive.
        let (event, perf) = makeRepRangeContext(
            context: context,
            actualRepsPerSet: [8, 8],
            repRangeMode: .target,
            targetRepsForTarget: 10
        )
        let change = PrescriptionChange(changeType: .increaseRepRangeTarget, previousValue: 8, newValue: 10)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .tooAggressive)
    }

    // MARK: - tooEasyBuffer Boundary Behavior

    @Test @MainActor
    func tooEasyBuffer_narrowRange_repsExactlyAtCeilingPlusOneIsGood() throws {
        let context = try TestDataFactory.makeContext()
        // range 8-10, span=2 ≤ 3 → buffer=1; ceiling+buffer=11; reps=11 → good (exactly at limit)
        let (event, perf, _) = makeSetScopedContext(context: context, actualWeight: 102.5, actualReps: 11, targetWeight: 100, lowerRange: 8, upperRange: 10)
        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 100, newValue: 102.5)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .good)
    }

    @Test @MainActor
    func tooEasyBuffer_narrowRange_repsAboveCeilingPlusOneIsTooEasy() throws {
        let context = try TestDataFactory.makeContext()
        // range 8-10, buffer=1; reps=12 > 11 → tooEasy
        let (event, perf, _) = makeSetScopedContext(context: context, actualWeight: 102.5, actualReps: 12, targetWeight: 100, lowerRange: 8, upperRange: 10)
        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 100, newValue: 102.5)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .tooEasy)
    }

    @Test @MainActor
    func tooEasyBuffer_wideRange_repsExactlyAtCeilingPlusThreeIsGood() throws {
        let context = try TestDataFactory.makeContext()
        // range 6-14, span=8 > 6 → buffer=3; ceiling+buffer=17; reps=17 → good
        let (event, perf, _) = makeSetScopedContext(context: context, actualWeight: 102.5, actualReps: 17, targetWeight: 100, lowerRange: 6, upperRange: 14)
        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 100, newValue: 102.5)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .good)
    }

    @Test @MainActor
    func tooEasyBuffer_wideRange_repsAboveCeilingPlusThreeIsTooEasy() throws {
        let context = try TestDataFactory.makeContext()
        // range 6-14, buffer=3; reps=18 > 17 → tooEasy
        let (event, perf, _) = makeSetScopedContext(context: context, actualWeight: 102.5, actualReps: 18, targetWeight: 100, lowerRange: 6, upperRange: 14)
        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 100, newValue: 102.5)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .tooEasy)
    }

    // MARK: - Warmup Weight Change (warmupCalibration category)

    @Test @MainActor
    func warmupWeightChange_ignored_whenWarmupLoadNotFollowed() throws {
        let context = try TestDataFactory.makeContext()
        // Warmup stayed at old load (60), suggestion was to increase to 70 → ignored
        let (event, perf, _) = makeSetScopedContext(
            context: context,
            actualWeight: 60,
            actualSetType: .warmup,
            targetWeight: 60,
            category: .warmupCalibration
        )
        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 60, newValue: 70)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .ignored)
    }

    @Test @MainActor
    func warmupWeightChange_good_whenWarmupFollowedAndLightRelativeToWorkingLoad() throws {
        let context = try TestDataFactory.makeContext()
        // Build prescription: 1 warmup + 1 working set
        let (_, prescription) = TestDataFactory.makePrescription(
            context: context, workingSets: 1, targetWeight: 100, targetReps: 8, lowerRange: 6, upperRange: 10
        )
        let warmupSlot = SetPrescription(exercisePrescription: prescription, setType: .warmup, targetWeight: 60, targetReps: 10, targetRest: 60, index: 0)
        // Reindex: warmup=0, working=1
        prescription.sortedSets.forEach { $0.index += 1 }
        prescription.sets?.insert(warmupSlot, at: 0)

        let session = TestDataFactory.makeSession(context: context)
        // warmup=70, working=100 → 70 < 100*0.9=90 → good
        let perf = TestDataFactory.makePerformance(
            context: context, session: session, prescription: prescription,
            sets: [
                (weight: 70, reps: 10, rest: 60, type: .warmup),
                (weight: 100, reps: 8, rest: 90, type: .working)
            ]
        )

        let warmupSetPerf = perf.sortedSets.first(where: { $0.type == .warmup })!
        let warmupSetPrescription = warmupSetPerf.prescription!

        let event = SuggestionEvent(
            category: .warmupCalibration,
            catalogID: prescription.catalogID,
            sessionFrom: nil,
            targetExercisePrescription: prescription,
            targetSetPrescription: warmupSetPrescription,
            triggerTargetSetID: warmupSetPrescription.id,
            triggerPerformanceSnapshot: .empty,
            triggerTargetSnapshot: ExerciseTargetSnapshot(prescription: prescription),
            trainingStyle: .straightSets
        )
        context.insert(event)

        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 60, newValue: 70)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .good)
    }

    @Test @MainActor
    func warmupWeightChange_tooAggressive_whenWarmupLoadTooCloseToWorkingLoad() throws {
        let context = try TestDataFactory.makeContext()
        // Build prescription: 1 warmup + 1 working set
        let (_, prescription) = TestDataFactory.makePrescription(
            context: context, workingSets: 1, targetWeight: 100, targetReps: 8, lowerRange: 6, upperRange: 10
        )
        let warmupSlot = SetPrescription(exercisePrescription: prescription, setType: .warmup, targetWeight: 80, targetReps: 10, targetRest: 60, index: 0)
        prescription.sortedSets.forEach { $0.index += 1 }
        prescription.sets?.insert(warmupSlot, at: 0)

        let session = TestDataFactory.makeSession(context: context)
        // warmup=95, working=100 → 95 >= 100*0.9=90 → tooAggressive
        let perf = TestDataFactory.makePerformance(
            context: context, session: session, prescription: prescription,
            sets: [
                (weight: 95, reps: 10, rest: 60, type: .warmup),
                (weight: 100, reps: 8, rest: 90, type: .working)
            ]
        )

        let warmupSetPerf = perf.sortedSets.first(where: { $0.type == .warmup })!
        let warmupSetPrescription = warmupSetPerf.prescription!

        let event = SuggestionEvent(
            category: .warmupCalibration,
            catalogID: prescription.catalogID,
            sessionFrom: nil,
            targetExercisePrescription: prescription,
            targetSetPrescription: warmupSetPrescription,
            triggerTargetSetID: warmupSetPrescription.id,
            triggerPerformanceSnapshot: .empty,
            triggerTargetSnapshot: ExerciseTargetSnapshot(prescription: prescription),
            trainingStyle: .straightSets
        )
        context.insert(event)

        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 80, newValue: 95)
        context.insert(change)

        let signal = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: perf, trainingStyle: .straightSets)

        #expect(signal?.outcome == .tooAggressive)
    }
}

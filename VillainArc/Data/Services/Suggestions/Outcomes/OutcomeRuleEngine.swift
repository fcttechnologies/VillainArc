import Foundation

/// Deterministic rules used to score a change outcome from actual workout data.
/// `OutcomeResolver` runs this first, then optionally lets AI override during merge.
struct OutcomeRuleEngine {

    /// Routes each change type to the matching rule evaluator.
    static func evaluate(change: PrescriptionChange, event: SuggestionEvent, exercisePerf: ExercisePerformance, trainingStyle: TrainingStyle?) -> OutcomeSignal? {
        let regularSets = relevantWorkingSets(in: exercisePerf, trainingStyle: trainingStyle)

        switch change.changeType {
        case .increaseWeight, .decreaseWeight:
            return evaluateWeightChange(change: change, event: event, exercisePerf: exercisePerf, trainingStyle: trainingStyle)
        case .increaseReps, .decreaseReps:
            return evaluateRepsChange(change: change, event: event, exercisePerf: exercisePerf)
        case .increaseRest, .decreaseRest:
            return evaluateSetRestChange(change: change, event: event, exercisePerf: exercisePerf)
        case .increaseRepRangeLower, .decreaseRepRangeLower,
             .increaseRepRangeUpper, .decreaseRepRangeUpper,
             .increaseRepRangeTarget, .decreaseRepRangeTarget,
             .changeRepRangeMode:
            return evaluateRepRangeChange(change: change, regularSets: regularSets, exercisePerf: exercisePerf)
        case .changeSetType:
            return evaluateSetTypeChange(change: change, event: event, exercisePerf: exercisePerf)
        }
    }

    private static func relevantWorkingSets(in exercisePerf: ExercisePerformance, trainingStyle: TrainingStyle?) -> [SetPerformance] {
        let progressionSets = MetricsCalculator.selectProgressionSets(from: exercisePerf, overrideStyle: trainingStyle)
        let workingSets = progressionSets.filter { $0.type == .working }
        return workingSets.isEmpty ? progressionSets : workingSets
    }

    // MARK: - Match Set Performance

    private static func matchSetPerformance(for event: SuggestionEvent, in exercisePerf: ExercisePerformance) -> SetPerformance? {
        let completeSets = exercisePerf.sortedSets.filter { $0.complete }

        if let setPrescriptionID = event.targetSetPrescription?.id,
           let matched = completeSets.first(where: { $0.prescription?.id == setPrescriptionID }) {
            return matched
        }

        return nil
    }

    // MARK: - Weight Change

    private static func evaluateWeightChange(change: PrescriptionChange, event: SuggestionEvent, exercisePerf: ExercisePerformance, trainingStyle: TrainingStyle?) -> OutcomeSignal? {
        guard event.isSetScoped,
              let setPerf = matchSetPerformance(for: event, in: exercisePerf) else { return nil }

        if event.category == .warmupCalibration {
            return evaluateWarmupWeightChange(change: change, setPerf: setPerf, exercisePerf: exercisePerf, trainingStyle: trainingStyle)
        }

        let newWeight = change.newValue
        let oldWeight = change.previousValue

        // Tolerance comes from equipment/muscle-aware increment sizing.
        let baseWeight = newWeight > 0 ? newWeight : oldWeight
        let weightStep = weightTolerance(for: exercisePerf, baseWeight: baseWeight)
        let actualWeight = setPerf.weight

        let followedDirection = followedDirectionalTarget(actual: actualWeight, old: oldWeight, new: newWeight, tolerance: weightStep)

        // If the athlete never got near the new target or moved in the suggested direction, mark as ignored.
        guard followedDirection else {
            if abs(actualWeight - oldWeight) <= weightStep {
                return OutcomeSignal(outcome: .ignored, confidence: 0.9, reason: "Actual weight (\(actualWeight)) stayed near old target (\(oldWeight)), new target (\(newWeight)) not attempted.")
            }
            return OutcomeSignal(outcome: .ignored, confidence: 0.7, reason: "Actual weight (\(actualWeight)) not close to new target (\(newWeight)).")
        }

        // Once target load was attempted, classify by rep performance.
        return evaluateRepsInRange(
            actualReps: setPerf.reps,
            exercisePerf: exercisePerf,
            context: "weight change to \(newWeight)"
        )
    }

    private static func evaluateWarmupWeightChange(change: PrescriptionChange, setPerf: SetPerformance, exercisePerf: ExercisePerformance, trainingStyle: TrainingStyle?) -> OutcomeSignal? {
        let newWeight = change.newValue
        let oldWeight = change.previousValue
        let baseWeight = newWeight > 0 ? newWeight : oldWeight
        let weightStep = weightTolerance(for: exercisePerf, baseWeight: baseWeight)
        let actualWeight = setPerf.weight

        let followedDirection = followedDirectionalTarget(actual: actualWeight, old: oldWeight, new: newWeight, tolerance: weightStep)
        guard followedDirection else {
            if abs(actualWeight - oldWeight) <= weightStep {
                return OutcomeSignal(outcome: .ignored, confidence: 0.9, reason: "Warmup load stayed near the old target (\(oldWeight)).")
            }
            return OutcomeSignal(outcome: .ignored, confidence: 0.7, reason: "Warmup load (\(actualWeight)) did not move toward the new target (\(newWeight)).")
        }

        guard setPerf.type == .warmup else {
            return OutcomeSignal(outcome: .tooAggressive, confidence: 0.85, reason: "The adjusted set no longer behaved like a warmup.")
        }

        if let anchorWeight = workingAnchorWeight(in: exercisePerf, trainingStyle: trainingStyle),
           anchorWeight > 0,
           actualWeight >= anchorWeight * 0.9 {
            return OutcomeSignal(outcome: .tooAggressive, confidence: 0.85, reason: "Warmup load (\(actualWeight)) was too close to the main working load (\(anchorWeight)).")
        }

        return OutcomeSignal(outcome: .good, confidence: 0.9, reason: "Warmup load moved toward the new target while still behaving like a warmup.")
    }

    // MARK: - Reps Change

    private static func evaluateRepsChange(change: PrescriptionChange, event: SuggestionEvent, exercisePerf: ExercisePerformance) -> OutcomeSignal? {
        guard event.isSetScoped,
              let setPerf = matchSetPerformance(for: event, in: exercisePerf) else { return nil }

        let newReps = Int(change.newValue)
        let oldReps = Int(change.previousValue)

        let actualReps = setPerf.reps

        // Accept either a close hit or clear movement in the suggested direction.
        let followedDirection = followedDirectionalTarget(actual: Double(actualReps), old: Double(oldReps), new: Double(newReps), tolerance: 1)
        guard followedDirection else {
            if abs(actualReps - oldReps) <= 1 {
                return OutcomeSignal(outcome: .ignored, confidence: 0.9, reason: "Actual reps (\(actualReps)) stayed at old target (\(oldReps)).")
            }
            return OutcomeSignal(outcome: .ignored, confidence: 0.7, reason: "Actual reps (\(actualReps)) not close to new target (\(newReps)).")
        }

        return evaluateRepsInRange(
            actualReps: actualReps,
            exercisePerf: exercisePerf,
            context: "reps change to \(newReps)"
        )
    }

    // MARK: - Set-Level Rest Change

    private static func evaluateSetRestChange(change: PrescriptionChange, event: SuggestionEvent, exercisePerf: ExercisePerformance) -> OutcomeSignal? {
        guard event.isSetScoped,
              let setPerf = matchSetPerformance(for: event, in: exercisePerf) else { return nil }

        let newRest = Int(change.newValue)
        let oldRest = Int(change.previousValue)

        let actualRest = setPerf.restSeconds

        let followedDirection = followedDirectionalTarget(actual: Double(actualRest), old: Double(oldRest), new: Double(newRest), tolerance: 15)

        // Rest adherence window: ±15s counts as following target. Overshooting in the suggested direction also counts.
        guard followedDirection else {
            if abs(actualRest - oldRest) <= 15 {
                return OutcomeSignal(outcome: .ignored, confidence: 0.9, reason: "Actual rest (\(actualRest)s) stayed near old target (\(oldRest)s).")
            }
            return OutcomeSignal(outcome: .ignored, confidence: 0.7, reason: "Actual rest (\(actualRest)s) not close to new target (\(newRest)s).")
        }

        return evaluateRepsInRange(
            actualReps: setPerf.reps,
            exercisePerf: exercisePerf,
            context: "rest change to \(newRest)s"
        )
    }

    // MARK: - Rep Range Change

    private static func evaluateRepRangeChange(change: PrescriptionChange, regularSets: [SetPerformance], exercisePerf: ExercisePerformance) -> OutcomeSignal? {
        guard !regularSets.isEmpty else { return nil }

        // Evaluate against the post-change range/mode, not the pre-change value.
        let newRange = effectiveNewRepRange(change: change, exercisePerf: exercisePerf)
        guard let floor = newRange.floor, let ceiling = newRange.ceiling else { return nil }

        let reps = regularSets.map { $0.reps }
        let inRange = reps.filter { $0 >= floor && $0 <= ceiling }
        let ratio = Double(inRange.count) / Double(reps.count)

        // Require at least 50% in range, or that all sets are near boundaries (within 2 reps).
        guard ratio >= 0.5 || reps.allSatisfy({ abs($0 - floor) <= 2 || abs($0 - ceiling) <= 2 }) else {
            return OutcomeSignal(outcome: .ignored, confidence: 0.7, reason: "Most sets (\(reps)) didn't fall in new range (\(floor)-\(ceiling)).")
        }

        let buffer = tooEasyBuffer(floor: floor, ceiling: ceiling)
        let belowFloor = reps.filter { $0 < floor }
        let aboveCeiling = reps.filter { $0 > ceiling + buffer }

        // If at least half the sets miss in one direction, classify directional mismatch.
        if !belowFloor.isEmpty && belowFloor.count >= reps.count / 2 {
            return OutcomeSignal(outcome: .tooAggressive, confidence: 0.8, reason: "Multiple sets (\(belowFloor)) fell below the new range floor (\(floor)).")
        }
        if !aboveCeiling.isEmpty && aboveCeiling.count >= reps.count / 2 {
            return OutcomeSignal(outcome: .tooEasy, confidence: 0.8, reason: "Multiple sets (\(aboveCeiling)) exceeded the new range ceiling (\(ceiling)) + buffer (\(buffer)).")
        }
        if ratio >= 0.5 {
            return OutcomeSignal(outcome: .good, confidence: 0.85, reason: "\(Int(ratio * 100))% of sets fell within the new range (\(floor)-\(ceiling)).")
        }

        return nil
    }

    // MARK: - Set Type Change

    private static func evaluateSetTypeChange(change: PrescriptionChange, event: SuggestionEvent, exercisePerf: ExercisePerformance) -> OutcomeSignal? {
        guard let setPerf = matchSetPerformance(for: event, in: exercisePerf),
              let newType = ExerciseSetType(rawValue: Int(change.newValue)) else { return nil }

        // Type changes are binary: exact type match means success, otherwise ignored.
        if setPerf.type == newType {
            return OutcomeSignal(outcome: .good, confidence: 0.95, reason: "Set type matches the new target (\(newType)).")
        }
        return OutcomeSignal(outcome: .ignored, confidence: 0.9, reason: "Actual set type (\(setPerf.type)) doesn't match new target (\(newType)).")
    }
    private static func followedDirectionalTarget(actual: Double, old: Double, new: Double, tolerance: Double) -> Bool {
        guard tolerance >= 0 else { return false }
        if abs(actual - new) <= tolerance {
            return true
        }
        if abs(actual - new) < abs(actual - old) {
            return true
        }

        if new > old {
            return actual > new
        }
        if new < old {
            return actual < new
        }
        return false
    }

    // MARK: - Rule Helpers

    private static func evaluateRepsInRange(actualReps: Int, exercisePerf: ExercisePerformance, context: String) -> OutcomeSignal? {
        let policy = exercisePerf.repRange ?? RepRangePolicy()

        // Shared intensity classifier used by multiple rules.
        switch policy.activeMode {
        case .range:
            let floor = policy.lowerRange
            let ceiling = policy.upperRange
            let buffer = tooEasyBuffer(floor: floor, ceiling: ceiling)

            if actualReps < floor {
                return OutcomeSignal(outcome: .tooAggressive, confidence: 0.85, reason: "Reps (\(actualReps)) below range floor (\(floor)) after \(context).")
            }
            if actualReps > ceiling + buffer {
                return OutcomeSignal(outcome: .tooEasy, confidence: 0.85, reason: "Reps (\(actualReps)) above range ceiling (\(ceiling)) + buffer (\(buffer)) after \(context).")
            }
            return OutcomeSignal(outcome: .good, confidence: 0.9, reason: "Reps (\(actualReps)) within range (\(floor)-\(ceiling)) after \(context).")

        case .target:
            let target = policy.targetReps
            let buffer = tooEasyBuffer(floor: target, ceiling: target)

            if actualReps < target {
                return OutcomeSignal(outcome: .tooAggressive, confidence: 0.85, reason: "Reps (\(actualReps)) below target (\(target)) after \(context).")
            }
            if actualReps > target + buffer {
                return OutcomeSignal(outcome: .tooEasy, confidence: 0.85, reason: "Reps (\(actualReps)) above target (\(target)) + buffer (\(buffer)) after \(context).")
            }
            return OutcomeSignal(outcome: .good, confidence: 0.9, reason: "Reps (\(actualReps)) on target (\(target)) after \(context).")

        case .notSet:
            return nil
        }
    }

    // Wider ranges allow a larger "too easy" overshoot buffer.
    private static func tooEasyBuffer(floor: Int, ceiling: Int) -> Int {
        let span = ceiling - floor
        if span <= 0 { return 1 }
        if span <= 3 { return 1 }
        if span <= 6 { return 2 }
        return 3
    }

    private static func weightTolerance(for exercisePerf: ExercisePerformance, baseWeight: Double) -> Double {
        let primaryMuscle = exercisePerf.musclesTargeted.first ?? .chest
        let equipment = exercisePerf.equipmentType
        // Keep tolerance aligned with progression increment granularity.
        return MetricsCalculator.weightIncrement(for: baseWeight, primaryMuscle: primaryMuscle, equipmentType: equipment)
    }

    private static func workingAnchorWeight(in exercisePerf: ExercisePerformance, trainingStyle: TrainingStyle?) -> Double? {
        let progressionSets = MetricsCalculator.selectProgressionSets(from: exercisePerf, overrideStyle: trainingStyle)
        let workingSets = progressionSets.filter { $0.complete && $0.type == .working }
        if let anchor = workingSets.map(\.weight).max(), anchor > 0 {
            return anchor
        }

        let fallback = exercisePerf.sortedSets.filter { $0.complete && $0.type == .working }.map(\.weight).max() ?? 0
        return fallback > 0 ? fallback : nil
    }

    // Computes the range that should be considered "new target state" for this change.
    private static func effectiveNewRepRange(change: PrescriptionChange, exercisePerf: ExercisePerformance) -> (floor: Int?, ceiling: Int?) {
        let policy = exercisePerf.repRange ?? RepRangePolicy()

        switch change.changeType {
        case .changeRepRangeMode:
            if let mode = RepRangeMode(rawValue: Int(change.newValue)) {
                switch mode {
                case .range: return (policy.lowerRange, policy.upperRange)
                case .target: return (policy.targetReps, policy.targetReps)
                case .notSet: return (nil, nil)
                }
            }
            return (nil, nil)
        case .increaseRepRangeLower, .decreaseRepRangeLower:
            return (Int(change.newValue), policy.upperRange)
        case .increaseRepRangeUpper, .decreaseRepRangeUpper:
            return (policy.lowerRange, Int(change.newValue))
        case .increaseRepRangeTarget, .decreaseRepRangeTarget:
            let newTarget = Int(change.newValue)
            return (newTarget, newTarget)
        default:
            switch policy.activeMode {
            case .range: return (policy.lowerRange, policy.upperRange)
            case .target: return (policy.targetReps, policy.targetReps)
            case .notSet: return (nil, nil)
            }
        }
    }
}

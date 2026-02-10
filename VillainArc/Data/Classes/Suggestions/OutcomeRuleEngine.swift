import Foundation

/// Deterministic rules used to score a change outcome from actual workout data.
/// `OutcomeResolver` runs this first, then optionally lets AI override during merge.
struct OutcomeRuleEngine {

    /// Routes each change type to the matching rule evaluator.
    static func evaluate(change: PrescriptionChange, exercisePerf: ExercisePerformance) -> OutcomeSignal? {
        let sets = exercisePerf.sortedSets
        let regularSets = sets.filter { $0.type == .working }

        switch change.changeType {
        case .increaseWeight, .decreaseWeight:
            return evaluateWeightChange(change: change, exercisePerf: exercisePerf)
        case .increaseReps, .decreaseReps:
            return evaluateRepsChange(change: change, exercisePerf: exercisePerf)
        case .increaseRest, .decreaseRest:
            return evaluateSetRestChange(change: change, exercisePerf: exercisePerf)
        case .increaseRestTimeSeconds, .decreaseRestTimeSeconds:
            return evaluateExerciseRestChange(change: change, exercisePerf: exercisePerf, completeSets: sets)
        case .increaseRepRangeLower, .decreaseRepRangeLower,
             .increaseRepRangeUpper, .decreaseRepRangeUpper,
             .increaseRepRangeTarget, .decreaseRepRangeTarget,
             .changeRepRangeMode:
            return evaluateRepRangeChange(change: change, regularSets: regularSets, exercisePerf: exercisePerf)
        case .changeSetType:
            return evaluateSetTypeChange(change: change, exercisePerf: exercisePerf)
        case .removeSet:
            return evaluateRemoveSetChange(change: change, exercisePerf: exercisePerf)
        default:
            return nil
        }
    }

    // MARK: - Match Set Performance

    private static func matchSetPerformance(for change: PrescriptionChange, in exercisePerf: ExercisePerformance) -> SetPerformance? {
        let completeSets = exercisePerf.sortedSets.filter { $0.complete }

        // Prefer an explicit prescription link for reliability.
        if let setPrescriptionID = change.targetSetPrescription?.id {
            if let match = completeSets.first(where: { $0.prescription?.id == setPrescriptionID }) {
                return match
            }
        }

        // Fallback to set index if we cannot resolve by prescription id.
        if let setIndex = change.targetSetPrescription?.index {
            return completeSets.first(where: { $0.index == setIndex })
        }
        return nil
    }

    // MARK: - Weight Change

    private static func evaluateWeightChange(change: PrescriptionChange, exercisePerf: ExercisePerformance) -> OutcomeSignal? {
        guard let setPerf = matchSetPerformance(for: change, in: exercisePerf),
              let newWeight = change.newValue,
              let oldWeight = change.previousValue else { return nil }

        // Tolerance comes from equipment/muscle-aware increment sizing.
        let baseWeight = newWeight > 0 ? newWeight : oldWeight
        let weightStep = weightTolerance(for: exercisePerf, baseWeight: baseWeight)
        let actualWeight = setPerf.weight

        // If the athlete never got near the new target, mark as ignored.
        guard abs(actualWeight - newWeight) <= weightStep else {
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

    // MARK: - Reps Change

    private static func evaluateRepsChange(change: PrescriptionChange, exercisePerf: ExercisePerformance) -> OutcomeSignal? {
        guard let setPerf = matchSetPerformance(for: change, in: exercisePerf),
              let newReps = change.newValue.map({ Int($0) }),
              let oldReps = change.previousValue.map({ Int($0) }) else { return nil }

        let actualReps = setPerf.reps

        // Accept either close hit (within 1 rep) or directional progress toward new target.
        let movedToward = abs(actualReps - newReps) < abs(actualReps - oldReps)
        guard abs(actualReps - newReps) <= 1 || movedToward else {
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

    private static func evaluateSetRestChange(change: PrescriptionChange, exercisePerf: ExercisePerformance) -> OutcomeSignal? {
        guard let setPerf = matchSetPerformance(for: change, in: exercisePerf),
              let newRest = change.newValue.map({ Int($0) }),
              let oldRest = change.previousValue.map({ Int($0) }) else { return nil }

        let actualRest = setPerf.restSeconds

        // Rest adherence window: ±15s counts as following target.
        guard abs(actualRest - newRest) <= 15 else {
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

    // MARK: - Exercise-Level Rest Change

    private static func evaluateExerciseRestChange(change: PrescriptionChange, exercisePerf: ExercisePerformance, completeSets: [SetPerformance]) -> OutcomeSignal? {
        guard let newRest = change.newValue.map({ Int($0) }) else { return nil }

        // Exercise-level rest rules use average rest across completed sets.
        let restValues = completeSets.map { $0.restSeconds }
        guard !restValues.isEmpty else { return nil }
        let avgRest = restValues.reduce(0, +) / restValues.count

        // Same exercise-level rest adherence window: ±15s.
        guard abs(avgRest - newRest) <= 15 else {
            return OutcomeSignal(outcome: .ignored, confidence: 0.7, reason: "Average rest (\(avgRest)s) not close to new target (\(newRest)s).")
        }

        // Use average reps from regular sets as the outcome signal for intensity.
        let regularSets = completeSets.filter { $0.type == .working }
        guard let avgReps = regularSets.isEmpty ? nil : regularSets.map(\.reps).reduce(0, +) / regularSets.count else {
            return nil
        }
        return evaluateRepsInRange(
            actualReps: avgReps,
            exercisePerf: exercisePerf,
            context: "exercise rest change to \(newRest)s"
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

    private static func evaluateSetTypeChange(change: PrescriptionChange, exercisePerf: ExercisePerformance) -> OutcomeSignal? {
        guard let setPerf = matchSetPerformance(for: change, in: exercisePerf),
              let newTypeRaw = change.newValue.map({ Int($0) }),
              let newType = ExerciseSetType(rawValue: newTypeRaw) else { return nil }

        // Type changes are binary: exact type match means success, otherwise ignored.
        if setPerf.type == newType {
            return OutcomeSignal(outcome: .good, confidence: 0.95, reason: "Set type matches the new target (\(newType)).")
        }
        return OutcomeSignal(outcome: .ignored, confidence: 0.9, reason: "Actual set type (\(setPerf.type)) doesn't match new target (\(newType)).")
    }

    // MARK: - Remove Set Change

    private static func evaluateRemoveSetChange(change: PrescriptionChange, exercisePerf: ExercisePerformance) -> OutcomeSignal? {
        guard let oldCount = change.previousValue.map({ Int($0) }),
              let newCount = change.newValue.map({ Int($0) }) else { return nil }

        let completedWorkingSets = exercisePerf.sortedSets.filter { $0.type == .working }
        let actualCount = completedWorkingSets.count

        // If user completed the reduced number of sets (or fewer), the volume reduction was appropriate.
        if actualCount <= newCount {
            return OutcomeSignal(outcome: .good, confidence: 0.85, reason: "User completed \(actualCount) working sets, matching or below the suggested \(newCount).")
        }

        // If user completed the original prescribed count, they ignored the suggestion.
        if actualCount >= oldCount {
            return OutcomeSignal(outcome: .ignored, confidence: 0.85, reason: "User completed \(actualCount) working sets, same as the original \(oldCount) — volume reduction not followed.")
        }

        // In between: partial adherence.
        return OutcomeSignal(outcome: .good, confidence: 0.6, reason: "User completed \(actualCount) working sets, between old (\(oldCount)) and suggested (\(newCount)).")
    }

    // MARK: - Rule Helpers

    private static func evaluateRepsInRange(actualReps: Int, exercisePerf: ExercisePerformance, context: String) -> OutcomeSignal? {
        let policy = exercisePerf.repRange

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

    // Computes the range that should be considered "new target state" for this change.
    private static func effectiveNewRepRange(change: PrescriptionChange, exercisePerf: ExercisePerformance) -> (floor: Int?, ceiling: Int?) {
        let policy = exercisePerf.repRange

        switch change.changeType {
        case .changeRepRangeMode:
            if let rawMode = change.newValue.map({ Int($0) }),
               let mode = RepRangeMode(rawValue: rawMode) {
                switch mode {
                case .range: return (policy.lowerRange, policy.upperRange)
                case .target: return (policy.targetReps, policy.targetReps)
                case .notSet: return (nil, nil)
                }
            }
            return (nil, nil)
        case .increaseRepRangeLower, .decreaseRepRangeLower:
            return (change.newValue.map { Int($0) } ?? policy.lowerRange, policy.upperRange)
        case .increaseRepRangeUpper, .decreaseRepRangeUpper:
            return (policy.lowerRange, change.newValue.map { Int($0) } ?? policy.upperRange)
        case .increaseRepRangeTarget, .decreaseRepRangeTarget:
            let newTarget = change.newValue.map { Int($0) } ?? policy.targetReps
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

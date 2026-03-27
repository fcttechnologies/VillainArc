import Foundation

/// Deterministic rules used to score a change outcome from actual workout data.
/// `OutcomeResolver` runs this first, then optionally lets AI override during merge.
struct OutcomeRuleEngine {
    private enum FollowThroughStrength {
        case none
        case partial
        case full
    }

    private enum DifficultyDirection {
        case harder
        case easier
        case neutral
    }

    private struct RecoverySetComparison {
        let actualRestOwnerSet: SetPerformance
        let actualDownstreamSet: SetPerformance
        let triggerDownstreamSet: SetPerformanceSnapshot
    }

    /// Routes each change type to the matching rule evaluator.
    static func evaluate(change: PrescriptionChange, event: SuggestionEvent, exercisePerf: ExercisePerformance, trainingStyle: TrainingStyle?) -> OutcomeSignal? {
        let regularSets = relevantWorkingSets(in: exercisePerf, trainingStyle: trainingStyle)

        switch change.changeType {
        case .increaseWeight, .decreaseWeight: return evaluateWeightChange(change: change, event: event, exercisePerf: exercisePerf, trainingStyle: trainingStyle)
        case .increaseReps, .decreaseReps: return evaluateRepsChange(change: change, event: event, exercisePerf: exercisePerf)
        case .increaseRest, .decreaseRest: return evaluateSetRestChange(change: change, event: event, exercisePerf: exercisePerf)
        case .increaseRepRangeLower, .decreaseRepRangeLower, .increaseRepRangeUpper, .decreaseRepRangeUpper, .increaseRepRangeTarget, .decreaseRepRangeTarget, .changeRepRangeMode: return evaluateRepRangeChange(change: change, event: event, regularSets: regularSets, exercisePerf: exercisePerf)
        case .changeSetType: return evaluateSetTypeChange(change: change, event: event, exercisePerf: exercisePerf)
        }
    }

    private static func relevantWorkingSets(in exercisePerf: ExercisePerformance, trainingStyle: TrainingStyle?) -> [SetPerformance] {
        let progressionSets = MetricsCalculator.selectProgressionSets(from: exercisePerf, overrideStyle: trainingStyle)
        let workingSets = progressionSets.filter { $0.type == .working }
        return workingSets.isEmpty ? progressionSets : workingSets
    }

    private static func hasStrongComparableContextRangeMiss(in exercisePerf: ExercisePerformance, primarySets: [SetPerformance], floor: Int, ceiling: Int, buffer: Int) -> Bool {
        guard !primarySets.isEmpty else { return false }

        let contextualSets = exercisePerf.sortedSets.filter { set in set.complete && set.type == .working && !MetricsCalculator.isPlanAnchored(set) }
        guard !contextualSets.isEmpty else { return false }

        let maxPrimaryWeight = primarySets.map(\.weight).max() ?? 0
        guard maxPrimaryWeight > 0 else { return false }

        let comparableWeightFloor = maxPrimaryWeight * 0.9
        return contextualSets.contains { set in
            guard set.weight >= comparableWeightFloor else { return false }
            return set.reps <= floor - 2 || set.reps >= ceiling + buffer + 2
        }
    }

    // MARK: - Match Set Performance

    private static func matchSetPerformance(for event: SuggestionEvent, in exercisePerf: ExercisePerformance) -> SetPerformance? {
        let completeSets = exercisePerf.sortedSets.filter { $0.complete }

        if let setPrescriptionID = event.targetSetPrescription?.id, let matched = completeSets.first(where: { $0.prescription?.id == setPrescriptionID }) { return matched }

        return nil
    }

    // MARK: - Weight Change

    private static func evaluateWeightChange(change: PrescriptionChange, event: SuggestionEvent, exercisePerf: ExercisePerformance, trainingStyle: TrainingStyle?) -> OutcomeSignal? {
        guard event.isSetScoped, let setPerf = matchSetPerformance(for: event, in: exercisePerf) else { return nil }

        if event.category == .warmupCalibration { return evaluateWarmupWeightChange(change: change, setPerf: setPerf, exercisePerf: exercisePerf, trainingStyle: trainingStyle, weightStepUsed: event.weightStepUsed) }

        let newWeight = change.newValue
        let oldWeight = change.previousValue

        // Tolerance comes from equipment/muscle-aware increment sizing.
        let baseWeight = newWeight > 0 ? newWeight : oldWeight
        let weightStep = weightTolerance(for: exercisePerf, baseWeight: baseWeight, weightStepUsed: event.weightStepUsed)
        let actualWeight = setPerf.weight
        let actualDifficultyWeight = difficultyRelativeWeight(actualWeight, equipmentType: exercisePerf.equipmentType)
        let oldDifficultyWeight = difficultyRelativeWeight(oldWeight, equipmentType: exercisePerf.equipmentType)
        let newDifficultyWeight = difficultyRelativeWeight(newWeight, equipmentType: exercisePerf.equipmentType)
        let loadLabel =
            if exercisePerf.equipmentType.usesAssistanceWeightSemantics {
                "assistance"
            } else if exercisePerf.equipmentType.usesPerSideLoadSemantics {
                "weight per side"
            } else {
                "weight"
            }

        // A large directional overshoot means the athlete had to move substantially past the
        // prescribed adjustment. Upward overshoot means the increase was too small; downward
        // overshoot means the decrease was still not enough.
        if newDifficultyWeight > oldDifficultyWeight && actualDifficultyWeight >= newDifficultyWeight + weightStep * 2 {
            return OutcomeSignal(outcome: .tooEasy, confidence: 0.8, reason: "Actual \(loadLabel) (\(actualWeight)) substantially exceeded the new target (\(newWeight)) — the suggested harder change was too conservative.")
        }
        if newDifficultyWeight < oldDifficultyWeight && actualDifficultyWeight <= newDifficultyWeight - weightStep * 2 {
            return OutcomeSignal(outcome: .insufficient, confidence: 0.8, reason: "Actual \(loadLabel) (\(actualWeight)) fell well below the new target (\(newWeight)) — the suggested easier change was not enough.")
        }

        let followThrough = followThroughStrength(actual: actualDifficultyWeight, old: oldDifficultyWeight, new: newDifficultyWeight, tolerance: weightStep)

        guard followThrough != .none else {
            if abs(actualDifficultyWeight - oldDifficultyWeight) <= weightStep { return OutcomeSignal(outcome: .ignored, confidence: 0.9, reason: "Actual \(loadLabel) (\(actualWeight)) stayed near old target (\(oldWeight)), new target (\(newWeight)) not attempted.") }
            return OutcomeSignal(outcome: .ignored, confidence: 0.7, reason: "Actual \(loadLabel) (\(actualWeight)) not close to new target (\(newWeight)).")
        }

        let context = followThrough == .full ? "\(loadLabel) change to \(newWeight)" : "partial \(loadLabel) change toward \(newWeight)"
        let baseSignal = evaluateRepsInRange(actualReps: setPerf.reps, frozenRepRange: event.triggerTargetSnapshot?.repRange ?? .empty, context: context)
        let adjustedSignal = adjustSignalForFollowThrough(baseSignal, strength: followThrough, actual: actualWeight, old: oldWeight, new: newWeight, metricName: loadLabel)

        if difficultyDirection(forWeightChangeFrom: oldWeight, to: newWeight, equipmentType: exercisePerf.equipmentType) == .easier {
            return evaluateSupportiveSetOutcome(
                adjustedSignal: adjustedSignal, triggerSet: triggerSetPerformance(for: event), frozenRepRange: event.triggerTargetSnapshot?.repRange ?? .empty, actualReps: setPerf.reps, context: exercisePerf.equipmentType.usesAssistanceWeightSemantics ? "Assistance increase" : "Load reduction")
        }

        return adjustedSignal
    }

    private static func evaluateWarmupWeightChange(change: PrescriptionChange, setPerf: SetPerformance, exercisePerf: ExercisePerformance, trainingStyle: TrainingStyle?, weightStepUsed: Double?) -> OutcomeSignal? {
        let newWeight = change.newValue
        let oldWeight = change.previousValue
        let baseWeight = newWeight > 0 ? newWeight : oldWeight
        let weightStep = weightTolerance(for: exercisePerf, baseWeight: baseWeight, weightStepUsed: weightStepUsed)
        let actualWeight = setPerf.weight

        let followThrough = followThroughStrength(actual: actualWeight, old: oldWeight, new: newWeight, tolerance: weightStep)
        guard followThrough != .none else {
            if abs(actualWeight - oldWeight) <= weightStep { return OutcomeSignal(outcome: .ignored, confidence: 0.9, reason: "Warmup load stayed near the old target (\(oldWeight)).") }
            return OutcomeSignal(outcome: .ignored, confidence: 0.7, reason: "Warmup load (\(actualWeight)) did not move toward the new target (\(newWeight)).")
        }

        guard setPerf.type == .warmup else { return OutcomeSignal(outcome: .tooAggressive, confidence: 0.85, reason: "The adjusted set no longer behaved like a warmup.") }

        if let anchorWeight = workingAnchorWeight(in: exercisePerf, trainingStyle: trainingStyle), anchorWeight > 0, actualWeight >= anchorWeight * 0.9 { return OutcomeSignal(outcome: .tooAggressive, confidence: 0.85, reason: "Warmup load (\(actualWeight)) was too close to the main working load (\(anchorWeight)).") }

        let signal = OutcomeSignal(outcome: .good, confidence: 0.9, reason: "Warmup load moved toward the new target while still behaving like a warmup.")
        return adjustSignalForFollowThrough(signal, strength: followThrough, actual: actualWeight, old: oldWeight, new: newWeight, metricName: "warmup weight")
    }

    // MARK: - Reps Change

    private static func evaluateRepsChange(change: PrescriptionChange, event: SuggestionEvent, exercisePerf: ExercisePerformance) -> OutcomeSignal? {
        guard event.isSetScoped, let setPerf = matchSetPerformance(for: event, in: exercisePerf) else { return nil }

        let newReps = Int(change.newValue)
        let oldReps = Int(change.previousValue)

        let actualReps = setPerf.reps

        // A large directional overshoot means the athlete had to move substantially past the
        // prescribed adjustment. Upward overshoot means the increase was too small; downward
        // overshoot means the decrease was still not enough.
        if newReps > oldReps && actualReps >= newReps + 2 { return OutcomeSignal(outcome: .tooEasy, confidence: 0.8, reason: "Actual reps (\(actualReps)) substantially exceeded the new target (\(newReps)) — the suggested increase was too conservative.") }
        if newReps < oldReps && actualReps <= newReps - 2 { return OutcomeSignal(outcome: .insufficient, confidence: 0.8, reason: "Actual reps (\(actualReps)) fell well below the new target (\(newReps)) — the suggested decrease was not enough.") }

        let followThrough = followThroughStrength(actual: Double(actualReps), old: Double(oldReps), new: Double(newReps), tolerance: 1)
        guard followThrough != .none else {
            if abs(actualReps - oldReps) <= 1 { return OutcomeSignal(outcome: .ignored, confidence: 0.9, reason: "Actual reps (\(actualReps)) stayed at old target (\(oldReps)).") }
            return OutcomeSignal(outcome: .ignored, confidence: 0.7, reason: "Actual reps (\(actualReps)) not close to new target (\(newReps)).")
        }

        let context = followThrough == .full ? "reps change to \(newReps)" : "partial reps change toward \(newReps)"
        let baseSignal = evaluateRepsInRange(actualReps: actualReps, frozenRepRange: event.triggerTargetSnapshot?.repRange ?? .empty, context: context)
        let adjustedSignal = adjustSignalForFollowThrough(baseSignal, strength: followThrough, actual: Double(actualReps), old: Double(oldReps), new: Double(newReps), metricName: "reps")

        if difficultyDirection(for: change) == .easier { return evaluateSupportiveSetOutcome(adjustedSignal: adjustedSignal, triggerSet: triggerSetPerformance(for: event), frozenRepRange: event.triggerTargetSnapshot?.repRange ?? .empty, actualReps: actualReps, context: "Rep reduction") }

        return adjustedSignal
    }

    // MARK: - Set-Level Rest Change

    private static func evaluateSetRestChange(change: PrescriptionChange, event: SuggestionEvent, exercisePerf: ExercisePerformance) -> OutcomeSignal? {
        guard event.isSetScoped, let comparison = recoverySetComparison(for: event, in: exercisePerf) else { return nil }

        let newRest = Int(change.newValue)
        let oldRest = Int(change.previousValue)
        let restTolerance = 15

        let actualRest = comparison.actualRestOwnerSet.effectiveRestSeconds

        // Mirror the directional-overshoot handling used by weight/reps so a much larger
        // rest adjustment does not get credited as a clean test of the suggested target.
        if newRest > oldRest && actualRest >= newRest + restTolerance * 2 { return OutcomeSignal(outcome: .insufficient, confidence: 0.8, reason: "Actual rest (\(actualRest)s) substantially exceeded the new target (\(newRest)s) — the suggested increase was not enough.") }
        if newRest < oldRest && actualRest <= newRest - restTolerance * 2 { return OutcomeSignal(outcome: .tooEasy, confidence: 0.8, reason: "Actual rest (\(actualRest)s) was substantially shorter than the new target (\(newRest)s) — the suggested decrease was too conservative.") }

        let followThrough = followThroughStrength(actual: Double(actualRest), old: Double(oldRest), new: Double(newRest), tolerance: Double(restTolerance))

        guard followThrough != .none else {
            if abs(actualRest - oldRest) <= restTolerance { return OutcomeSignal(outcome: .ignored, confidence: 0.9, reason: "Actual rest (\(actualRest)s) stayed near old target (\(oldRest)s).") }
            return OutcomeSignal(outcome: .ignored, confidence: 0.7, reason: "Actual rest (\(actualRest)s) not close to new target (\(newRest)s).")
        }

        let currentSignal = evaluateRepsInRange(actualReps: comparison.actualDownstreamSet.reps, frozenRepRange: event.triggerTargetSnapshot?.repRange ?? .empty, context: "recovery after rest change to \(newRest)s on the following set")
        let triggerSignal = evaluateRepsInRange(actualReps: comparison.triggerDownstreamSet.reps, frozenRepRange: event.triggerTargetSnapshot?.repRange ?? .empty, context: "trigger performance on the following set")

        let weightTolerance = OutcomeRuleEngine.weightTolerance(for: exercisePerf, baseWeight: max(comparison.actualDownstreamSet.weight, comparison.triggerDownstreamSet.weight), weightStepUsed: nil)

        let improvement = downstreamPerformanceImproved(actual: comparison.actualDownstreamSet, trigger: comparison.triggerDownstreamSet, weightTolerance: weightTolerance)
        let maintained = downstreamPerformanceMaintained(actual: comparison.actualDownstreamSet, trigger: comparison.triggerDownstreamSet, weightTolerance: weightTolerance)
        let followAdjustedSignal = adjustSignalForFollowThrough(currentSignal, strength: followThrough, actual: Double(actualRest), old: Double(oldRest), new: Double(newRest), metricName: "rest")

        if newRest > oldRest { return evaluateIncreaseRestOutcome(adjustedSignal: followAdjustedSignal, triggerSignal: triggerSignal, improvement: improvement, actualDownstreamSet: comparison.actualDownstreamSet, triggerDownstreamSet: comparison.triggerDownstreamSet) }

        return evaluateDecreaseRestOutcome(adjustedSignal: followAdjustedSignal, triggerSignal: triggerSignal, maintained: maintained, actualDownstreamSet: comparison.actualDownstreamSet, triggerDownstreamSet: comparison.triggerDownstreamSet)
    }

    // MARK: - Rep Range Change

    private static func evaluateRepRangeChange(change: PrescriptionChange, event: SuggestionEvent, regularSets: [SetPerformance], exercisePerf: ExercisePerformance) -> OutcomeSignal? {
        guard !regularSets.isEmpty else { return nil }

        // Evaluate against the post-change range/mode. Use the rep range frozen at
        // suggestion-creation time so that a later range change on the live prescription
        // doesn't shift the evaluation window retroactively.
        let newRange = effectiveNewRepRange(change: change, frozenRepRange: event.triggerTargetSnapshot?.repRange ?? .empty)
        guard let floor = newRange.floor, let ceiling = newRange.ceiling else { return nil }

        let reps = regularSets.map { $0.reps }
        let buffer = tooEasyBuffer(floor: floor, ceiling: ceiling)
        let inRange = reps.filter { $0 >= floor && $0 <= ceiling }
        let ratio = Double(inRange.count) / Double(reps.count)
        let belowFloor = reps.filter { $0 < floor }
        let aboveCeiling = reps.filter { $0 > ceiling + buffer }
        let difficulty = difficultyDirection(for: change)

        // If at least half the sets miss in one direction, classify directional mismatch.
        // Use count * 2 >= reps.count to get true >=50% without integer-division truncation
        // (e.g. reps.count/2 = 1 for 3 sets, which would fire on just 1 miss).
        if !belowFloor.isEmpty && belowFloor.count * 2 >= reps.count {
            let outcome: Outcome = difficulty == .easier ? .insufficient : .tooAggressive
            let reason: String
            if difficulty == .easier {
                reason = "Multiple sets (\(belowFloor)) still fell below the easier range floor (\(floor))."
            } else {
                reason = "Multiple sets (\(belowFloor)) fell below the new range floor (\(floor))."
            }
            return OutcomeSignal(outcome: outcome, confidence: 0.8, reason: reason)
        }
        if !aboveCeiling.isEmpty && aboveCeiling.count * 2 >= reps.count { return OutcomeSignal(outcome: .tooEasy, confidence: 0.8, reason: "Multiple sets (\(aboveCeiling)) exceeded the new range ceiling (\(ceiling)) + buffer (\(buffer)).") }

        // Require at least 50% in range, or that all sets are near boundaries (within 2 reps).
        guard ratio >= 0.5 || reps.allSatisfy({ abs($0 - floor) <= 2 || abs($0 - ceiling) <= 2 }) else { return OutcomeSignal(outcome: .ignored, confidence: 0.7, reason: "Most sets (\(reps)) didn't fall in new range (\(floor)-\(ceiling)).") }

        if ratio >= 0.5 {
            if hasStrongComparableContextRangeMiss(in: exercisePerf, primarySets: regularSets, floor: floor, ceiling: ceiling, buffer: buffer) {
                return OutcomeSignal(outcome: .ignored, confidence: 0.65, reason: "Linked prescribed sets matched the new range, but a comparable unlinked working set diverged strongly enough that the exercise-level result remains ambiguous.")
            }
            return OutcomeSignal(outcome: .good, confidence: 0.85, reason: "\(Int(ratio * 100))% of sets fell within the new range (\(floor)-\(ceiling)).")
        }

        return nil
    }

    // MARK: - Set Type Change

    private static func evaluateSetTypeChange(change: PrescriptionChange, event: SuggestionEvent, exercisePerf: ExercisePerformance) -> OutcomeSignal? {
        guard let setPerf = matchSetPerformance(for: event, in: exercisePerf), let newType = ExerciseSetType(rawValue: Int(change.newValue)) else { return nil }

        // Type changes are binary: exact type match means success, otherwise ignored.
        if setPerf.type == newType { return OutcomeSignal(outcome: .good, confidence: 0.95, reason: "Set type matches the new target (\(newType)).") }
        return OutcomeSignal(outcome: .ignored, confidence: 0.9, reason: "Actual set type (\(setPerf.type)) doesn't match new target (\(newType)).")
    }

    private static func followThroughStrength(actual: Double, old: Double, new: Double, tolerance: Double) -> FollowThroughStrength {
        guard tolerance >= 0 else { return .none }
        guard new != old else { return .full }
        if abs(actual - new) <= tolerance { return .full }

        if new > old {
            if actual > new { return .full }
            if abs(actual - old) <= tolerance || actual <= old { return .none }
            return .partial
        }

        if actual < new { return .full }
        if abs(actual - old) <= tolerance || actual >= old { return .none }
        return .partial
    }

    private static func adjustSignalForFollowThrough(_ signal: OutcomeSignal?, strength: FollowThroughStrength, actual: Double, old: Double, new: Double, metricName: String) -> OutcomeSignal? {
        guard let signal else { return nil }
        guard strength == .partial else { return signal }

        return OutcomeSignal(outcome: signal.outcome, confidence: min(signal.confidence, 0.65), reason: "Actual \(metricName) (\(actual)) moved toward new target (\(new)) from old target (\(old)) but did not fully reach it. \(signal.reason)")
    }

    private static func difficultyDirection(for change: PrescriptionChange) -> DifficultyDirection {
        switch change.changeType {
        case .increaseWeight, .increaseReps, .decreaseRest, .increaseRepRangeLower, .decreaseRepRangeUpper, .increaseRepRangeTarget: return .harder
        case .decreaseWeight, .decreaseReps, .increaseRest, .decreaseRepRangeLower, .increaseRepRangeUpper, .decreaseRepRangeTarget: return .easier
        case .changeSetType, .changeRepRangeMode: return .neutral
        }
    }

    private static func difficultyDirection(forWeightChangeFrom oldWeight: Double, to newWeight: Double, equipmentType: EquipmentType) -> DifficultyDirection {
        let oldDifficultyWeight = difficultyRelativeWeight(oldWeight, equipmentType: equipmentType)
        let newDifficultyWeight = difficultyRelativeWeight(newWeight, equipmentType: equipmentType)

        if newDifficultyWeight > oldDifficultyWeight { return .harder }
        if newDifficultyWeight < oldDifficultyWeight { return .easier }
        return .neutral
    }

    private static func difficultyRelativeWeight(_ weight: Double, equipmentType: EquipmentType) -> Double { equipmentType.usesAssistanceWeightSemantics ? -weight : weight }

    private static func minimumSuccessfulReps(for frozenRepRange: RepRangeSnapshot) -> Int? {
        switch frozenRepRange.mode {
        case .range: return frozenRepRange.lower
        case .target: return max(1, frozenRepRange.target - 1)
        case .notSet: return nil
        }
    }

    private static func triggerSetPerformance(for event: SuggestionEvent) -> SetPerformanceSnapshot? {
        guard let triggerPerf = event.triggerPerformance else { return nil }
        let triggerSets = ExercisePerformanceSnapshot(performance: triggerPerf).sets.sorted { $0.index < $1.index }

        if let triggerTargetSetID = event.triggerTargetSetID, let triggerSet = triggerSets.first(where: { $0.originalTargetSetID == triggerTargetSetID }) { return triggerSet }

        if let triggerIndex = event.triggerTargetSetIndex { return triggerSets.first { $0.index == triggerIndex } }

        return nil
    }

    private static func evaluateSupportiveSetOutcome(adjustedSignal: OutcomeSignal?, triggerSet: SetPerformanceSnapshot?, frozenRepRange: RepRangeSnapshot, actualReps: Int, context: String) -> OutcomeSignal? {
        guard let adjustedSignal else { return nil }

        switch adjustedSignal.outcome {
        case .tooAggressive:
            if let triggerSet { return OutcomeSignal(outcome: .insufficient, confidence: adjustedSignal.confidence, reason: "\(context) was followed, but performance still sat below the desired zone (\(actualReps) reps now vs \(triggerSet.reps) at trigger).") }
            return OutcomeSignal(outcome: .insufficient, confidence: adjustedSignal.confidence, reason: "\(context) was followed, but performance still sat below the desired zone.")
        case .good, .tooEasy:
            guard let triggerSet, let minimumSuccessfulReps = minimumSuccessfulReps(for: frozenRepRange), triggerSet.reps <= minimumSuccessfulReps, actualReps <= triggerSet.reps else { return adjustedSignal }

            return OutcomeSignal(outcome: .insufficient, confidence: min(adjustedSignal.confidence, 0.7), reason: "\(context) was followed, but reps did not improve enough versus trigger performance (\(actualReps) reps now vs \(triggerSet.reps) at trigger).")
        case .insufficient, .ignored, .pending: return adjustedSignal
        }
    }

    private static func recoverySetComparison(for event: SuggestionEvent, in exercisePerf: ExercisePerformance) -> RecoverySetComparison? {
        guard let restOwnerSet = matchSetPerformance(for: event, in: exercisePerf), let actualDownstreamSet = nextCompletedWorkingSet(after: restOwnerSet, in: exercisePerf), let triggerDownstreamSet = nextTriggerWorkingSet(for: event) else { return nil }

        return RecoverySetComparison(actualRestOwnerSet: restOwnerSet, actualDownstreamSet: actualDownstreamSet, triggerDownstreamSet: triggerDownstreamSet)
    }

    private static func nextCompletedWorkingSet(after set: SetPerformance, in exercisePerf: ExercisePerformance) -> SetPerformance? { exercisePerf.sortedSets.first { candidate in candidate.complete && candidate.type == .working && candidate.index > set.index } }

    private static func nextTriggerWorkingSet(for event: SuggestionEvent) -> SetPerformanceSnapshot? {
        guard let triggerPerf = event.triggerPerformance else { return nil }
        let triggerSets = ExercisePerformanceSnapshot(performance: triggerPerf).sets.sorted { $0.index < $1.index }

        if let triggerTargetSetID = event.triggerTargetSetID, let triggerSet = triggerSets.first(where: { $0.originalTargetSetID == triggerTargetSetID }) { return triggerSets.first { $0.type == .working && $0.index > triggerSet.index } }

        if let triggerIndex = event.triggerTargetSetIndex { return triggerSets.first { $0.type == .working && $0.index > triggerIndex } }

        return nil
    }

    private static func downstreamPerformanceImproved(actual: SetPerformance, trigger: SetPerformanceSnapshot, weightTolerance: Double) -> Bool {
        if actual.reps > trigger.reps { return true }

        if actual.weight >= trigger.weight + max(0.5, weightTolerance), actual.reps >= trigger.reps { return true }

        if let actualEstimated1RM = actual.estimated1RM, let triggerEstimated1RM = estimated1RM(weight: trigger.weight, reps: trigger.reps), actualEstimated1RM > triggerEstimated1RM { return true }

        return false
    }

    private static func downstreamPerformanceMaintained(actual: SetPerformance, trigger: SetPerformanceSnapshot, weightTolerance: Double) -> Bool {
        if actual.reps > trigger.reps { return true }

        let similarWeight = abs(actual.weight - trigger.weight) <= weightTolerance
        if similarWeight && actual.reps >= trigger.reps { return true }

        if actual.weight > trigger.weight + max(0.5, weightTolerance), actual.reps >= max(1, trigger.reps - 1) { return true }

        return false
    }

    private static func evaluateIncreaseRestOutcome(adjustedSignal: OutcomeSignal?, triggerSignal: OutcomeSignal?, improvement: Bool, actualDownstreamSet: SetPerformance, triggerDownstreamSet: SetPerformanceSnapshot) -> OutcomeSignal? {
        guard let adjustedSignal else { return nil }

        switch adjustedSignal.outcome {
        case .tooAggressive: return OutcomeSignal(outcome: .insufficient, confidence: adjustedSignal.confidence, reason: "Rest change was followed, but the following set still fell below the desired zone (\(actualDownstreamSet.reps) reps vs \(triggerDownstreamSet.reps) at trigger).")
        case .good, .tooEasy:
            if improvement || triggerSignal?.outcome == .tooAggressive { return adjustedSignal }
            return OutcomeSignal(outcome: .insufficient, confidence: min(adjustedSignal.confidence, 0.7), reason: "Rest change was followed, but the following set did not improve enough versus trigger performance (\(actualDownstreamSet.reps) reps now vs \(triggerDownstreamSet.reps) at trigger).")
        case .insufficient, .ignored, .pending: return adjustedSignal
        }
    }

    private static func evaluateDecreaseRestOutcome(adjustedSignal: OutcomeSignal?, triggerSignal: OutcomeSignal?, maintained: Bool, actualDownstreamSet: SetPerformance, triggerDownstreamSet: SetPerformanceSnapshot) -> OutcomeSignal? {
        guard let adjustedSignal else { return nil }

        switch adjustedSignal.outcome {
        case .tooAggressive: return adjustedSignal
        case .good, .tooEasy:
            if maintained { return adjustedSignal }
            return OutcomeSignal(outcome: .tooAggressive, confidence: min(adjustedSignal.confidence, 0.7), reason: "Reduced rest was followed, but the following set regressed versus trigger performance (\(actualDownstreamSet.reps) reps now vs \(triggerDownstreamSet.reps) at trigger).")
        case .insufficient: return triggerSignal?.outcome == .tooAggressive ? adjustedSignal : OutcomeSignal(outcome: .tooAggressive, confidence: min(adjustedSignal.confidence, 0.7), reason: adjustedSignal.reason)
        case .ignored, .pending: return adjustedSignal
        }
    }

    private static func estimated1RM(weight: Double, reps: Int) -> Double? {
        guard weight > 0, reps > 0 else { return nil }
        return weight * (1 + (Double(reps) / 30))
    }

    // MARK: - Rule Helpers

    // Shared intensity classifier used by weight, reps, and rest change evaluators.
    // Accepts the rep range frozen at suggestion-creation time (from triggerTargetSnapshot)
    // rather than reading the live prescription, so that any range changes accepted between
    // suggestion creation and outcome evaluation don't corrupt the result.
    private static func evaluateRepsInRange(actualReps: Int, frozenRepRange: RepRangeSnapshot, context: String) -> OutcomeSignal? {
        switch frozenRepRange.mode {
        case .range:
            let floor = frozenRepRange.lower
            let ceiling = frozenRepRange.upper
            let buffer = tooEasyBuffer(floor: floor, ceiling: ceiling)

            if actualReps < floor { return OutcomeSignal(outcome: .tooAggressive, confidence: 0.85, reason: "Reps (\(actualReps)) below range floor (\(floor)) after \(context).") }
            if actualReps > ceiling + buffer { return OutcomeSignal(outcome: .tooEasy, confidence: 0.85, reason: "Reps (\(actualReps)) above range ceiling (\(ceiling)) + buffer (\(buffer)) after \(context).") }
            return OutcomeSignal(outcome: .good, confidence: 0.9, reason: "Reps (\(actualReps)) within range (\(floor)-\(ceiling)) after \(context).")

        case .target:
            let target = frozenRepRange.target
            let buffer = tooEasyBuffer(floor: target, ceiling: target)
            let minimumSuccessfulReps = max(1, target - 1)

            if actualReps < minimumSuccessfulReps { return OutcomeSignal(outcome: .tooAggressive, confidence: 0.85, reason: "Reps (\(actualReps)) below the acceptable target zone (\(minimumSuccessfulReps)-\(target)) after \(context).") }
            if actualReps > target + buffer { return OutcomeSignal(outcome: .tooEasy, confidence: 0.85, reason: "Reps (\(actualReps)) above target (\(target)) + buffer (\(buffer)) after \(context).") }
            return OutcomeSignal(outcome: .good, confidence: 0.9, reason: "Reps (\(actualReps)) within the acceptable target zone (\(minimumSuccessfulReps)-\(target)) after \(context).")

        case .notSet: return nil
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

    private static func weightTolerance(for exercisePerf: ExercisePerformance, baseWeight: Double, weightStepUsed: Double?) -> Double {
        if let weightStepUsed, weightStepUsed > 0 { return weightStepUsed }
        let primaryMuscle = exercisePerf.musclesTargeted.first ?? .chest
        let equipment = exercisePerf.equipmentType
        // Keep tolerance aligned with progression increment granularity.
        return MetricsCalculator.weightIncrement(for: baseWeight, primaryMuscle: primaryMuscle, equipmentType: equipment, catalogID: exercisePerf.catalogID)
    }

    private static func workingAnchorWeight(in exercisePerf: ExercisePerformance, trainingStyle: TrainingStyle?) -> Double? {
        let progressionSets = MetricsCalculator.selectProgressionSets(from: exercisePerf, overrideStyle: trainingStyle)
        let workingSets = progressionSets.filter { $0.complete && $0.type == .working }
        if let anchor = workingSets.map(\.weight).max(), anchor > 0 { return anchor }

        let fallback = exercisePerf.sortedSets.filter { $0.complete && $0.type == .working }.map(\.weight).max() ?? 0
        return fallback > 0 ? fallback : nil
    }

    // Computes the range that should be considered "new target state" for this change.
    // Uses the rep range frozen at suggestion-creation time for the unchanged half of the
    // range (e.g., ceiling when only the floor was changed), so that a later modification
    // to the live prescription doesn't shift the evaluation window retroactively.
    private static func effectiveNewRepRange(change: PrescriptionChange, frozenRepRange: RepRangeSnapshot) -> (floor: Int?, ceiling: Int?) {
        switch change.changeType {
        case .changeRepRangeMode:
            if let mode = RepRangeMode(rawValue: Int(change.newValue)) {
                switch mode {
                case .range: return (frozenRepRange.lower, frozenRepRange.upper)
                case .target: return (frozenRepRange.target, frozenRepRange.target)
                case .notSet: return (nil, nil)
                }
            }
            return (nil, nil)
        case .increaseRepRangeLower, .decreaseRepRangeLower: return (Int(change.newValue), frozenRepRange.upper)
        case .increaseRepRangeUpper, .decreaseRepRangeUpper: return (frozenRepRange.lower, Int(change.newValue))
        case .increaseRepRangeTarget, .decreaseRepRangeTarget:
            let newTarget = Int(change.newValue)
            return (newTarget, newTarget)
        default:
            switch frozenRepRange.mode {
            case .range: return (frozenRepRange.lower, frozenRepRange.upper)
            case .target: return (frozenRepRange.target, frozenRepRange.target)
            case .notSet: return (nil, nil)
            }
        }
    }
}

import Foundation

struct ExerciseSuggestionContext {
    let session: WorkoutSession
    let performance: ExercisePerformance
    let prescription: ExercisePrescription
    let history: [ExercisePerformance]
    let plan: WorkoutPlan
    let resolvedTrainingStyle: TrainingStyle
}

struct RuleEngine {
    static func evaluate(context: ExerciseSuggestionContext) -> [PrescriptionChange] {
        // Rule order is intentional:
        // 1) Progression rules (increase weight when performance warrants it).
        // 2) Safety/cleanup (reduce weight, fix prescriptions to match behavior).
        // 3) Optimization (rest/stagnation, set type hygiene).
        var suggestions: [PrescriptionChange] = []

        // Progression rules (ordered from strongest evidence to more general).
        suggestions.append(contentsOf: largeOvershootProgression(context))
        suggestions.append(contentsOf: doubleProgressionRange(context))
        suggestions.append(contentsOf: doubleProgressionTarget(context))
        suggestions.append(contentsOf: steadyRepIncreaseWithinRange(context))

        // Safety / cleanup rules.
        suggestions.append(contentsOf: belowRangeWeightDecrease(context))
        suggestions.append(contentsOf: reducedWeightToHitReps(context))
        suggestions.append(contentsOf: matchActualWeight(context))
        suggestions.append(contentsOf: stagnationIncreaseRest(context))
        suggestions.append(contentsOf: volumeRegression(context))

        // Set type hygiene (ensure labels match behavior).
        suggestions.append(contentsOf: shortRestPerformanceDrop(context))
        suggestions.append(contentsOf: dropSetWithoutBase(context))
        suggestions.append(contentsOf: warmupActingLikeWorkingSet(context))
        suggestions.append(contentsOf: regularActingLikeWarmup(context))
        suggestions.append(contentsOf: setTypeMismatch(context))

        return suggestions
    }

    private static func doubleProgressionRange(_ context: ExerciseSuggestionContext) -> [PrescriptionChange] {
        // Range mode progression: hit upper bound for 2 sessions -> increase weight, reset to lower bound.
        let repRange = context.prescription.repRange
        guard repRange.activeMode == .range else { return [] }
        let lower = repRange.lowerRange
        let upper = repRange.upperRange
        let recent = recentPerformances(context)
        guard recent.count >= 2 else { return [] }

        // Require BOTH of the last two sessions to hit the top of the range.
        let lastTwo = Array(recent.prefix(2))
        let hitTopInBoth = lastTwo.allSatisfy { performance in
            let progressionSets = selectProgressionSets(from: performance, context: context)
            guard !progressionSets.isEmpty else { return false }
            return progressionSets.allSatisfy { $0.reps >= upper }
        }

        guard hitTopInBoth else { return [] }

        let progressionSets = selectProgressionSets(from: context.performance, context: context)
        guard !progressionSets.isEmpty else { return [] }

        var changes: [PrescriptionChange] = []
        let repsReason = "Reset reps to \(lower) to account for the added weight."

        let multiplier = styleIncrementMultiplier(context)

        for set in progressionSets {
            guard let setPrescription = targetSet(for: set, prescription: context.prescription) else { continue }
            let currentWeight = setPrescription.targetWeight
            guard currentWeight > 0 else { continue }

            // Increment is based on muscle group, weight size, and training style.
            let baseIncrement = weightIncrement(for: currentWeight, context: context)
            let newWeight = MetricsCalculator.roundToNearestPlate(currentWeight + baseIncrement * multiplier)
            let shouldResetReps = setPrescription.targetReps != lower
            let weightReason = shouldResetReps
                ? "You hit the top of your rep range (\(upper)) in your last two sessions. Increase weight to keep progressing."
                : "You hit the top of your rep range (\(upper)) in your last two sessions. Increase weight and keep reps at \(lower)."

            changes.append(makeSetChange(context: context, set: set, setPrescription: setPrescription, changeType: .increaseWeight, previousValue: currentWeight, newValue: newWeight, reasoning: weightReason))

            if shouldResetReps {
                changes.append(makeSetChange(context: context, set: set, setPrescription: setPrescription, changeType: .decreaseReps, previousValue: Double(setPrescription.targetReps), newValue: Double(lower), reasoning: repsReason))
            }
        }

        return changes
    }

    private static func doubleProgressionTarget(_ context: ExerciseSuggestionContext) -> [PrescriptionChange] {
        // Target mode progression: exceed target by 1+ for 2 sessions -> increase weight.
        let repRange = context.prescription.repRange
        guard repRange.activeMode == .target else { return [] }
        let target = repRange.targetReps
        let recent = recentPerformances(context)
        guard recent.count >= 2 else { return [] }

        // Require BOTH of the last two sessions to exceed target by at least 1.
        let lastTwo = Array(recent.prefix(2))
        let exceededTargetInBoth = lastTwo.allSatisfy { performance in
            let progressionSets = selectProgressionSets(from: performance, context: context)
            guard !progressionSets.isEmpty else { return false }
            return progressionSets.allSatisfy { $0.reps >= target + 1 }
        }

        guard exceededTargetInBoth else { return [] }

        let progressionSets = selectProgressionSets(from: context.performance, context: context)
        guard !progressionSets.isEmpty else { return [] }

        var changes: [PrescriptionChange] = []
        let reason = "You exceeded your rep target (\(target)) in your last two sessions. Increase weight to keep progressing."
        let multiplier = styleIncrementMultiplier(context)

        for set in progressionSets {
            guard let setPrescription = targetSet(for: set, prescription: context.prescription) else { continue }
            let currentWeight = setPrescription.targetWeight
            guard currentWeight > 0 else { continue }

            let baseIncrement = weightIncrement(for: currentWeight, context: context)
            let newWeight = MetricsCalculator.roundToNearestPlate(currentWeight + baseIncrement * multiplier)

            changes.append(makeSetChange(context: context, set: set, setPrescription: setPrescription, changeType: .increaseWeight, previousValue: currentWeight, newValue: newWeight, reasoning: reason))
        }

        return changes
    }

    private static func steadyRepIncreaseWithinRange(_ context: ExerciseSuggestionContext) -> [PrescriptionChange] {
        // Range mode progression: repeat the same reps at the same weight for 2 sessions -> increase reps by 1.
        let repRange = context.prescription.repRange
        guard repRange.activeMode == .range else { return [] }
        let lower = repRange.lowerRange
        let upper = repRange.upperRange
        let recent = recentPerformances(context)
        guard recent.count >= 2 else { return [] }

        let progressionSets = selectProgressionSets(from: context.performance, context: context)
        guard !progressionSets.isEmpty else { return [] }

        // Skip reps-increase if weight progression already qualifies.
        let progressionIndices = progressionWeightChangeIndices(context)

        let evidence = Array(recent.prefix(3))
        let weightTolerance = 2.5
        let reason = "You've repeated the same reps at this weight for multiple sessions. Add a rep to keep progressing within your range."

        var changes: [PrescriptionChange] = []

        for set in progressionSets {
            guard let setPrescription = targetSet(for: set, prescription: context.prescription) else { continue }
            guard setPrescription.type == .working else { continue }
            guard !progressionIndices.contains(setPrescription.index) else { continue }
            guard setPrescription.targetReps > 0 else { continue }

            var samples: [(reps: Int, weight: Double)] = []
            var includesCurrent = false

            for performance in evidence {
                guard let perfSet = performance.sortedSets[safe: setPrescription.index],
                      perfSet.complete else { continue }
                guard perfSet.type == .working else { continue }

                if performance.id == context.performance.id {
                    includesCurrent = true
                }

                samples.append((reps: perfSet.reps, weight: perfSet.weight))
            }

            guard includesCurrent, samples.count >= 2 else { continue }

            let lastTwo = Array(samples.prefix(2))
            let reps = lastTwo[0].reps
            let sameReps = lastTwo.allSatisfy { $0.reps == reps }
            let sameWeight = lastTwo.allSatisfy { abs($0.weight - lastTwo[0].weight) <= weightTolerance }
            guard sameReps && sameWeight else { continue }
            guard reps >= lower, reps < upper else { continue }
            guard reps >= setPrescription.targetReps else { continue }

            let newReps = min(upper, reps + 1)
            guard newReps > setPrescription.targetReps else { continue }

            changes.append(makeSetChange(context: context, set: set, setPrescription: setPrescription, changeType: .increaseReps, previousValue: Double(setPrescription.targetReps), newValue: Double(newReps), reasoning: reason))
        }

        return changes
    }

    private static func largeOvershootProgression(_ context: ExerciseSuggestionContext) -> [PrescriptionChange] {
        // Large overshoot: reps exceed top by 4+ (range) or target by 5+ for 2 sessions -> bigger jump.
        let recent = recentPerformances(context)
        guard recent.count >= 2 else { return [] }

        // Check overshoot in BOTH of the last two sessions.
        let lastTwo = Array(recent.prefix(2))
        let repRange = context.prescription.repRange
        guard repRange.activeMode != .notSet else { return [] }

        let overshootMet: Bool
        var lower = 0
        var shouldResetReps = false
        switch repRange.activeMode {
        case .range:
            lower = repRange.lowerRange
            shouldResetReps = true
            let upper = repRange.upperRange
            overshootMet = lastTwo.allSatisfy { performance in
                let progressionSets = selectProgressionSets(from: performance, context: context)
                guard !progressionSets.isEmpty else { return false }
                return progressionSets.allSatisfy { $0.reps >= upper + 4 }
            }
        case .target:
            let target = repRange.targetReps
            overshootMet = lastTwo.allSatisfy { performance in
                let progressionSets = selectProgressionSets(from: performance, context: context)
                guard !progressionSets.isEmpty else { return false }
                return progressionSets.allSatisfy { $0.reps >= target + 5 }
            }
        case .notSet:
            return []
        }

        guard overshootMet else { return [] }

        let progressionSets = selectProgressionSets(from: context.performance, context: context)
        guard !progressionSets.isEmpty else { return [] }

        var changes: [PrescriptionChange] = []
        let weightReason = "You exceeded the top of your rep range in two sessions. Increase weight to better match your current strength."
        let repsReason = "Reset reps to \(lower) to account for the larger weight jump."

        for set in progressionSets {
            guard let setPrescription = targetSet(for: set, prescription: context.prescription) else { continue }
            let currentWeight = setPrescription.targetWeight
            guard currentWeight > 0 else { continue }

            // Larger jump = 1.5x the usual increment.
            let baseIncrement = weightIncrement(for: currentWeight, context: context)
            let jumpWeight = currentWeight + (baseIncrement * 1.5)
            let newWeight = MetricsCalculator.roundToNearestPlate(jumpWeight)

            changes.append(makeSetChange(context: context, set: set, setPrescription: setPrescription, changeType: .increaseWeight, previousValue: currentWeight, newValue: newWeight, reasoning: weightReason))

            if shouldResetReps, setPrescription.targetReps != lower {
                changes.append(makeSetChange(context: context, set: set, setPrescription: setPrescription, changeType: .decreaseReps, previousValue: Double(setPrescription.targetReps), newValue: Double(lower), reasoning: repsReason))
            }
        }

        return changes
    }

    private static func belowRangeWeightDecrease(_ context: ExerciseSuggestionContext) -> [PrescriptionChange] {
        // Range mode safety: below lower bound in 2 of last 3 -> reduce weight.
        let repRange = context.prescription.repRange
        guard repRange.activeMode == .range else { return [] }
        let lower = repRange.lowerRange
        let recent = recentPerformances(context)
        guard recent.count >= 2 else { return [] }

        // Evidence window: last 3 sessions, need 2 sessions below range.
        let lastThree = Array(recent.prefix(3))
        var belowCount = 0

        for performance in lastThree {
            let progressionSets = selectProgressionSets(from: performance, context: context)
            guard !progressionSets.isEmpty else { continue }

            var sessionBelow = true
            for set in progressionSets {
                guard let setPrescription = targetSet(for: set, prescription: context.prescription) else {
                    sessionBelow = false
                    break
                }

                // Only count if they tried the prescribed load.
                let attemptedWeight = abs(set.weight - setPrescription.targetWeight) <= 2.5
                if !(set.reps < lower && attemptedWeight) {
                    sessionBelow = false
                    break
                }
            }

            if sessionBelow {
                belowCount += 1
            }
        }

        guard belowCount >= 2 else { return [] }

        let progressionSets = selectProgressionSets(from: context.performance, context: context)
        guard !progressionSets.isEmpty else { return [] }

        var changes: [PrescriptionChange] = []
        let reason = "You fell below the minimum rep target (\(lower)) in 2 of your last 3 sessions. Reduce weight slightly to stay in range."

        for set in progressionSets {
            guard let setPrescription = targetSet(for: set, prescription: context.prescription) else { continue }
            let currentWeight = setPrescription.targetWeight
            guard currentWeight > 0 else { continue }

            let decrement = weightIncrement(for: currentWeight, context: context)
            let newWeight = MetricsCalculator.roundToNearestPlate(max(0, currentWeight - decrement))

            changes.append(makeSetChange(context: context, set: set, setPrescription: setPrescription, changeType: .decreaseWeight, previousValue: currentWeight, newValue: newWeight, reasoning: reason))
        }

        return changes
    }

    private static func matchActualWeight(_ context: ExerciseSuggestionContext) -> [PrescriptionChange] {
        // Cleanup: user consistently uses a different weight -> update prescription weight.
        let recent = recentPerformances(context)
        guard recent.count >= 3 else { return [] }

        // Avoid fighting progression rules: if a progression weight increase is already warranted, skip cleanup.
        let progressionIndices = progressionWeightChangeIndices(context)

        // Require 3 data points (stability).
        let lastThree = Array(recent.prefix(3))
        var changes: [PrescriptionChange] = []

        for setPrescription in context.prescription.sortedSets {
            guard setPrescription.type == .working else { continue }
            if progressionIndices.contains(setPrescription.index) {
                continue
            }

            var weights: [Double] = []
            for performance in lastThree {
                guard let set = performance.sortedSets[safe: setPrescription.index],
                      set.complete,
                      set.type == .working else {
                    continue
                }
                weights.append(set.weight)
            }

            guard weights.count == 3 else { continue }

            // Require consistent deviation of > 5 lbs in one direction.
            let targetWeight = setPrescription.targetWeight
            let deltas = weights.map { $0 - targetWeight }
            let allAbove = deltas.allSatisfy { $0 > 5 }
            let allBelow = deltas.allSatisfy { $0 < -5 }
            guard allAbove || allBelow else { continue }

            let average = weights.reduce(0, +) / Double(weights.count)
            let newWeight = MetricsCalculator.roundToNearestPlate(average)
            guard abs(newWeight - targetWeight) > 0.1 else { continue }

            let changeType: ChangeType = newWeight > targetWeight ? .increaseWeight : .decreaseWeight
            let reason = "You've used about \(MetricsCalculator.roundToNearestPlate(average)) lbs for three sessions. Update the prescription to match your working weight."

            changes.append(makeSetChange(context: context, set: context.performance.sortedSets[safe: setPrescription.index], setPrescription: setPrescription, changeType: changeType, previousValue: targetWeight, newValue: newWeight, reasoning: reason))
        }

        return changes
    }

    private static func reducedWeightToHitReps(_ context: ExerciseSuggestionContext) -> [PrescriptionChange] {
        // Cleanup: user regularly lowers weight to hit reps -> reduce prescribed load.
        let recent = recentPerformances(context)
        guard recent.count >= 2 else { return [] }

        let lastTwo = Array(recent.prefix(2))
        let repFloor = repFloor(context)

        var changes: [PrescriptionChange] = []

        for setPrescription in context.prescription.sortedSets where setPrescription.type == .working {
            var reducedWeights: [Double] = []
            var hitCount = 0

            for performance in lastTwo {
                guard let set = performance.sortedSets[safe: setPrescription.index], set.complete else { continue }

                let reducedLoad = set.weight < (setPrescription.targetWeight - 2.5)
                let repsLow = repFloor.map { set.reps <= $0 } ?? false

                if reducedLoad && repsLow {
                    hitCount += 1
                    reducedWeights.append(set.weight)
                }
            }

            guard hitCount >= 2, !reducedWeights.isEmpty else { continue }

            let average = reducedWeights.reduce(0, +) / Double(reducedWeights.count)
            let newWeight = MetricsCalculator.roundToNearestPlate(average)
            guard newWeight < setPrescription.targetWeight else { continue }

            let reason = "You've reduced the load to hit your reps in recent sessions. Update the prescription to match your current working weight."

            changes.append(makeSetChange(context: context, set: context.performance.sortedSets[safe: setPrescription.index], setPrescription: setPrescription, changeType: .decreaseWeight, previousValue: setPrescription.targetWeight, newValue: newWeight, reasoning: reason))
        }

        return changes
    }

    private static func shortRestPerformanceDrop(_ context: ExerciseSuggestionContext) -> [PrescriptionChange] {
        // Rest rule: user rests shorter than prescribed and reps drop -> suggest more rest.
        let recent = recentPerformances(context)
        guard recent.count >= 2 else { return [] }

        let lastTwo = Array(recent.prefix(2))
        let repFloor = repFloor(context)

        let restPolicy = context.prescription.restTimePolicy
        let restIncrement = 15

        func triggerSetIndices(in performance: ExercisePerformance) -> [Int] {
            var indices: [Int] = []
            let sets = performance.sortedSets

            for idx in 1..<sets.count {
                let currentSet = sets[idx]
                guard currentSet.complete, currentSet.type == .working else { continue }

                let prevSet = sets[idx - 1]
                let effectiveRest = performance.effectiveRestSeconds(after: prevSet)
                guard effectiveRest > 0 else { continue }

                guard let setPrescription = targetSet(for: currentSet, prescription: context.prescription) else { continue }
                let targetRest = restPolicy.activeMode == .allSame
                    ? restPolicy.allSameSeconds
                    : setPrescription.targetRest

                let actualRest = currentSet.restSeconds
                guard actualRest < targetRest - 15 else { continue }

                let previousRegular = sets[..<idx].last { $0.type == .working && $0.complete }
                let repDrop = previousRegular.map { $0.reps - currentSet.reps } ?? 0
                let belowFloor = repFloor.map { currentSet.reps < $0 } ?? false

                if repDrop >= 2 || belowFloor {
                    indices.append(currentSet.index)
                }
            }

            return indices
        }

        let triggeredLastTwo = lastTwo.map(triggerSetIndices)
        guard triggeredLastTwo.allSatisfy({ !$0.isEmpty }) else { return [] }

        let currentTriggered = Set(triggerSetIndices(in: context.performance))
        guard !currentTriggered.isEmpty else { return [] }

        let reason = "Your rest periods are shorter than prescribed and reps drop across sets. Increasing rest should help you stay in range."

        if restPolicy.activeMode == .allSame {
            let current = restPolicy.allSameSeconds
            let newValue = current + restIncrement
            return [makeExerciseChange(context: context, changeType: .increaseRestTimeSeconds, previousValue: Double(current), newValue: Double(newValue), reasoning: reason)]
        }

        var changes: [PrescriptionChange] = []
        for index in currentTriggered {
            guard let set = context.performance.sortedSets[safe: index],
                  let setPrescription = targetSet(for: set, prescription: context.prescription) else { continue }

            let current = setPrescription.targetRest
            let newValue = current + restIncrement

            changes.append(makeSetChange(context: context, set: set, setPrescription: setPrescription, changeType: .increaseRest, previousValue: Double(current), newValue: Double(newValue), reasoning: reason))
        }

        return changes
    }

    private static func stagnationIncreaseRest(_ context: ExerciseSuggestionContext) -> [PrescriptionChange] {
        // Optimization: if estimated 1RM hasn't improved over 3 sessions AND user is struggling, increase rest.
        let recent = recentPerformances(context)

        // Use style-aware e1RM: for top-set styles, measure stagnation from the progression sets only.
        let e1rms: [Double]
        switch context.resolvedTrainingStyle {
        case .topSetBackoffs, .descendingPyramid:
            e1rms = recent.compactMap { perf in
                let progressionSets = selectProgressionSets(from: perf, context: context)
                return progressionSets.compactMap(\.estimated1RM).max()
            }
        default:
            e1rms = recent.compactMap(\.bestEstimated1RM)
        }
        guard e1rms.count >= 3 else { return [] }

        let recent3 = Array(e1rms.prefix(3))
        let newest = recent3[0]
        let oldest = recent3[2]
        guard oldest > 0 else { return [] }

        // Plateau threshold: within +/-2% over 3 sessions.
        let improvement = (newest - oldest) / oldest
        guard improvement < 0.02, improvement > -0.02 else { return [] }

        // Only suggest rest if user is struggling to hit targets.
        // If they're hitting targets consistently, progression rules will handle weight increases.
        guard isStrugglingWithTargets(context: context, recent: recent) else { return [] }

        let increment = 15
        let reason = "Progress has plateaued and you're struggling to hit targets. Adding rest may help recovery and performance."

        // If rest is all-same, update the policy; otherwise update progression sets.
        if context.prescription.restTimePolicy.activeMode == .allSame {
            let current = context.prescription.restTimePolicy.allSameSeconds
            let newValue = current + increment
            return [makeExerciseChange(context: context, changeType: .increaseRestTimeSeconds, previousValue: Double(current), newValue: Double(newValue), reasoning: reason)]
        }

        let progressionSets = selectProgressionSets(from: context.performance, context: context)
        guard !progressionSets.isEmpty else { return [] }

        var changes: [PrescriptionChange] = []
        for set in progressionSets {
            // Skip drop/superset chains where effective rest is intentionally zero.
            guard set.effectiveRestSeconds > 0,
                  let setPrescription = targetSet(for: set, prescription: context.prescription) else { continue }
            let current = setPrescription.targetRest
            let newValue = current + increment

            changes.append(makeSetChange(context: context, set: set, setPrescription: setPrescription, changeType: .increaseRest, previousValue: Double(current), newValue: Double(newValue), reasoning: reason))
        }

        return changes
    }

    private static func volumeRegression(_ context: ExerciseSuggestionContext) -> [PrescriptionChange] {
        // Volume regression: user consistently completes fewer sets than prescribed across 3 sessions -> suggest removing the last set.
        let prescribedSets = context.prescription.sortedSets
        let prescribedWorkingSets = prescribedSets.filter { $0.type == .working }
        guard prescribedWorkingSets.count >= 3 else { return [] } // Need at least 3 prescribed working sets to suggest removing one.

        let recent = recentPerformances(context)
        guard recent.count >= 3 else { return [] }

        let lastThree = Array(recent.prefix(3))
        var shortCount = 0

        for performance in lastThree {
            let completedWorkingSets = performance.sortedSets.filter { $0.type == .working }
            if completedWorkingSets.count < prescribedWorkingSets.count {
                shortCount += 1
            }
        }

        // Require all 3 recent sessions to show fewer working sets than prescribed.
        guard shortCount >= 3 else { return [] }

        // The set to remove is the last prescribed working set.
        let prescribedCount = prescribedWorkingSets.count
        let reason = "You've completed fewer than the prescribed \(prescribedCount) working sets in your last 3 sessions. Consider removing the last set to match your actual volume."

        return [makeExerciseChange(context: context, changeType: .removeSet, previousValue: Double(prescribedCount), newValue: Double(prescribedCount - 1), reasoning: reason)]
    }

    private static func dropSetWithoutBase(_ context: ExerciseSuggestionContext) -> [PrescriptionChange] {
        // Cleanup: drop sets should follow a regular set; if not, convert the first drop set.
        let sets = context.performance.sortedSets
        guard sets.contains(where: { $0.type == .dropSet }) else { return [] }

        let regularIndices = Set(sets.filter { $0.type == .working }.map(\.index))

        // Find first drop set that has no regular set before it.
        let targetDrop = sets.first { set in
            guard set.type == .dropSet else { return false }
            let hasRegularBefore = regularIndices.contains { $0 < set.index }
            return !hasRegularBefore
        }

        guard let dropSet = targetDrop,
              let setPrescription = targetSet(for: dropSet, prescription: context.prescription) else {
            return []
        }

        let reason = "Drop sets work best after a heavy working set. Converting the first drop set to regular gives it a proper anchor."

        return [makeSetChange(context: context, set: dropSet, setPrescription: setPrescription, changeType: .changeSetType, previousValue: Double(setPrescription.type.rawValue), newValue: Double(ExerciseSetType.working.rawValue), reasoning: reason)]
    }

    private static func progressionWeightChangeIndices(_ context: ExerciseSuggestionContext) -> Set<Int> {
        // Returns the set indices that would receive a progression-based weight change.
        let recent = recentPerformances(context)
        guard recent.count >= 2 else { return [] }

        let lastTwo = Array(recent.prefix(2))
        let repRange = context.prescription.repRange
        guard repRange.activeMode != .notSet else { return [] }
        let progressionSets = selectProgressionSets(from: context.performance, context: context)
        guard !progressionSets.isEmpty else { return [] }

        switch repRange.activeMode {
        case .range:
            let upper = repRange.upperRange
            let hitTopInBoth = lastTwo.allSatisfy { performance in
                let sets = selectProgressionSets(from: performance, context: context)
                guard !sets.isEmpty else { return false }
                return sets.allSatisfy { $0.reps >= upper }
            }
            let overshootInBoth = lastTwo.allSatisfy { performance in
                let sets = selectProgressionSets(from: performance, context: context)
                guard !sets.isEmpty else { return false }
                return sets.allSatisfy { $0.reps >= upper + 4 }
            }
            guard hitTopInBoth || overshootInBoth else { return [] }
            return Set(progressionSets.map(\.index))

        case .target:
            let target = repRange.targetReps
            let exceededInBoth = lastTwo.allSatisfy { performance in
                let sets = selectProgressionSets(from: performance, context: context)
                guard !sets.isEmpty else { return false }
                return sets.allSatisfy { $0.reps >= target + 1 }
            }
            let overshootInBoth = lastTwo.allSatisfy { performance in
                let sets = selectProgressionSets(from: performance, context: context)
                guard !sets.isEmpty else { return false }
                return sets.allSatisfy { $0.reps >= target + 5 }
            }
            guard exceededInBoth || overshootInBoth else { return [] }
            return Set(progressionSets.map(\.index))

        case .notSet:
            return []
        }
    }

    private static func warmupActingLikeWorkingSet(_ context: ExerciseSuggestionContext) -> [PrescriptionChange] {
        // Cleanup: warmup set is within 10% of top regular weight in two sessions -> suggest regular.
        let recent = recentPerformances(context)
        guard recent.count >= 2 else { return [] }

        // Evidence window: last 2 sessions.
        let lastTwo = Array(recent.prefix(2))
        var changes: [PrescriptionChange] = []

        for setPrescription in context.prescription.sortedSets where setPrescription.type == .warmup {
            var hitCount = 0
            var sourceSet: SetPerformance?

            for performance in lastTwo {
                // Compare warmup weight to the max regular set in that session.
                let regularSets = performance.sortedSets.filter { $0.complete && $0.type == .working }
                guard let maxWeight = regularSets.map(\.weight).max(), maxWeight > 0 else { continue }
                guard let set = performance.sortedSets[safe: setPrescription.index], set.complete else { continue }

                if set.weight >= maxWeight * 0.9 {
                    hitCount += 1
                    if performance.id == context.performance.id {
                        sourceSet = set
                    }
                }
            }

            guard hitCount >= 2 else { continue }

            let reason = "This warmup set is within 10% of your top working weight in recent sessions. Consider marking it as a regular set."
            changes.append(makeSetChange(context: context, set: sourceSet, setPrescription: setPrescription, changeType: .changeSetType, previousValue: Double(setPrescription.type.rawValue), newValue: Double(ExerciseSetType.working.rawValue), reasoning: reason))
        }

        return changes
    }

    private static func regularActingLikeWarmup(_ context: ExerciseSuggestionContext) -> [PrescriptionChange] {
        // Cleanup: early regular set <70% of top regular weight in two sessions -> suggest warmup.
        let recent = recentPerformances(context)
        guard recent.count >= 2 else { return [] }

        // Evidence window: last 2 sessions.
        let lastTwo = Array(recent.prefix(2))
        var changes: [PrescriptionChange] = []

        for setPrescription in context.prescription.sortedSets where setPrescription.type == .working && setPrescription.index <= 1 {
            var hitCount = 0
            var sourceSet: SetPerformance?

            for performance in lastTwo {
                // Compare this early regular set to the session's max regular set.
                let regularSets = performance.sortedSets.filter { $0.complete && $0.type == .working }
                guard let maxWeight = regularSets.map(\.weight).max(), maxWeight > 0 else { continue }
                guard let set = performance.sortedSets[safe: setPrescription.index], set.complete else { continue }

                if set.weight < maxWeight * 0.7 {
                    hitCount += 1
                    if performance.id == context.performance.id {
                        sourceSet = set
                    }
                }
            }

            guard hitCount >= 2 else { continue }

            let reason = "This set is much lighter than your top working weight. Consider marking it as a warmup."
            changes.append(makeSetChange(context: context, set: sourceSet, setPrescription: setPrescription, changeType: .changeSetType, previousValue: Double(setPrescription.type.rawValue), newValue: Double(ExerciseSetType.warmup.rawValue), reasoning: reason))
        }

        return changes
    }

    private static func isStrugglingWithTargets(context: ExerciseSuggestionContext, recent: [ExercisePerformance]) -> Bool {
        let lastThree = Array(recent.prefix(3))
        guard let targetFloor = repFloor(context) else { return false }

        // Count how many sessions had sets below or barely hitting target
        var strugglingCount = 0

        for performance in lastThree {
            let progressionSets = selectProgressionSets(from: performance, context: context)
            guard !progressionSets.isEmpty else { continue }

            // Check if any progression sets were below floor
            let anyBelowFloor = progressionSets.contains { $0.reps < targetFloor }

            // OR check if reps are barely hitting floor (within 1 rep)
            // This catches "technically hitting but clearly struggling"
            let barelyHitting = progressionSets.allSatisfy { $0.reps <= targetFloor + 1 }

            if anyBelowFloor || barelyHitting {
                strugglingCount += 1
            }
        }

        // Require at least 2 of 3 sessions showing struggle
        return strugglingCount >= 2
    }

    private static func setTypeMismatch(_ context: ExerciseSuggestionContext) -> [PrescriptionChange] {
        // Cleanup: set type mismatch across two sessions -> update prescription set type.
        let recent = recentPerformances(context)
        guard recent.count >= 2 else { return [] }

        let lastTwo = Array(recent.prefix(2))
        var changes: [PrescriptionChange] = []

        for setPrescription in context.prescription.sortedSets {
            var types: [ExerciseSetType] = []
            var sourceSet: SetPerformance?

            for performance in lastTwo {
                guard let set = performance.sortedSets[safe: setPrescription.index], set.complete else { continue }
                types.append(set.type)
                if performance.id == context.performance.id {
                    sourceSet = set
                }
            }

            guard types.count == 2, let firstType = types.first, types.allSatisfy({ $0 == firstType }) else { continue }
            guard firstType != setPrescription.type else { continue }

            let reason = "You've logged this set as \(firstType.displayName) for the last two sessions. Update the prescription to match."

            changes.append(makeSetChange(context: context, set: sourceSet, setPrescription: setPrescription, changeType: .changeSetType, previousValue: Double(setPrescription.type.rawValue), newValue: Double(firstType.rawValue), reasoning: reason))
        }

        return changes
    }

    private static func selectProgressionSets(from performance: ExercisePerformance, context: ExerciseSuggestionContext) -> [SetPerformance] {
        MetricsCalculator.selectProgressionSets(from: performance, overrideStyle: context.resolvedTrainingStyle)
    }

    /// Returns a multiplier for weight increments based on training style.
    /// Top-set styles can handle slightly larger jumps because backoff volume provides recovery stimulus.
    private static func styleIncrementMultiplier(_ context: ExerciseSuggestionContext) -> Double {
        switch context.resolvedTrainingStyle {
        case .topSetBackoffs:
            return 1.25
        default:
            return 1.0
        }
    }

    private static func repFloor(_ context: ExerciseSuggestionContext) -> Int? {
        let policy = context.prescription.repRange
        switch policy.activeMode {
        case .range:
            return policy.lowerRange
        case .target:
            return policy.targetReps
        case .notSet:
            return nil
        }
    }

    private static func recentPerformances(_ context: ExerciseSuggestionContext) -> [ExercisePerformance] {
        // Include the current session at the front of the historical list.
        [context.performance] + context.history
    }

    private static func targetSet(for set: SetPerformance, prescription: ExercisePrescription) -> SetPrescription? {
        // Prefer a direct prescription link when available; fallback to index match.
        if let setPrescription = set.prescription {
            return setPrescription
        }
        return prescription.sortedSets[safe: set.index]
    }

    private static func weightIncrement(for weight: Double, context: ExerciseSuggestionContext) -> Double {
        MetricsCalculator.weightIncrement(for: weight, primaryMuscle: context.prescription.musclesTargeted.first!, equipmentType: context.prescription.equipmentType)
    }

    private static func makeSetChange(context: ExerciseSuggestionContext, set: SetPerformance?, setPrescription: SetPrescription, changeType: ChangeType, previousValue: Double, newValue: Double, reasoning: String) -> PrescriptionChange {
        // Build a set-scoped suggestion change record.
        return PrescriptionChange(source: .rules, catalogID: context.prescription.catalogID, sessionFrom: context.session, sourceExercisePerformance: context.performance, sourceSetPerformance: set, targetExercisePrescription: context.prescription, targetSetPrescription: setPrescription, targetPlan: context.plan, changeType: changeType, previousValue: previousValue, newValue: newValue, changeReasoning: reasoning)
    }

    private static func makeExerciseChange(context: ExerciseSuggestionContext, changeType: ChangeType, previousValue: Double, newValue: Double, reasoning: String) -> PrescriptionChange {
        // Build an exercise-level suggestion change record.
        return PrescriptionChange(source: .rules, catalogID: context.prescription.catalogID, sessionFrom: context.session, sourceExercisePerformance: context.performance, targetExercisePrescription: context.prescription, targetPlan: context.plan, changeType: changeType, previousValue: previousValue, newValue: newValue, changeReasoning: reasoning)
    }
}

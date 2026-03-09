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
        var suggestions: [PrescriptionChange] = []

        let progression = progressionSuggestions(context)
        suggestions.append(contentsOf: progression)

        let safetyAndCleanup = safetyAndCleanupSuggestions(context)
        suggestions.append(contentsOf: safetyAndCleanup)

        let shouldHold = progression.isEmpty && safetyAndCleanup.isEmpty && shouldHoldSteady(context)
        if !shouldHold {
            suggestions.append(contentsOf: plateauSuggestions(context))
        }

        suggestions.append(contentsOf: setTypeHygieneSuggestions(context))

        return suggestions
    }

    private static func progressionSuggestions(_ context: ExerciseSuggestionContext) -> [PrescriptionChange] {
        var suggestions: [PrescriptionChange] = []
        suggestions.append(contentsOf: largeOvershootProgression(context))
        suggestions.append(contentsOf: immediateProgressionRange(context))
        suggestions.append(contentsOf: immediateProgressionTarget(context))
        suggestions.append(contentsOf: confirmedProgressionRange(context))
        suggestions.append(contentsOf: confirmedProgressionTarget(context))
        suggestions.append(contentsOf: steadyRepIncreaseWithinRange(context))
        return suggestions
    }

    private static func safetyAndCleanupSuggestions(_ context: ExerciseSuggestionContext) -> [PrescriptionChange] {
        var suggestions: [PrescriptionChange] = []
        suggestions.append(contentsOf: belowRangeWeightDecrease(context))
        suggestions.append(contentsOf: reducedWeightToHitReps(context))
        suggestions.append(contentsOf: matchActualWeight(context))
        return suggestions
    }

    private static func plateauSuggestions(_ context: ExerciseSuggestionContext) -> [PrescriptionChange] {
        var suggestions: [PrescriptionChange] = []
        suggestions.append(contentsOf: shortRestPerformanceDrop(context))
        suggestions.append(contentsOf: stagnationIncreaseRest(context))
        return suggestions
    }

    private static func setTypeHygieneSuggestions(_ context: ExerciseSuggestionContext) -> [PrescriptionChange] {
        var suggestions: [PrescriptionChange] = []
        suggestions.append(contentsOf: dropSetWithoutBase(context))
        suggestions.append(contentsOf: warmupActingLikeWorkingSet(context))
        suggestions.append(contentsOf: regularActingLikeWarmup(context))
        suggestions.append(contentsOf: setTypeMismatch(context))
        return suggestions
    }

    private static func immediateProgressionRange(_ context: ExerciseSuggestionContext) -> [PrescriptionChange] {
        // Range mode progression: if primary sets reach the top of the range now, progress immediately.
        let repRange = context.prescription.repRange ?? RepRangePolicy()
        guard repRange.activeMode == .range else { return [] }
        let lower = repRange.lowerRange
        let upper = repRange.upperRange
        let progressionSets = primaryProgressionSets(from: context.performance, context: context)
        guard !progressionSets.isEmpty else { return [] }
        guard progressionSets.allSatisfy({ $0.reps >= upper }) else { return [] }

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
                ? "You hit the top of your rep range (\(upper)) on your primary sets this session. Increase weight to keep progressing."
                : "You hit the top of your rep range (\(upper)) on your primary sets this session. Increase weight and keep reps at \(lower)."

            changes.append(makeSetChange(context: context, set: set, setPrescription: setPrescription, changeType: .increaseWeight, previousValue: currentWeight, newValue: newWeight, reasoning: weightReason))

            if shouldResetReps {
                changes.append(makeSetChange(context: context, set: set, setPrescription: setPrescription, changeType: .decreaseReps, previousValue: Double(setPrescription.targetReps), newValue: Double(lower), reasoning: repsReason))
            }
        }

        return changes
    }

    private static func immediateProgressionTarget(_ context: ExerciseSuggestionContext) -> [PrescriptionChange] {
        // Target mode progression: if primary sets exceed the target now, progress immediately.
        let repRange = context.prescription.repRange ?? RepRangePolicy()
        guard repRange.activeMode == .target else { return [] }
        let target = repRange.targetReps
        let progressionSets = primaryProgressionSets(from: context.performance, context: context)
        guard !progressionSets.isEmpty else { return [] }
        guard progressionSets.allSatisfy({ $0.reps >= target + 1 }) else { return [] }

        var changes: [PrescriptionChange] = []
        let reason = "You exceeded your rep target (\(target)) on your primary sets this session. Increase weight to keep progressing."
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

    private static func confirmedProgressionRange(_ context: ExerciseSuggestionContext) -> [PrescriptionChange] {
        let repRange = context.prescription.repRange ?? RepRangePolicy()
        guard repRange.activeMode == .range else { return [] }
        let lower = repRange.lowerRange
        let upper = repRange.upperRange
        let recent = recentPerformances(context)
        guard recent.count >= 2 else { return [] }
        guard !qualifiesForImmediateLoadProgression(context) else { return [] }

        let lastTwo = Array(recent.prefix(2))
        let nearTopInBoth = lastTwo.allSatisfy { performance in
            let progressionSets = primaryProgressionSets(from: performance, context: context)
            guard !progressionSets.isEmpty else { return false }
            return progressionSets.allSatisfy { $0.reps >= upper - 1 }
        }
        guard nearTopInBoth else { return [] }

        let progressionSets = primaryProgressionSets(from: context.performance, context: context)
        guard !progressionSets.isEmpty else { return [] }

        var changes: [PrescriptionChange] = []
        let repsReason = "Reset reps to \(lower) to account for the added weight."
        let multiplier = styleIncrementMultiplier(context)

        for set in progressionSets {
            guard let setPrescription = targetSet(for: set, prescription: context.prescription) else { continue }
            let currentWeight = setPrescription.targetWeight
            guard currentWeight > 0 else { continue }

            let baseIncrement = weightIncrement(for: currentWeight, context: context)
            let newWeight = MetricsCalculator.roundToNearestPlate(currentWeight + baseIncrement * multiplier)
            let shouldResetReps = setPrescription.targetReps != lower
            let weightReason = shouldResetReps
                ? "You've been near the top of your rep range (\(upper)) for two sessions on your primary sets. Increase weight to keep progressing."
                : "You've been near the top of your rep range (\(upper)) for two sessions on your primary sets. Increase weight and keep reps at \(lower)."

            changes.append(makeSetChange(context: context, set: set, setPrescription: setPrescription, changeType: .increaseWeight, previousValue: currentWeight, newValue: newWeight, reasoning: weightReason))

            if shouldResetReps {
                changes.append(makeSetChange(context: context, set: set, setPrescription: setPrescription, changeType: .decreaseReps, previousValue: Double(setPrescription.targetReps), newValue: Double(lower), reasoning: repsReason))
            }
        }

        return changes
    }

    private static func confirmedProgressionTarget(_ context: ExerciseSuggestionContext) -> [PrescriptionChange] {
        let repRange = context.prescription.repRange ?? RepRangePolicy()
        guard repRange.activeMode == .target else { return [] }
        let target = repRange.targetReps
        let recent = recentPerformances(context)
        guard recent.count >= 2 else { return [] }
        guard !qualifiesForImmediateLoadProgression(context) else { return [] }

        let lastTwo = Array(recent.prefix(2))
        let nearTargetInBoth = lastTwo.allSatisfy { performance in
            let progressionSets = primaryProgressionSets(from: performance, context: context)
            guard !progressionSets.isEmpty else { return false }
            return progressionSets.allSatisfy { $0.reps >= target }
        }
        guard nearTargetInBoth else { return [] }

        let progressionSets = primaryProgressionSets(from: context.performance, context: context)
        guard !progressionSets.isEmpty else { return [] }

        var changes: [PrescriptionChange] = []
        let reason = "You've consistently reached your rep target (\(target)) on your primary sets. Increase weight to keep progressing."
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
        let repRange = context.prescription.repRange ?? RepRangePolicy()
        guard repRange.activeMode == .range else { return [] }
        let lower = repRange.lowerRange
        let upper = repRange.upperRange
        let recent = recentPerformances(context)
        guard recent.count >= 2 else { return [] }

        let progressionSets = primaryProgressionSets(from: context.performance, context: context)
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
                guard let perfSet = matchingSetPerformance(in: performance, for: setPrescription) else { continue }
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
        // Large overshoot: one emphatically strong session is enough for a larger jump.
        let repRange = context.prescription.repRange ?? RepRangePolicy()
        guard repRange.activeMode != .notSet else { return [] }
        let progressionSets = primaryProgressionSets(from: context.performance, context: context)
        guard !progressionSets.isEmpty else { return [] }

        let overshootMet: Bool
        var lower = 0
        var shouldResetReps = false
        switch repRange.activeMode {
        case .range:
            lower = repRange.lowerRange
            shouldResetReps = true
            let upper = repRange.upperRange
            overshootMet = progressionSets.allSatisfy { $0.reps >= upper + 3 }
        case .target:
            let target = repRange.targetReps
            overshootMet = progressionSets.allSatisfy { $0.reps >= target + 4 }
        case .notSet:
            return []
        }

        guard overshootMet else { return [] }

        var changes: [PrescriptionChange] = []
        let weightReason = "You significantly overshot the target on your primary sets this session. Increase weight to better match your current strength."
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
        let repRange = context.prescription.repRange ?? RepRangePolicy()
        guard repRange.activeMode == .range else { return [] }
        let lower = repRange.lowerRange
        let recent = recentPerformances(context)
        guard recent.count >= 2 else { return [] }

        // Evidence window: last 3 sessions, need 2 sessions below range.
        let lastThree = Array(recent.prefix(3))
        var belowCount = 0

        for performance in lastThree {
            let progressionSets = primaryProgressionSets(from: performance, context: context)
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

        let progressionSets = primaryProgressionSets(from: context.performance, context: context)
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
                guard let set = matchingSetPerformance(in: performance, for: setPrescription),
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

            changes.append(makeSetChange(context: context, set: matchingSetPerformance(in: context.performance, for: setPrescription, requireComplete: false), setPrescription: setPrescription, changeType: changeType, previousValue: targetWeight, newValue: newWeight, reasoning: reason))
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
                guard let set = matchingSetPerformance(in: performance, for: setPrescription) else { continue }

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

            changes.append(makeSetChange(context: context, set: matchingSetPerformance(in: context.performance, for: setPrescription, requireComplete: false), setPrescription: setPrescription, changeType: .decreaseWeight, previousValue: setPrescription.targetWeight, newValue: newWeight, reasoning: reason))
        }

        return changes
    }

    private static func shortRestPerformanceDrop(_ context: ExerciseSuggestionContext) -> [PrescriptionChange] {
        // Rest rule: user rests shorter than prescribed and reps drop -> suggest more rest.
        let recent = recentPerformances(context)
        guard recent.count >= 2 else { return [] }
        guard !shouldHoldSteady(context) else { return [] }

        let lastTwo = Array(recent.prefix(2))
        let repFloor = repFloor(context)

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
                let targetRest = setPrescription.targetRest

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
        guard !shouldHoldSteady(context) else { return [] }

        // Use style-aware e1RM: for top-set styles, measure stagnation from the progression sets only.
        let e1rms: [Double]
        switch context.resolvedTrainingStyle {
        case .topSetBackoffs, .descendingPyramid:
            e1rms = recent.compactMap { perf in
                let progressionSets = primaryProgressionSets(from: perf, context: context)
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

        let progressionSets = primaryProgressionSets(from: context.performance, context: context)
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
        let repRange = context.prescription.repRange ?? RepRangePolicy()
        guard repRange.activeMode != .notSet else { return [] }
        let progressionSets = primaryProgressionSets(from: context.performance, context: context)
        guard !progressionSets.isEmpty else { return [] }

        switch repRange.activeMode {
        case .range:
            let upper = repRange.upperRange
            let hitTopInBoth = lastTwo.allSatisfy { performance in
                let sets = primaryProgressionSets(from: performance, context: context)
                guard !sets.isEmpty else { return false }
                return sets.allSatisfy { $0.reps >= upper }
            }
            let overshootInBoth = lastTwo.allSatisfy { performance in
                let sets = primaryProgressionSets(from: performance, context: context)
                guard !sets.isEmpty else { return false }
                return sets.allSatisfy { $0.reps >= upper - 1 }
            }
            guard hitTopInBoth || overshootInBoth else { return [] }
            return Set(progressionSets.map(\.index))

        case .target:
            let target = repRange.targetReps
            let exceededInBoth = lastTwo.allSatisfy { performance in
                let sets = primaryProgressionSets(from: performance, context: context)
                guard !sets.isEmpty else { return false }
                return sets.allSatisfy { $0.reps >= target + 1 }
            }
            let overshootInBoth = lastTwo.allSatisfy { performance in
                let sets = primaryProgressionSets(from: performance, context: context)
                guard !sets.isEmpty else { return false }
                return sets.allSatisfy { $0.reps >= target }
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
                guard let set = matchingSetPerformance(in: performance, for: setPrescription) else { continue }

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
                guard let set = matchingSetPerformance(in: performance, for: setPrescription) else { continue }

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
            let progressionSets = primaryProgressionSets(from: performance, context: context)
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
                guard let set = matchingSetPerformance(in: performance, for: setPrescription) else { continue }
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

    private static func primaryProgressionSets(from performance: ExercisePerformance, context: ExerciseSuggestionContext) -> [SetPerformance] {
        MetricsCalculator.selectProgressionSets(from: performance, overrideStyle: context.resolvedTrainingStyle)
    }

    private static func qualifiesForImmediateLoadProgression(_ context: ExerciseSuggestionContext) -> Bool {
        let repRange = context.prescription.repRange ?? RepRangePolicy()
        let progressionSets = primaryProgressionSets(from: context.performance, context: context)
        guard !progressionSets.isEmpty else { return false }

        switch repRange.activeMode {
        case .range:
            return progressionSets.allSatisfy { $0.reps >= repRange.upperRange }
        case .target:
            return progressionSets.allSatisfy { $0.reps >= repRange.targetReps + 1 }
        case .notSet:
            return false
        }
    }

    private static func shouldHoldSteady(_ context: ExerciseSuggestionContext) -> Bool {
        let repRange = context.prescription.repRange ?? RepRangePolicy()
        let progressionSets = primaryProgressionSets(from: context.performance, context: context)
        guard !progressionSets.isEmpty else { return false }

        switch repRange.activeMode {
        case .range:
            let upper = repRange.upperRange
            let lower = repRange.lowerRange
            let allInRange = progressionSets.allSatisfy { $0.reps >= lower && $0.reps <= upper + 1 }
            let closeToProgression = progressionSets.allSatisfy { $0.reps >= max(lower, upper - 1) }
            return allInRange && closeToProgression
        case .target:
            let target = repRange.targetReps
            let onTrack = progressionSets.allSatisfy { $0.reps >= target - 1 }
            let closeToProgression = progressionSets.allSatisfy { $0.reps >= target }
            return onTrack && closeToProgression
        case .notSet:
            return false
        }
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
        let policy = context.prescription.repRange ?? RepRangePolicy()
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

    private static func matchingSetPerformance(in performance: ExercisePerformance, for setPrescription: SetPrescription, requireComplete: Bool = true) -> SetPerformance? {
        let candidateSets = requireComplete
            ? performance.sortedSets.filter(\.complete)
            : performance.sortedSets

        if let linkedSet = candidateSets.first(where: { $0.prescription?.id == setPrescription.id }) {
            return linkedSet
        }

        if let typedMatch = candidateSets.first(where: { $0.index == setPrescription.index && $0.type == setPrescription.type }) {
            return typedMatch
        }

        return candidateSets.first(where: { $0.index == setPrescription.index })
    }

    private static func weightIncrement(for weight: Double, context: ExerciseSuggestionContext) -> Double {
        let primaryMuscle = context.prescription.musclesTargeted.first
            ?? context.performance.musclesTargeted.first
            ?? .chest
        return MetricsCalculator.weightIncrement(for: weight, primaryMuscle: primaryMuscle, equipmentType: context.prescription.equipmentType)
    }

    private static func makeSetChange(context: ExerciseSuggestionContext, set: SetPerformance?, setPrescription: SetPrescription, changeType: ChangeType, previousValue: Double, newValue: Double, reasoning: String) -> PrescriptionChange {
        // Build a set-scoped suggestion change record.
        return PrescriptionChange(source: .rules, catalogID: context.prescription.catalogID, sessionFrom: context.session, sourceExercisePerformance: context.performance, sourceSetPerformance: set, targetExercisePrescription: context.prescription, targetSetPrescription: setPrescription, targetPlan: context.plan, changeType: changeType, previousValue: previousValue, newValue: newValue, changeReasoning: reasoning, trainingStyle: context.resolvedTrainingStyle)
    }

    private static func makeExerciseChange(context: ExerciseSuggestionContext, changeType: ChangeType, previousValue: Double, newValue: Double, reasoning: String) -> PrescriptionChange {
        // Build an exercise-level suggestion change record.
        return PrescriptionChange(source: .rules, catalogID: context.prescription.catalogID, sessionFrom: context.session, sourceExercisePerformance: context.performance, targetExercisePrescription: context.prescription, targetPlan: context.plan, changeType: changeType, previousValue: previousValue, newValue: newValue, changeReasoning: reasoning, trainingStyle: context.resolvedTrainingStyle)
    }
}

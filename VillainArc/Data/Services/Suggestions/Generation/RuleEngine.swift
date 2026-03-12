import Foundation

struct ExerciseSuggestionContext {
    let session: WorkoutSession
    let performance: ExercisePerformance
    let prescription: ExercisePrescription
    let history: [ExercisePerformance]
    let plan: WorkoutPlan
    let resolvedTrainingStyle: TrainingStyle
}

@MainActor
struct RuleEngine {
    private struct TargetSetContext {
        let index: Int
        let type: ExerciseSetType
        let targetWeight: Double
        let targetReps: Int
        let targetRest: Int
        let targetRPE: Int

        init(snapshot: SetTargetSnapshot) {
            index = snapshot.index
            type = snapshot.type
            targetWeight = snapshot.targetWeight
            targetReps = snapshot.targetReps
            targetRest = snapshot.targetRest
            targetRPE = snapshot.targetRPE
        }
    }

    private struct RepEvidence {
        let sessionCount: Int
        let minRep: Int
        let maxRep: Int
        let representativeReps: [Int]
    }

    static func evaluate(context: ExerciseSuggestionContext) -> [SuggestionEventDraft] {
        var suggestions: [SuggestionEventDraft] = []

        let progression = progressionSuggestions(context)
        suggestions.append(contentsOf: progression)

        let safetyAndCleanup = safetyAndCleanupSuggestions(context)
        suggestions.append(contentsOf: safetyAndCleanup)

        let shouldHold = progression.isEmpty && safetyAndCleanup.isEmpty && shouldHoldSteady(context)
        if !shouldHold {
            suggestions.append(contentsOf: plateauSuggestions(context))
        }

        suggestions.append(contentsOf: setTypeHygieneSuggestions(context))

        if !suggestions.contains(where: { $0.targetSetIndex != nil }) {
            suggestions.append(contentsOf: exerciseLevelRepRangeSuggestions(context))
        }

        return suggestions
    }

    private static func progressionSuggestions(_ context: ExerciseSuggestionContext) -> [SuggestionEventDraft] {
        var suggestions: [SuggestionEventDraft] = []
        suggestions.append(contentsOf: largeOvershootProgression(context))
        suggestions.append(contentsOf: immediateProgressionRange(context))
        suggestions.append(contentsOf: immediateProgressionTarget(context))
        suggestions.append(contentsOf: confirmedProgressionRange(context))
        suggestions.append(contentsOf: confirmedProgressionTarget(context))
        suggestions.append(contentsOf: steadyRepIncreaseWithinRange(context))
        return suggestions
    }

    private static func safetyAndCleanupSuggestions(_ context: ExerciseSuggestionContext) -> [SuggestionEventDraft] {
        var suggestions: [SuggestionEventDraft] = []
        suggestions.append(contentsOf: belowRangeWeightDecrease(context))
        suggestions.append(contentsOf: reducedWeightToHitReps(context))
        suggestions.append(contentsOf: matchActualWeight(context))
        return suggestions
    }

    private static func plateauSuggestions(_ context: ExerciseSuggestionContext) -> [SuggestionEventDraft] {
        var suggestions: [SuggestionEventDraft] = []
        suggestions.append(contentsOf: shortRestPerformanceDrop(context))
        suggestions.append(contentsOf: stagnationIncreaseRest(context))
        return suggestions
    }

    private static func setTypeHygieneSuggestions(_ context: ExerciseSuggestionContext) -> [SuggestionEventDraft] {
        var suggestions: [SuggestionEventDraft] = []
        suggestions.append(contentsOf: dropSetWithoutBase(context))
        suggestions.append(contentsOf: warmupActingLikeWorkingSet(context))
        suggestions.append(contentsOf: regularActingLikeWarmup(context))
        suggestions.append(contentsOf: setTypeMismatch(context))
        return suggestions
    }

    private static func exerciseLevelRepRangeSuggestions(_ context: ExerciseSuggestionContext) -> [SuggestionEventDraft] {
        if let initialRange = suggestInitialRange(context) {
            return [initialRange]
        }
        if let targetToRange = suggestTargetToRange(context) {
            return [targetToRange]
        }
        if let shiftedRangeUp = suggestShiftedRange(context, direction: .up) {
            return [shiftedRangeUp]
        }
        if let shiftedRangeDown = suggestShiftedRange(context, direction: .down) {
            return [shiftedRangeDown]
        }
        return []
    }

    private static func immediateProgressionRange(_ context: ExerciseSuggestionContext) -> [SuggestionEventDraft] {
        // Range mode progression: if primary sets reach the top of the range now, progress immediately.
        let repRange = context.prescription.repRange ?? RepRangePolicy()
        guard repRange.activeMode == .range else { return [] }
        let lower = repRange.lowerRange
        let upper = repRange.upperRange
        let progressionSets = primaryProgressionSets(from: context.performance, context: context)
        guard !progressionSets.isEmpty else { return [] }
        guard progressionSets.allSatisfy({ $0.reps >= upper }) else { return [] }

        var events: [SuggestionEventDraft] = []
        let repsReason = "Reset reps to \(lower) to account for the added weight."

        let multiplier = styleIncrementMultiplier(context)

        for set in progressionSets {
            guard let setPrescription = targetSet(for: set) else { continue }
            let currentWeight = setPrescription.targetWeight
            guard currentWeight > 0 else { continue }

            // Increment is based on muscle group, weight size, and training style.
            let baseIncrement = weightIncrement(for: currentWeight, context: context)
            let newWeight = MetricsCalculator.roundToNearestPlate(currentWeight + baseIncrement * multiplier)
            let shouldResetReps = setPrescription.targetReps != lower
            let weightReason = shouldResetReps
                ? "You hit the top of your rep range (\(upper)) on your primary sets this session. Increase weight to keep progressing."
                : "You hit the top of your rep range (\(upper)) on your primary sets this session. Increase weight and keep reps at \(lower)."

            var draftChanges: [PrescriptionChangeDraft] = [
                makeChangeDraft(changeType: .increaseWeight, previousValue: currentWeight, newValue: newWeight)
            ]

            if shouldResetReps {
                draftChanges.append(makeChangeDraft(changeType: .decreaseReps, previousValue: Double(setPrescription.targetReps), newValue: Double(lower)))
            }

            events.append(makeSetEvent(context: context, setPrescription: setPrescription, changes: draftChanges, reasoning: combineReasoning(weightReason, shouldResetReps ? repsReason : nil)))
        }

        return events
    }

    private static func immediateProgressionTarget(_ context: ExerciseSuggestionContext) -> [SuggestionEventDraft] {
        // Target mode progression: if primary sets exceed the target now, progress immediately.
        let repRange = context.prescription.repRange ?? RepRangePolicy()
        guard repRange.activeMode == .target else { return [] }
        let target = repRange.targetReps
        let progressionSets = primaryProgressionSets(from: context.performance, context: context)
        guard !progressionSets.isEmpty else { return [] }
        guard progressionSets.allSatisfy({ $0.reps >= target + 1 }) else { return [] }

        var events: [SuggestionEventDraft] = []
        let reason = "You exceeded your rep target (\(target)) on your primary sets this session. Increase weight to keep progressing."
        let multiplier = styleIncrementMultiplier(context)

        for set in progressionSets {
            guard let setPrescription = targetSet(for: set) else { continue }
            let currentWeight = setPrescription.targetWeight
            guard currentWeight > 0 else { continue }

            let baseIncrement = weightIncrement(for: currentWeight, context: context)
            let newWeight = MetricsCalculator.roundToNearestPlate(currentWeight + baseIncrement * multiplier)

            events.append(makeSetEvent(context: context, setPrescription: setPrescription, changes: [makeChangeDraft(changeType: .increaseWeight, previousValue: currentWeight, newValue: newWeight)], reasoning: reason))
        }

        return events
    }

    private static func confirmedProgressionRange(_ context: ExerciseSuggestionContext) -> [SuggestionEventDraft] {
        let repRange = context.prescription.repRange ?? RepRangePolicy()
        guard repRange.activeMode == .range else { return [] }
        let lower = repRange.lowerRange
        let upper = repRange.upperRange
        let recent = recentPerformances(context)
        guard recent.count >= 2 else { return [] }
        guard !qualifiesForImmediateLoadProgression(context) else { return [] }

        let lastTwo = Array(recent.prefix(2))
        let nearTopInBoth = lastTwo.allSatisfy { performance in
            guard let performanceRepRange = historicalOrCurrentRepRange(for: performance, context: context),
                  performanceRepRange.mode == .range else { return false }
            let progressionSets = primaryProgressionSets(from: performance, context: context)
            guard !progressionSets.isEmpty else { return false }
            return progressionSets.allSatisfy { $0.reps >= performanceRepRange.upper - 1 }
        }
        guard nearTopInBoth else { return [] }

        let progressionSets = primaryProgressionSets(from: context.performance, context: context)
        guard !progressionSets.isEmpty else { return [] }

        var events: [SuggestionEventDraft] = []
        let repsReason = "Reset reps to \(lower) to account for the added weight."
        let multiplier = styleIncrementMultiplier(context)

        for set in progressionSets {
            guard let setPrescription = targetSet(for: set) else { continue }
            let currentWeight = setPrescription.targetWeight
            guard currentWeight > 0 else { continue }

            let baseIncrement = weightIncrement(for: currentWeight, context: context)
            let newWeight = MetricsCalculator.roundToNearestPlate(currentWeight + baseIncrement * multiplier)
            let shouldResetReps = setPrescription.targetReps != lower
            let weightReason = shouldResetReps
                ? "You've been near the top of your rep range (\(upper)) for two sessions on your primary sets. Increase weight to keep progressing."
                : "You've been near the top of your rep range (\(upper)) for two sessions on your primary sets. Increase weight and keep reps at \(lower)."

            var draftChanges: [PrescriptionChangeDraft] = [
                makeChangeDraft(changeType: .increaseWeight, previousValue: currentWeight, newValue: newWeight)
            ]

            if shouldResetReps {
                draftChanges.append(makeChangeDraft(changeType: .decreaseReps, previousValue: Double(setPrescription.targetReps), newValue: Double(lower)))
            }

            events.append(makeSetEvent(context: context, setPrescription: setPrescription, changes: draftChanges, reasoning: combineReasoning(weightReason, shouldResetReps ? repsReason : nil)))
        }

        return events
    }

    private static func confirmedProgressionTarget(_ context: ExerciseSuggestionContext) -> [SuggestionEventDraft] {
        let repRange = context.prescription.repRange ?? RepRangePolicy()
        guard repRange.activeMode == .target else { return [] }
        let target = repRange.targetReps
        let recent = recentPerformances(context)
        guard recent.count >= 2 else { return [] }
        guard !qualifiesForImmediateLoadProgression(context) else { return [] }

        let lastTwo = Array(recent.prefix(2))
        let nearTargetInBoth = lastTwo.allSatisfy { performance in
            guard let performanceRepRange = historicalOrCurrentRepRange(for: performance, context: context),
                  performanceRepRange.mode == .target else { return false }
            let progressionSets = primaryProgressionSets(from: performance, context: context)
            guard !progressionSets.isEmpty else { return false }
            return progressionSets.allSatisfy { $0.reps >= performanceRepRange.target }
        }
        guard nearTargetInBoth else { return [] }

        let progressionSets = primaryProgressionSets(from: context.performance, context: context)
        guard !progressionSets.isEmpty else { return [] }

        var events: [SuggestionEventDraft] = []
        let reason = "You've consistently reached your rep target (\(target)) on your primary sets. Increase weight to keep progressing."
        let multiplier = styleIncrementMultiplier(context)

        for set in progressionSets {
            guard let setPrescription = targetSet(for: set) else { continue }
            let currentWeight = setPrescription.targetWeight
            guard currentWeight > 0 else { continue }

            let baseIncrement = weightIncrement(for: currentWeight, context: context)
            let newWeight = MetricsCalculator.roundToNearestPlate(currentWeight + baseIncrement * multiplier)

            events.append(makeSetEvent(context: context, setPrescription: setPrescription, changes: [makeChangeDraft(changeType: .increaseWeight, previousValue: currentWeight, newValue: newWeight)], reasoning: reason))
        }

        return events
    }

    private static func steadyRepIncreaseWithinRange(_ context: ExerciseSuggestionContext) -> [SuggestionEventDraft] {
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

        var events: [SuggestionEventDraft] = []

        for set in progressionSets {
            guard let setPrescription = targetSet(for: set) else { continue }
            guard setPrescription.type == .working else { continue }
            guard !progressionIndices.contains(setPrescription.index) else { continue }
            guard setPrescription.targetReps > 0 else { continue }

            var samples: [(reps: Int, weight: Double)] = []
            var includesCurrent = false

            for performance in evidence {
                guard let perfSet = matchingSetPerformance(in: performance, for: setPrescription, context: context) else { continue }
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

            events.append(makeSetEvent(context: context, setPrescription: setPrescription, changes: [makeChangeDraft(changeType: .increaseReps, previousValue: Double(setPrescription.targetReps), newValue: Double(newReps))], reasoning: reason))
        }

        return events
    }

    private static func largeOvershootProgression(_ context: ExerciseSuggestionContext) -> [SuggestionEventDraft] {
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

        var events: [SuggestionEventDraft] = []
        let weightReason = "You significantly overshot the target on your primary sets this session. Increase weight to better match your current strength."
        let repsReason = "Reset reps to \(lower) to account for the larger weight jump."

        for set in progressionSets {
            guard let setPrescription = targetSet(for: set) else { continue }
            let currentWeight = setPrescription.targetWeight
            guard currentWeight > 0 else { continue }

            // Larger jump = 1.5x the usual increment.
            let baseIncrement = weightIncrement(for: currentWeight, context: context)
            let jumpWeight = currentWeight + (baseIncrement * 1.5)
            let newWeight = MetricsCalculator.roundToNearestPlate(jumpWeight)

            var draftChanges: [PrescriptionChangeDraft] = [
                makeChangeDraft(changeType: .increaseWeight, previousValue: currentWeight, newValue: newWeight)
            ]

            if shouldResetReps, setPrescription.targetReps != lower {
                draftChanges.append(makeChangeDraft(changeType: .decreaseReps, previousValue: Double(setPrescription.targetReps), newValue: Double(lower)))
            }

            events.append(makeSetEvent(context: context, setPrescription: setPrescription, changes: draftChanges, reasoning: combineReasoning(weightReason, shouldResetReps && setPrescription.targetReps != lower ? repsReason : nil)))
        }

        return events
    }

    private static func belowRangeWeightDecrease(_ context: ExerciseSuggestionContext) -> [SuggestionEventDraft] {
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
            guard let performanceRepRange = historicalOrCurrentRepRange(for: performance, context: context),
                  performanceRepRange.mode == .range else { continue }
            let progressionSets = primaryProgressionSets(from: performance, context: context)
            guard !progressionSets.isEmpty else { continue }

            var sessionBelow = true
            for set in progressionSets {
                guard let setTarget = historicalOrCurrentTargetSet(for: set, context: context) else {
                    sessionBelow = false
                    break
                }

                // Only count if they tried the prescribed load.
                let attemptedWeight = abs(set.weight - setTarget.targetWeight) <= 2.5
                if !(set.reps < performanceRepRange.lower && attemptedWeight) {
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

        var events: [SuggestionEventDraft] = []
        let reason = "You fell below the minimum rep target (\(lower)) in 2 of your last 3 sessions. Reduce weight slightly to stay in range."

        for set in progressionSets {
            guard let setPrescription = targetSet(for: set) else { continue }
            let currentWeight = setPrescription.targetWeight
            guard currentWeight > 0 else { continue }

            let decrement = weightIncrement(for: currentWeight, context: context)
            let newWeight = MetricsCalculator.roundToNearestPlate(max(0, currentWeight - decrement))

            events.append(makeSetEvent(context: context, setPrescription: setPrescription, changes: [makeChangeDraft(changeType: .decreaseWeight, previousValue: currentWeight, newValue: newWeight)], reasoning: reason))
        }

        return events
    }

    private static func matchActualWeight(_ context: ExerciseSuggestionContext) -> [SuggestionEventDraft] {
        // Cleanup: user consistently uses a different weight -> update prescription weight.
        let recent = recentPerformances(context)
        guard recent.count >= 3 else { return [] }

        // Avoid fighting progression rules: if a progression weight increase is already warranted, skip cleanup.
        let progressionIndices = progressionWeightChangeIndices(context)

        // Require 3 data points (stability).
        let lastThree = Array(recent.prefix(3))
        var events: [SuggestionEventDraft] = []

        for setPrescription in context.prescription.sortedSets {
            guard setPrescription.type == .working else { continue }
            if progressionIndices.contains(setPrescription.index) {
                continue
            }

            var weights: [Double] = []
            for performance in lastThree {
                guard let set = matchingSetPerformance(in: performance, for: setPrescription, context: context),
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

            events.append(makeSetEvent(context: context, setPrescription: setPrescription, changes: [makeChangeDraft(changeType: changeType, previousValue: targetWeight, newValue: newWeight)], reasoning: reason))
        }

        return events
    }

    private static func reducedWeightToHitReps(_ context: ExerciseSuggestionContext) -> [SuggestionEventDraft] {
        // Cleanup: user regularly lowers weight to hit reps -> reduce prescribed load.
        let recent = recentPerformances(context)
        guard recent.count >= 2 else { return [] }

        let lastTwo = Array(recent.prefix(2))
        let repFloor = repFloor(context)

        var events: [SuggestionEventDraft] = []

        for setPrescription in context.prescription.sortedSets where setPrescription.type == .working {
            var reducedWeights: [Double] = []
            var hitCount = 0

            for performance in lastTwo {
                guard let set = matchingSetPerformance(in: performance, for: setPrescription, context: context) else { continue }

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

            events.append(makeSetEvent(context: context, setPrescription: setPrescription, changes: [makeChangeDraft(changeType: .decreaseWeight, previousValue: setPrescription.targetWeight, newValue: newWeight)], reasoning: reason))
        }

        return events
    }

    private static func shortRestPerformanceDrop(_ context: ExerciseSuggestionContext) -> [SuggestionEventDraft] {
        // Rest rule: user rests shorter than prescribed and reps drop -> suggest more rest.
        let recent = recentPerformances(context)
        guard recent.count >= 2 else { return [] }
        guard !shouldHoldSteady(context) else { return [] }

        let lastTwo = Array(recent.prefix(2))

        let restIncrement = 15

        func triggerSetIndices(in performance: ExercisePerformance) -> [Int] {
            var indices: [Int] = []
            let sets = performance.sortedSets
            let repFloorForPerformance: Int? = {
                guard let repRange = historicalOrCurrentRepRange(for: performance, context: context) else { return nil }
                switch repRange.mode {
                case .range:
                    return repRange.lower
                case .target:
                    return repRange.target
                case .notSet:
                    return nil
                }
            }()

            for idx in 1..<sets.count {
                let currentSet = sets[idx]
                guard currentSet.complete, currentSet.type == .working else { continue }

                let prevSet = sets[idx - 1]
                let effectiveRest = performance.effectiveRestSeconds(after: prevSet)
                guard effectiveRest > 0 else { continue }

                guard let setTarget = historicalOrCurrentTargetSet(for: currentSet, context: context) else { continue }
                let targetRest = setTarget.targetRest

                let actualRest = currentSet.restSeconds
                guard actualRest < targetRest - 15 else { continue }

                let previousRegular = sets[..<idx].last { $0.type == .working && $0.complete }
                let repDrop = previousRegular.map { $0.reps - currentSet.reps } ?? 0
                let belowFloor = repFloorForPerformance.map { currentSet.reps < $0 } ?? false

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

        var events: [SuggestionEventDraft] = []
        for index in currentTriggered {
            guard let set = context.performance.sortedSets[safe: index],
                  let setPrescription = targetSet(for: set) else { continue }

            let current = setPrescription.targetRest
            let newValue = current + restIncrement

            events.append(makeSetEvent(context: context, setPrescription: setPrescription, changes: [makeChangeDraft(changeType: .increaseRest, previousValue: Double(current), newValue: Double(newValue))], reasoning: reason))
        }

        return events
    }

    private static func stagnationIncreaseRest(_ context: ExerciseSuggestionContext) -> [SuggestionEventDraft] {
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

        var events: [SuggestionEventDraft] = []
        for set in progressionSets {
            // Skip drop/superset chains where effective rest is intentionally zero.
            guard set.effectiveRestSeconds > 0,
                  let setPrescription = targetSet(for: set) else { continue }
            let current = setPrescription.targetRest
            let newValue = current + increment

            events.append(makeSetEvent(context: context, setPrescription: setPrescription, changes: [makeChangeDraft(changeType: .increaseRest, previousValue: Double(current), newValue: Double(newValue))], reasoning: reason))
        }

        return events
    }

    private static func dropSetWithoutBase(_ context: ExerciseSuggestionContext) -> [SuggestionEventDraft] {
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
              let setPrescription = targetSet(for: dropSet) else {
            return []
        }

        let reason = "Drop sets work best after a heavy working set. Converting the first drop set to regular gives it a proper anchor."

        return [makeSetEvent(context: context, setPrescription: setPrescription, changes: [makeChangeDraft(changeType: .changeSetType, previousValue: Double(setPrescription.type.rawValue), newValue: Double(ExerciseSetType.working.rawValue))], reasoning: reason)]
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
            let hitTopInBoth = lastTwo.allSatisfy { performance in
                guard let performanceRepRange = historicalOrCurrentRepRange(for: performance, context: context),
                      performanceRepRange.mode == .range else { return false }
                let sets = primaryProgressionSets(from: performance, context: context)
                guard !sets.isEmpty else { return false }
                return sets.allSatisfy { $0.reps >= performanceRepRange.upper }
            }
            let overshootInBoth = lastTwo.allSatisfy { performance in
                guard let performanceRepRange = historicalOrCurrentRepRange(for: performance, context: context),
                      performanceRepRange.mode == .range else { return false }
                let sets = primaryProgressionSets(from: performance, context: context)
                guard !sets.isEmpty else { return false }
                return sets.allSatisfy { $0.reps >= performanceRepRange.upper - 1 }
            }
            guard hitTopInBoth || overshootInBoth else { return [] }
            return Set(progressionSets.map(\.index))

        case .target:
            let exceededInBoth = lastTwo.allSatisfy { performance in
                guard let performanceRepRange = historicalOrCurrentRepRange(for: performance, context: context),
                      performanceRepRange.mode == .target else { return false }
                let sets = primaryProgressionSets(from: performance, context: context)
                guard !sets.isEmpty else { return false }
                return sets.allSatisfy { $0.reps >= performanceRepRange.target + 1 }
            }
            let overshootInBoth = lastTwo.allSatisfy { performance in
                guard let performanceRepRange = historicalOrCurrentRepRange(for: performance, context: context),
                      performanceRepRange.mode == .target else { return false }
                let sets = primaryProgressionSets(from: performance, context: context)
                guard !sets.isEmpty else { return false }
                return sets.allSatisfy { $0.reps >= performanceRepRange.target }
            }
            guard exceededInBoth || overshootInBoth else { return [] }
            return Set(progressionSets.map(\.index))

        case .notSet:
            return []
        }
    }

    private static func warmupActingLikeWorkingSet(_ context: ExerciseSuggestionContext) -> [SuggestionEventDraft] {
        // Cleanup: warmup set is within 10% of top regular weight in two sessions -> suggest regular.
        let recent = recentPerformances(context)
        guard recent.count >= 2 else { return [] }

        // Evidence window: last 2 sessions.
        let lastTwo = Array(recent.prefix(2))
        var events: [SuggestionEventDraft] = []

        for setPrescription in context.prescription.sortedSets where setPrescription.type == .warmup {
            var hitCount = 0

            for performance in lastTwo {
                // Compare warmup weight to the max regular set in that session.
                let regularSets = performance.sortedSets.filter { $0.complete && $0.type == .working }
                guard let maxWeight = regularSets.map(\.weight).max(), maxWeight > 0 else { continue }
                guard let set = matchingSetPerformance(in: performance, for: setPrescription, context: context) else { continue }

                if set.weight >= maxWeight * 0.9 {
                    hitCount += 1
                }
            }

            guard hitCount >= 2 else { continue }

            let reason = "This warmup set is within 10% of your top working weight in recent sessions. Consider marking it as a regular set."
            events.append(makeSetEvent(context: context, setPrescription: setPrescription, changes: [makeChangeDraft(changeType: .changeSetType, previousValue: Double(setPrescription.type.rawValue), newValue: Double(ExerciseSetType.working.rawValue))], reasoning: reason))
        }

        return events
    }

    private static func regularActingLikeWarmup(_ context: ExerciseSuggestionContext) -> [SuggestionEventDraft] {
        // Cleanup: early regular set <70% of top regular weight in two sessions -> suggest warmup.
        let recent = recentPerformances(context)
        guard recent.count >= 2 else { return [] }

        // Evidence window: last 2 sessions.
        let lastTwo = Array(recent.prefix(2))
        var events: [SuggestionEventDraft] = []

        for setPrescription in context.prescription.sortedSets where setPrescription.type == .working && setPrescription.index <= 1 {
            var hitCount = 0

            for performance in lastTwo {
                // Compare this early regular set to the session's max regular set.
                let regularSets = performance.sortedSets.filter { $0.complete && $0.type == .working }
                guard let maxWeight = regularSets.map(\.weight).max(), maxWeight > 0 else { continue }
                guard let set = matchingSetPerformance(in: performance, for: setPrescription, context: context) else { continue }

                if set.weight < maxWeight * 0.7 {
                    hitCount += 1
                }
            }

            guard hitCount >= 2 else { continue }

            let reason = "This set is much lighter than your top working weight. Consider marking it as a warmup."
            events.append(makeSetEvent(context: context, setPrescription: setPrescription, changes: [makeChangeDraft(changeType: .changeSetType, previousValue: Double(setPrescription.type.rawValue), newValue: Double(ExerciseSetType.warmup.rawValue))], reasoning: reason))
        }

        return events
    }

    private static func isStrugglingWithTargets(context: ExerciseSuggestionContext, recent: [ExercisePerformance]) -> Bool {
        let lastThree = Array(recent.prefix(3))

        // Count how many sessions had sets below or barely hitting target
        var strugglingCount = 0

        for performance in lastThree {
            guard let performanceRepRange = historicalOrCurrentRepRange(for: performance, context: context) else { continue }
            let targetFloor: Int
            switch performanceRepRange.mode {
            case .range:
                targetFloor = performanceRepRange.lower
            case .target:
                targetFloor = performanceRepRange.target
            case .notSet:
                continue
            }
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

    private static func setTypeMismatch(_ context: ExerciseSuggestionContext) -> [SuggestionEventDraft] {
        // Cleanup: set type mismatch across two sessions -> update prescription set type.
        let recent = recentPerformances(context)
        guard recent.count >= 2 else { return [] }

        let lastTwo = Array(recent.prefix(2))
        var events: [SuggestionEventDraft] = []

        for setPrescription in context.prescription.sortedSets {
            var types: [ExerciseSetType] = []

            for performance in lastTwo {
                guard let set = matchingSetPerformance(in: performance, for: setPrescription, context: context) else { continue }
                types.append(set.type)
            }

            guard types.count == 2, let firstType = types.first, types.allSatisfy({ $0 == firstType }) else { continue }
            guard firstType != setPrescription.type else { continue }

            let reason = "You've logged this set as \(firstType.displayName) for the last two sessions. Update the prescription to match."

            events.append(makeSetEvent(context: context, setPrescription: setPrescription, changes: [makeChangeDraft(changeType: .changeSetType, previousValue: Double(setPrescription.type.rawValue), newValue: Double(firstType.rawValue))], reasoning: reason))
        }

        return events
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

    private static func repEvidence(_ context: ExerciseSuggestionContext, sessionsRequired: Int = 3) -> RepEvidence? {
        let performances = Array(recentPerformances(context).prefix(sessionsRequired))
        guard performances.count >= sessionsRequired else { return nil }

        var allReps: [Int] = []
        var representativeReps: [Int] = []

        for performance in performances {
            let progressionSets = primaryProgressionSets(from: performance, context: context).filter(\.complete)
            let reps = progressionSets.map(\.reps).filter { $0 > 0 }
            guard !reps.isEmpty else { return nil }

            allReps.append(contentsOf: reps)
            let average = Double(reps.reduce(0, +)) / Double(reps.count)
            representativeReps.append(Int(average.rounded()))
        }

        guard let minRep = allReps.min(), let maxRep = allReps.max() else { return nil }
        return RepEvidence(sessionCount: performances.count, minRep: minRep, maxRep: maxRep, representativeReps: representativeReps)
    }

    private static func normalizedRange(minRep: Int, maxRep: Int) -> (lower: Int, upper: Int)? {
        let lower = max(1, minRep)
        let upper = max(lower + 2, maxRep)
        guard upper - lower <= 4 else { return nil }
        return (lower, upper)
    }

    private static func suggestInitialRange(_ context: ExerciseSuggestionContext) -> SuggestionEventDraft? {
        let repRange = context.prescription.repRange ?? RepRangePolicy()
        guard repRange.activeMode == .notSet else { return nil }
        guard let evidence = repEvidence(context), evidence.sessionCount >= 3 else { return nil }
        guard let desiredRange = normalizedRange(minRep: evidence.minRep, maxRep: evidence.maxRep) else { return nil }

        let reason = "You've trained this exercise consistently for recent sessions without a rep range set. Add a range that matches how you already perform it."
        return makeRepRangeEvent(context: context, desiredMode: .range, desiredLower: desiredRange.lower, desiredUpper: desiredRange.upper, desiredTarget: repRange.targetReps, reasoning: reason)
    }

    private static func suggestTargetToRange(_ context: ExerciseSuggestionContext) -> SuggestionEventDraft? {
        let repRange = context.prescription.repRange ?? RepRangePolicy()
        guard repRange.activeMode == .target else { return nil }
        guard let evidence = repEvidence(context), evidence.sessionCount >= 3 else { return nil }

        let distinctRepresentativeCount = Set(evidence.representativeReps).count
        guard distinctRepresentativeCount >= 2 else { return nil }
        guard evidence.minRep >= max(1, repRange.targetReps - 1) else { return nil }
        guard evidence.maxRep >= repRange.targetReps + 1 else { return nil }
        guard let desiredRange = normalizedRange(minRep: evidence.minRep, maxRep: evidence.maxRep) else { return nil }

        let reason = "You perform this exercise across a rep band rather than one exact target. Switching to a range should better match how you train it."
        return makeRepRangeEvent(context: context, desiredMode: .range, desiredLower: desiredRange.lower, desiredUpper: desiredRange.upper, desiredTarget: repRange.targetReps, reasoning: reason)
    }

    private enum RangeShiftDirection {
        case up
        case down
    }

    private static func suggestShiftedRange(_ context: ExerciseSuggestionContext, direction: RangeShiftDirection) -> SuggestionEventDraft? {
        let repRange = context.prescription.repRange ?? RepRangePolicy()
        guard repRange.activeMode == .range else { return nil }
        guard let evidence = repEvidence(context), evidence.sessionCount >= 3 else { return nil }
        guard let desiredRange = normalizedRange(minRep: evidence.minRep, maxRep: evidence.maxRep) else { return nil }

        switch direction {
        case .up:
            guard evidence.minRep >= repRange.upperRange - 1 else { return nil }
            guard evidence.maxRep >= repRange.upperRange + 1 else { return nil }
            guard desiredRange.lower > repRange.lowerRange || desiredRange.upper > repRange.upperRange else { return nil }

            let reason = "You're consistently performing above your current rep band. Shift the range up so the prescription better matches your training."
            return makeRepRangeEvent(context: context, desiredMode: .range, desiredLower: desiredRange.lower, desiredUpper: desiredRange.upper, desiredTarget: repRange.targetReps, reasoning: reason)

        case .down:
            guard evidence.maxRep <= repRange.lowerRange + 1 else { return nil }
            guard evidence.minRep <= repRange.lowerRange - 1 else { return nil }
            guard desiredRange.lower < repRange.lowerRange || desiredRange.upper < repRange.upperRange else { return nil }

            let reason = "You're consistently performing below your current rep band. Shift the range down so the prescription better matches your training."
            return makeRepRangeEvent(context: context, desiredMode: .range, desiredLower: desiredRange.lower, desiredUpper: desiredRange.upper, desiredTarget: repRange.targetReps, reasoning: reason)
        }
    }

    private static func historicalOrCurrentRepRange(for performance: ExercisePerformance, context: ExerciseSuggestionContext) -> RepRangeSnapshot? {
        if performance.id == context.performance.id {
            return RepRangeSnapshot(policy: context.prescription.repRange)
        }

        return performance.originalTargetSnapshot?.repRange
    }

    private static func historicalOrCurrentTargetSet(for set: SetPerformance, context: ExerciseSuggestionContext) -> TargetSetContext? {
        guard let performance = set.exercise else { return nil }

        if performance.id == context.performance.id {
            guard let prescription = set.prescription else { return nil }
            return TargetSetContext(snapshot: SetTargetSnapshot(prescription: prescription))
        }

        guard let targetIndex = set.linkedTargetSetIndex else {
            return nil
        }
        guard let snapshot = performance.originalTargetSnapshot?.sets.first(where: { $0.index == targetIndex }) else {
            return nil
        }

        return TargetSetContext(snapshot: snapshot)
    }

    private static func targetSet(for set: SetPerformance) -> SetPrescription? {
        set.prescription
    }

    private static func matchingSetPerformance(in performance: ExercisePerformance, for setPrescription: SetPrescription, context: ExerciseSuggestionContext, requireComplete: Bool = true) -> SetPerformance? {
        let candidateSets = requireComplete
            ? performance.sortedSets.filter(\.complete)
            : performance.sortedSets

        if performance.id == context.performance.id {
            return candidateSets.first(where: { $0.prescription?.id == setPrescription.id })
        }

        return candidateSets.first(where: { $0.linkedTargetSetIndex == setPrescription.index })
    }

    private static func weightIncrement(for weight: Double, context: ExerciseSuggestionContext) -> Double {
        let primaryMuscle = context.prescription.musclesTargeted.first
            ?? context.performance.musclesTargeted.first
            ?? .chest
        return MetricsCalculator.weightIncrement(for: weight, primaryMuscle: primaryMuscle, equipmentType: context.prescription.equipmentType)
    }

    private static func makeChangeDraft(changeType: ChangeType, previousValue: Double, newValue: Double) -> PrescriptionChangeDraft {
        PrescriptionChangeDraft(changeType: changeType, previousValue: previousValue, newValue: newValue)
    }

    private static func makeSetEvent(context: ExerciseSuggestionContext, setPrescription: SetPrescription, changes: [PrescriptionChangeDraft], reasoning: String?) -> SuggestionEventDraft {
        SuggestionEventDraft(targetExercisePrescription: context.prescription, targetSetPrescription: setPrescription, targetSetIndex: setPrescription.index, changeReasoning: reasoning, changes: changes)
    }

    private static func makeExerciseEvent(context: ExerciseSuggestionContext, changes: [PrescriptionChangeDraft], reasoning: String?) -> SuggestionEventDraft {
        SuggestionEventDraft(targetExercisePrescription: context.prescription, changeReasoning: reasoning, changes: changes)
    }

    private static func makeRepRangeEvent(context: ExerciseSuggestionContext, desiredMode: RepRangeMode, desiredLower: Int, desiredUpper: Int, desiredTarget: Int, reasoning: String?) -> SuggestionEventDraft? {
        guard let repRange = context.prescription.repRange else { return nil }

        var changes: [PrescriptionChangeDraft] = []

        if repRange.activeMode != desiredMode {
            changes.append(makeChangeDraft(changeType: .changeRepRangeMode, previousValue: Double(repRange.activeMode.rawValue), newValue: Double(desiredMode.rawValue)))
        }
        if repRange.lowerRange != desiredLower {
            let changeType: ChangeType = desiredLower > repRange.lowerRange ? .increaseRepRangeLower : .decreaseRepRangeLower
            changes.append(makeChangeDraft(changeType: changeType, previousValue: Double(repRange.lowerRange), newValue: Double(desiredLower)))
        }
        if repRange.upperRange != desiredUpper {
            let changeType: ChangeType = desiredUpper > repRange.upperRange ? .increaseRepRangeUpper : .decreaseRepRangeUpper
            changes.append(makeChangeDraft(changeType: changeType, previousValue: Double(repRange.upperRange), newValue: Double(desiredUpper)))
        }
        if desiredMode == .target, repRange.targetReps != desiredTarget {
            let changeType: ChangeType = desiredTarget > repRange.targetReps ? .increaseRepRangeTarget : .decreaseRepRangeTarget
            changes.append(makeChangeDraft(changeType: changeType, previousValue: Double(repRange.targetReps), newValue: Double(desiredTarget)))
        }

        guard !changes.isEmpty else { return nil }
        return makeExerciseEvent(context: context, changes: changes, reasoning: reasoning)
    }

    private static func combineReasoning(_ reasons: String?...) -> String? {
        let parts = reasons
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !parts.isEmpty else { return nil }

        var uniqueParts: [String] = []
        for part in parts where !uniqueParts.contains(part) {
            uniqueParts.append(part)
        }

        return uniqueParts.joined(separator: " ")
    }
}

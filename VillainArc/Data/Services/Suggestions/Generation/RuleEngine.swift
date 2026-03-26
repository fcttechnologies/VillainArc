import Foundation

struct ExerciseSuggestionContext {
    let session: WorkoutSession
    let performance: ExercisePerformance
    let prescription: ExercisePrescription
    let history: [ExercisePerformance]
    let plan: WorkoutPlan
    let resolvedTrainingStyle: TrainingStyle
    let weightUnit: WeightUnit
    let preferredWeightChange: Double?

    init(session: WorkoutSession, performance: ExercisePerformance, prescription: ExercisePrescription, history: [ExercisePerformance], plan: WorkoutPlan, resolvedTrainingStyle: TrainingStyle, weightUnit: WeightUnit, preferredWeightChange: Double? = nil) {
        self.session = session
        self.performance = performance
        self.prescription = prescription
        self.history = history
        self.plan = plan
        self.resolvedTrainingStyle = resolvedTrainingStyle
        self.weightUnit = weightUnit
        self.preferredWeightChange = preferredWeightChange
    }
}

@MainActor struct RuleEngine {
    private struct TargetSetContext {
        let targetSetID: UUID?
        let index: Int
        let type: ExerciseSetType
        let targetWeight: Double
        let targetReps: Int
        let targetRest: Int
        let targetRPE: Int

        init(snapshot: SetTargetSnapshot) {
            targetSetID = snapshot.targetSetID
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
        let representativeReps: [Int]
        let sessionFloors: [Int]
        let sessionCeilings: [Int]

        var representativeMin: Int? { representativeReps.min() }

        var representativeMax: Int? { representativeReps.max() }

        var observedBandWidth: Int? {
            guard let floor = sessionFloors.min(), let ceiling = sessionCeilings.max() else { return nil }
            return ceiling - floor
        }
    }

    static func evaluate(context: ExerciseSuggestionContext) -> [SuggestionEventDraft] {
        var suggestions: [SuggestionEventDraft] = []

        let progression = progressionSuggestions(context)
        suggestions.append(contentsOf: progression)

        let safetyAndCleanup = safetyAndCleanupSuggestions(context)
        suggestions.append(contentsOf: safetyAndCleanup)

        let shouldHold = progression.isEmpty && safetyAndCleanup.isEmpty && shouldHoldSteady(context)
        if !shouldHold { suggestions.append(contentsOf: plateauSuggestions(context)) }

        suggestions.append(contentsOf: setTypeHygieneSuggestions(context))

        if !suggestions.contains(where: { $0.targetSetPrescription != nil && $0.category != .recovery }) { suggestions.append(contentsOf: exerciseLevelRepRangeSuggestions(context)) }

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
        suggestions.append(contentsOf: calibrateWarmupWeights(context))
        suggestions.append(contentsOf: dropSetWithoutBase(context))
        suggestions.append(contentsOf: warmupActingLikeWorkingSet(context))
        suggestions.append(contentsOf: regularActingLikeWarmup(context))
        suggestions.append(contentsOf: setTypeMismatch(context))
        return suggestions
    }

    private static func exerciseLevelRepRangeSuggestions(_ context: ExerciseSuggestionContext) -> [SuggestionEventDraft] {
        if let initialRange = suggestInitialRange(context) { return [initialRange] }
        if let targetToRange = suggestTargetToRange(context) { return [targetToRange] }
        if let shiftedRangeUp = suggestShiftedRange(context, direction: .up) { return [shiftedRangeUp] }
        if let shiftedRangeDown = suggestShiftedRange(context, direction: .down) { return [shiftedRangeDown] }
        return []
    }

    private static func immediateProgressionRange(_ context: ExerciseSuggestionContext) -> [SuggestionEventDraft] {
        // Range mode progression: if primary sets reach the top of the range now, progress immediately.
        guard supportsLoadChangeSuggestions(for: context) else { return [] }
        let repRange = context.prescription.repRange ?? RepRangePolicy()
        guard repRange.activeMode == .range else { return [] }
        let profile = progressionProfile(for: context)
        guard profile.allowsImmediateLoadProgression else { return [] }
        let lower = repRange.lowerRange
        let upper = repRange.upperRange
        let progressionSets = primaryProgressionSets(from: context.performance, context: context)
        guard !progressionSets.isEmpty else { return [] }
        guard progressionSets.allSatisfy({ $0.reps >= upper }) else { return [] }
        guard !hasStrongComparableContextMiss(in: context.performance, primarySets: progressionSets, repThreshold: upper) else { return [] }

        var events: [SuggestionEventDraft] = []
        let repsReason = resetRepsReason(lower: lower, context: context)

        let multiplier = styleIncrementMultiplier(context)

        for set in progressionSets {
            guard let setPrescription = targetSet(for: set) else { continue }
            let currentWeight = setPrescription.targetWeight
            guard currentWeight > 0 else { continue }

            // Increment is based on muscle group, weight size, and training style.
            let baseIncrement = suggestedWeightStep(for: currentWeight, context: context)
            guard let harderChange = harderLoadChange(from: currentWeight, amount: baseIncrement * multiplier, context: context) else { continue }
            let shouldResetReps = setPrescription.targetReps != lower
            let weightReason = shouldResetReps ? "You hit the top of your rep range (\(upper)) on your primary sets this session. \(harderLoadAction(context)) to keep progressing." : "You hit the top of your rep range (\(upper)) on your primary sets this session. \(harderLoadAction(context)) and keep reps at \(lower)."

            var draftChanges: [PrescriptionChangeDraft] = [makeChangeDraft(changeType: harderChange.changeType, previousValue: currentWeight, newValue: harderChange.newWeight)]

            if shouldResetReps { draftChanges.append(makeChangeDraft(changeType: .decreaseReps, previousValue: Double(setPrescription.targetReps), newValue: Double(lower))) }

            events.append(makeSetEvent(context: context, ruleID: .immediateProgressionRange, category: .performance, setPrescription: setPrescription, changes: draftChanges, reasoning: combineReasoning(weightReason, shouldResetReps ? repsReason : nil)))
        }

        return events
    }

    private static func immediateProgressionTarget(_ context: ExerciseSuggestionContext) -> [SuggestionEventDraft] {
        // Target mode progression: if primary sets exceed the target now, progress immediately.
        guard supportsLoadChangeSuggestions(for: context) else { return [] }
        let repRange = context.prescription.repRange ?? RepRangePolicy()
        guard repRange.activeMode == .target else { return [] }
        let profile = progressionProfile(for: context)
        guard profile.allowsImmediateLoadProgression else { return [] }
        let target = repRange.targetReps
        let progressionSets = primaryProgressionSets(from: context.performance, context: context)
        guard !progressionSets.isEmpty else { return [] }
        guard progressionSets.allSatisfy({ $0.reps >= target + 1 }) else { return [] }
        guard !hasStrongComparableContextMiss(in: context.performance, primarySets: progressionSets, repThreshold: target + 1) else { return [] }

        var events: [SuggestionEventDraft] = []
        let reason = "You exceeded your rep target (\(target)) on your primary sets this session. \(harderLoadAction(context)) to keep progressing."
        let multiplier = styleIncrementMultiplier(context)

        for set in progressionSets {
            guard let setPrescription = targetSet(for: set) else { continue }
            let currentWeight = setPrescription.targetWeight
            guard currentWeight > 0 else { continue }

            let baseIncrement = suggestedWeightStep(for: currentWeight, context: context)
            guard let harderChange = harderLoadChange(from: currentWeight, amount: baseIncrement * multiplier, context: context) else { continue }

            events.append(makeSetEvent(context: context, ruleID: .immediateProgressionTarget, category: .performance, setPrescription: setPrescription, changes: [makeChangeDraft(changeType: harderChange.changeType, previousValue: currentWeight, newValue: harderChange.newWeight)], reasoning: reason))
        }

        return events
    }

    private static func confirmedProgressionRange(_ context: ExerciseSuggestionContext) -> [SuggestionEventDraft] {
        guard supportsLoadChangeSuggestions(for: context) else { return [] }
        let repRange = context.prescription.repRange ?? RepRangePolicy()
        guard repRange.activeMode == .range else { return [] }
        let profile = progressionProfile(for: context)
        let lower = repRange.lowerRange
        let upper = repRange.upperRange
        let recent = recentPerformances(context)
        guard recent.count >= 2 else { return [] }
        guard !qualifiesForImmediateLoadProgression(context) else { return [] }
        let requiredReps = max(lower, upper - profile.confirmedRangeMargin)

        let lastTwo = Array(recent.prefix(2))
        let nearTopInBoth = lastTwo.allSatisfy { performance in
            guard let performanceRepRange = historicalOrCurrentRepRange(for: performance, context: context), performanceRepRange.mode == .range else { return false }
            let progressionSets = primaryProgressionSets(from: performance, context: context)
            guard !progressionSets.isEmpty else { return false }
            let threshold = max(performanceRepRange.lower, performanceRepRange.upper - profile.confirmedRangeMargin)
            guard progressionSets.allSatisfy({ $0.reps >= threshold }) else { return false }
            return !hasStrongComparableContextMiss(in: performance, primarySets: progressionSets, repThreshold: threshold)
        }
        guard nearTopInBoth else { return [] }

        let progressionSets = primaryProgressionSets(from: context.performance, context: context)
        guard !progressionSets.isEmpty else { return [] }
        guard !hasStrongComparableContextMiss(in: context.performance, primarySets: progressionSets, repThreshold: requiredReps) else { return [] }

        var events: [SuggestionEventDraft] = []
        let repsReason = resetRepsReason(lower: lower, context: context)
        let evidenceDescription = profile.confirmedRangeMargin == 0 ? "You've hit the top of your rep range (\(upper)) for two sessions on your primary sets." : "You've been at or within one rep of the top of your rep range (\(upper)) for two sessions on your primary sets."
        let multiplier = styleIncrementMultiplier(context)

        for set in progressionSets {
            guard let setPrescription = targetSet(for: set) else { continue }
            let currentWeight = setPrescription.targetWeight
            guard currentWeight > 0 else { continue }

            let baseIncrement = suggestedWeightStep(for: currentWeight, context: context)
            guard let harderChange = harderLoadChange(from: currentWeight, amount: baseIncrement * multiplier, context: context) else { continue }
            let shouldResetReps = setPrescription.targetReps != lower
            let weightReason = shouldResetReps ? "\(evidenceDescription) \(harderLoadAction(context)) to keep progressing." : "\(evidenceDescription) \(harderLoadAction(context)) and keep reps at \(lower)."

            var draftChanges: [PrescriptionChangeDraft] = [makeChangeDraft(changeType: harderChange.changeType, previousValue: currentWeight, newValue: harderChange.newWeight)]

            if shouldResetReps { draftChanges.append(makeChangeDraft(changeType: .decreaseReps, previousValue: Double(setPrescription.targetReps), newValue: Double(lower))) }

            events.append(makeSetEvent(context: context, ruleID: .confirmedProgressionRange, category: .performance, setPrescription: setPrescription, changes: draftChanges, reasoning: combineReasoning(weightReason, shouldResetReps ? repsReason : nil)))
        }

        return events
    }

    private static func confirmedProgressionTarget(_ context: ExerciseSuggestionContext) -> [SuggestionEventDraft] {
        guard supportsLoadChangeSuggestions(for: context) else { return [] }
        let repRange = context.prescription.repRange ?? RepRangePolicy()
        guard repRange.activeMode == .target else { return [] }
        let profile = progressionProfile(for: context)
        let target = repRange.targetReps
        let recent = recentPerformances(context)
        guard recent.count >= 2 else { return [] }
        guard !qualifiesForImmediateLoadProgression(context) else { return [] }
        let requiredReps = max(1, target - profile.confirmedTargetMargin)

        let lastTwo = Array(recent.prefix(2))
        let nearTargetInBoth = lastTwo.allSatisfy { performance in
            guard let performanceRepRange = historicalOrCurrentRepRange(for: performance, context: context), performanceRepRange.mode == .target else { return false }
            let progressionSets = primaryProgressionSets(from: performance, context: context)
            guard !progressionSets.isEmpty else { return false }
            let threshold = max(1, performanceRepRange.target - profile.confirmedTargetMargin)
            guard progressionSets.allSatisfy({ $0.reps >= threshold }) else { return false }
            return !hasStrongComparableContextMiss(in: performance, primarySets: progressionSets, repThreshold: threshold)
        }
        guard nearTargetInBoth else { return [] }

        let progressionSets = primaryProgressionSets(from: context.performance, context: context)
        guard !progressionSets.isEmpty else { return [] }
        guard !hasStrongComparableContextMiss(in: context.performance, primarySets: progressionSets, repThreshold: requiredReps) else { return [] }

        var events: [SuggestionEventDraft] = []
        let reason =
            profile.confirmedTargetMargin == 0 ? "You've consistently hit your target (\(target)) on your primary sets. \(harderLoadAction(context)) to keep progressing." : "You've consistently been at or within one rep of your target (\(target)) on your primary sets. \(harderLoadAction(context)) to keep progressing."
        let multiplier = styleIncrementMultiplier(context)

        for set in progressionSets {
            guard let setPrescription = targetSet(for: set) else { continue }
            let currentWeight = setPrescription.targetWeight
            guard currentWeight > 0 else { continue }

            let baseIncrement = suggestedWeightStep(for: currentWeight, context: context)
            guard let harderChange = harderLoadChange(from: currentWeight, amount: baseIncrement * multiplier, context: context) else { continue }

            events.append(makeSetEvent(context: context, ruleID: .confirmedProgressionTarget, category: .performance, setPrescription: setPrescription, changes: [makeChangeDraft(changeType: harderChange.changeType, previousValue: currentWeight, newValue: harderChange.newWeight)], reasoning: reason))
        }

        return events
    }

    private static func steadyRepIncreaseWithinRange(_ context: ExerciseSuggestionContext) -> [SuggestionEventDraft] {
        // Range mode target catch-up: if the same weight is repeated for 2 sessions and both
        // sessions beat the current target inside the range, raise the target conservatively
        // to the lower of the two observed performances.
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
        let reason = "You've consistently exceeded the current target at this weight for multiple sessions. Raise the target reps to match your recent performance."

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

                if performance.id == context.performance.id { includesCurrent = true }

                samples.append((reps: perfSet.reps, weight: perfSet.weight))
            }

            guard includesCurrent, samples.count >= 2 else { continue }

            let lastTwo = Array(samples.prefix(2))
            let sameWeight = lastTwo.allSatisfy { abs($0.weight - lastTwo[0].weight) < 0.001 }
            guard sameWeight else { continue }

            let repsBySession = lastTwo.map(\.reps)
            guard repsBySession.allSatisfy({ $0 >= lower && $0 < upper }) else { continue }
            guard repsBySession.allSatisfy({ $0 >= setPrescription.targetReps }) else { continue }

            let newReps: Int
            if repsBySession.allSatisfy({ $0 == repsBySession[0] }) {
                newReps = min(upper, repsBySession[0] + 1)
            } else {
                newReps = min(upper, repsBySession.min() ?? 0)
            }
            guard newReps >= lower else { continue }

            guard newReps > setPrescription.targetReps else { continue }

            events.append(makeSetEvent(context: context, ruleID: .steadyRepIncreaseWithinRange, category: .performance, setPrescription: setPrescription, changes: [makeChangeDraft(changeType: .increaseReps, previousValue: Double(setPrescription.targetReps), newValue: Double(newReps))], reasoning: reason))
        }

        return events
    }

    private static func largeOvershootProgression(_ context: ExerciseSuggestionContext) -> [SuggestionEventDraft] {
        // Large overshoot: one emphatically strong session is enough for a larger jump.
        guard supportsLoadChangeSuggestions(for: context) else { return [] }
        let repRange = context.prescription.repRange ?? RepRangePolicy()
        guard repRange.activeMode != .notSet else { return [] }
        let profile = progressionProfile(for: context)
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
            overshootMet = progressionSets.allSatisfy { $0.reps >= upper + profile.overshootRangeExtraReps }
        case .target:
            let target = repRange.targetReps
            overshootMet = progressionSets.allSatisfy { $0.reps >= target + profile.overshootTargetExtraReps }
        case .notSet: return []
        }

        guard overshootMet else { return [] }

        var events: [SuggestionEventDraft] = []
        let weightReason = "You significantly overshot the target on your primary sets this session. \(harderLoadAction(context)) to better match your current strength."
        let repsReason = resetRepsReason(lower: lower, context: context)

        for set in progressionSets {
            guard let setPrescription = targetSet(for: set) else { continue }
            let currentWeight = setPrescription.targetWeight
            guard currentWeight > 0 else { continue }

            // Overshoot jumps still respect exercise context. Large-jump implements and
            // heavier compounds use a more conservative multiplier than small stable moves.
            let baseIncrement = suggestedWeightStep(for: currentWeight, context: context)
            guard let harderChange = harderLoadChange(from: currentWeight, amount: baseIncrement * profile.overshootIncrementMultiplier, context: context) else { continue }

            var draftChanges: [PrescriptionChangeDraft] = [makeChangeDraft(changeType: harderChange.changeType, previousValue: currentWeight, newValue: harderChange.newWeight)]

            if shouldResetReps, setPrescription.targetReps != lower { draftChanges.append(makeChangeDraft(changeType: .decreaseReps, previousValue: Double(setPrescription.targetReps), newValue: Double(lower))) }

            events.append(makeSetEvent(context: context, ruleID: .largeOvershootProgression, category: .performance, setPrescription: setPrescription, changes: draftChanges, reasoning: combineReasoning(weightReason, shouldResetReps && setPrescription.targetReps != lower ? repsReason : nil)))
        }

        return events
    }

    private static func belowRangeWeightDecrease(_ context: ExerciseSuggestionContext) -> [SuggestionEventDraft] {
        // Range mode safety: below lower bound in 2 of last 3 -> reduce weight.
        guard supportsLoadChangeSuggestions(for: context) else { return [] }
        let repRange = context.prescription.repRange ?? RepRangePolicy()
        guard repRange.activeMode == .range else { return [] }
        let profile = progressionProfile(for: context)
        let lower = repRange.lowerRange
        let recent = recentPerformances(context)
        let requiresFullWindow = profile.belowRangeRequiredCount >= 3
        let minimumSessionCount = requiresFullWindow ? profile.belowRangeWindowSize : profile.belowRangeRequiredCount
        guard recent.count >= minimumSessionCount else { return [] }

        // Evidence window scales by lift context so heavier or more awkward loading
        // schemes require stronger repeated misses before regressing.
        let evidenceWindow = Array(recent.prefix(profile.belowRangeWindowSize))
        var belowCount = 0

        for performance in evidenceWindow {
            guard let performanceRepRange = historicalOrCurrentRepRange(for: performance, context: context), performanceRepRange.mode == .range else { continue }
            let progressionSets = primaryProgressionSets(from: performance, context: context)
            guard !progressionSets.isEmpty else { continue }

            var sessionBelow = true
            for set in progressionSets {
                guard let setTarget = historicalOrCurrentTargetSet(for: set, context: context) else {
                    sessionBelow = false
                    break
                }

                // Only count if they meaningfully attempted the prescribed load.
                let attemptedWeight = abs(set.weight - setTarget.targetWeight) <= attemptedWeightTolerance(for: setTarget.targetWeight, context: context, profile: profile)
                if !(set.reps < performanceRepRange.lower && attemptedWeight) {
                    sessionBelow = false
                    break
                }
            }

            if sessionBelow { belowCount += 1 }
        }

        guard belowCount >= profile.belowRangeRequiredCount else { return [] }

        let progressionSets = primaryProgressionSets(from: context.performance, context: context)
        guard !progressionSets.isEmpty else { return [] }

        var events: [SuggestionEventDraft] = []
        let reason: String
        if requiresFullWindow {
            reason = "You fell below the minimum rep target (\(lower)) in \(profile.belowRangeRequiredCount) of your last \(profile.belowRangeWindowSize) sessions while still attempting the prescribed load. \(easierLoadAction(context)) to stay in range."
        } else {
            reason = "You repeatedly fell below the minimum rep target (\(lower)) in recent sessions while still attempting the prescribed load. \(easierLoadAction(context)) to stay in range."
        }

        for set in progressionSets {
            guard let setPrescription = targetSet(for: set) else { continue }
            let currentWeight = setPrescription.targetWeight
            guard currentWeight > 0 else { continue }

            let decrement = suggestedWeightStep(for: currentWeight, context: context)
            guard let easierChange = easierLoadChange(from: currentWeight, amount: decrement, context: context) else { continue }

            events.append(makeSetEvent(context: context, ruleID: .belowRangeWeightDecrease, category: .performance, setPrescription: setPrescription, changes: [makeChangeDraft(changeType: easierChange.changeType, previousValue: currentWeight, newValue: easierChange.newWeight)], reasoning: reason))
        }

        return events
    }

    private static func matchActualWeight(_ context: ExerciseSuggestionContext) -> [SuggestionEventDraft] {
        // Cleanup: user consistently uses a different weight -> update prescription weight.
        guard supportsLoadChangeSuggestions(for: context) else { return [] }
        let recent = recentPerformances(context)
        let profile = progressionProfile(for: context)
        guard recent.count >= profile.matchActualWeightSessionsRequired else { return [] }

        // Avoid fighting progression rules: if a progression weight increase is already warranted, skip cleanup.
        let progressionIndices = progressionWeightChangeIndices(context)

        // Require a profile-specific number of data points so heavier lifts do not rewrite
        // prescriptions off short-term drift while stable accessories still adapt.
        let recentEvidence = Array(recent.prefix(profile.matchActualWeightSessionsRequired))
        var events: [SuggestionEventDraft] = []

        for setPrescription in context.prescription.sortedSets {
            guard setPrescription.type == .working else { continue }
            if progressionIndices.contains(setPrescription.index) { continue }

            var weights: [Double] = []
            for performance in recentEvidence {
                guard let set = matchingSetPerformance(in: performance, for: setPrescription, context: context), set.type == .working else { continue }
                weights.append(set.weight)
            }

            guard weights.count == profile.matchActualWeightSessionsRequired else { continue }

            let targetWeight = setPrescription.targetWeight
            let increment = defaultWeightIncrement(for: targetWeight, context: context)
            let deviationThreshold = max(1.25, increment * profile.meaningfulDeviationIncrementMultiplier)
            let deltas = weights.map { $0 - targetWeight }
            let allAbove = deltas.allSatisfy { $0 > deviationThreshold }
            let allBelow = deltas.allSatisfy { $0 < -deviationThreshold }
            guard allAbove || allBelow else { continue }

            // Stability filter: skip if weights are trending (spread wider than one increment
            // indicates active progression rather than a stable calibration discrepancy).
            let spread = weights.max()! - weights.min()!
            guard spread <= increment else { continue }

            let newWeight = roundSuggestedWeight(median(of: weights), context: context)
            guard abs(newWeight - targetWeight) > 0.1 else { continue }

            let changeType: ChangeType = newWeight > targetWeight ? .increaseWeight : .decreaseWeight
            let reason = matchActualWeightReason(newWeight: newWeight, sessionsRequired: profile.matchActualWeightSessionsRequired, context: context)

            events.append(makeSetEvent(context: context, ruleID: .matchActualWeight, category: .performance, setPrescription: setPrescription, changes: [makeChangeDraft(changeType: changeType, previousValue: targetWeight, newValue: newWeight)], reasoning: reason))
        }

        return events
    }

    private static func reducedWeightToHitReps(_ context: ExerciseSuggestionContext) -> [SuggestionEventDraft] {
        // Cleanup: user regularly lowers weight to hit reps -> reduce prescribed load.
        guard supportsLoadChangeSuggestions(for: context) else { return [] }
        let recent = recentPerformances(context)
        let profile = progressionProfile(for: context)
        guard recent.count >= profile.reducedWeightSessionsRequired else { return [] }

        let evidenceWindow = Array(recent.prefix(profile.reducedWeightSessionsRequired))

        var events: [SuggestionEventDraft] = []

        for setPrescription in context.prescription.sortedSets where setPrescription.type == .working {
            var supportiveWeights: [Double] = []
            var atOrBelowFloorCount = 0
            var belowFloorCount = 0
            let supportiveLoadThreshold = meaningfulReducedLoadThreshold(for: setPrescription.targetWeight, context: context, profile: profile)

            for performance in evidenceWindow {
                guard let set = matchingSetPerformance(in: performance, for: setPrescription, context: context), let setTarget = historicalOrCurrentTargetSet(for: set, context: context), let performanceRepRange = historicalOrCurrentRepRange(for: performance, context: context),
                    let floor = repFloor(for: performanceRepRange)
                else { continue }

                let supportiveLoad =
                    if context.prescription.equipmentType.usesAssistanceWeightSemantics {
                        set.weight >= (setTarget.targetWeight + supportiveLoadThreshold)
                    } else {
                        set.weight <= (setTarget.targetWeight - supportiveLoadThreshold)
                    }
                let atOrBelowFloor = set.reps <= floor
                let belowFloor = set.reps < floor

                if supportiveLoad && atOrBelowFloor {
                    atOrBelowFloorCount += 1
                    supportiveWeights.append(set.weight)
                    if belowFloor { belowFloorCount += 1 }
                }
            }

            // We only adapt the prescription downward when the athlete repeatedly reduces
            // load and at least one of those sessions still falls below the minimum target.
            // Two "reduced load + exactly at floor" sessions are acceptable execution, not
            // enough evidence that the prescription itself should be lowered.
            guard atOrBelowFloorCount >= profile.reducedWeightSessionsRequired, belowFloorCount >= 1, !supportiveWeights.isEmpty else { continue }

            let average = supportiveWeights.reduce(0, +) / Double(supportiveWeights.count)
            let newWeight = roundSuggestedWeight(average, context: context)
            let changeType: ChangeType
            let reason: String
            if context.prescription.equipmentType.usesAssistanceWeightSemantics {
                guard newWeight > setPrescription.targetWeight else { continue }
                changeType = .increaseWeight
                reason = "You've increased assistance to hit your reps in recent sessions. Update the prescription to match your current assistance setting."
            } else {
                guard newWeight < setPrescription.targetWeight else { continue }
                changeType = .decreaseWeight
                reason = "You've reduced the load to hit your reps in recent sessions. Update the prescription to match your current working weight."
            }

            events.append(makeSetEvent(context: context, ruleID: .reducedWeightToHitReps, category: .performance, setPrescription: setPrescription, changes: [makeChangeDraft(changeType: changeType, previousValue: setPrescription.targetWeight, newValue: newWeight)], reasoning: reason))
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
        let repeatedEvidence = recentRecoveryEvidence(context: context, performances: lastTwo, mode: .underRested)
        guard !repeatedEvidence.isEmpty else { return [] }

        let currentTriggered = recoveryEvidence(in: context.performance, context: context, mode: .underRested)
        let currentTargetIDs = Set(currentTriggered.keys).intersection(repeatedEvidence)
        guard !currentTargetIDs.isEmpty else { return [] }

        let reason = "Your rest periods are repeatedly shorter than prescribed and the following set falls to the floor or below. Increasing rest should help the next set stay productive."

        var events: [SuggestionEventDraft] = []
        for targetSetID in currentTargetIDs {
            guard let evidence = currentTriggered[targetSetID], let setPrescription = targetSet(for: evidence.restOwnerSet) else { continue }

            let current = setPrescription.targetRest
            let newValue = current + restIncrement

            events.append(
                makeSetEvent(context: context, ruleID: .shortRestPerformanceDrop, category: .recovery, setPrescription: setPrescription, evidenceStrength: .directTargetEvidence, changes: [makeChangeDraft(changeType: .increaseRest, previousValue: Double(current), newValue: Double(newValue))], reasoning: reason))
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
        case .topSetBackoffs, .descendingPyramid, .feederRamp, .reversePyramid, .restPauseCluster, .dropSetCluster:
            e1rms = recent.compactMap { perf in
                let progressionSets = primaryProgressionSets(from: perf, context: context)
                return progressionSets.compactMap(\.estimated1RM).max()
            }
        case .straightSets, .ascendingPyramid, .ascending, .unknown: e1rms = recent.compactMap(\.bestEstimated1RM)
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

        let repeatedRecoveryLimits = recentRecoveryEvidence(context: context, performances: Array(recent.prefix(3)), mode: .prescribedRecoveryLimited, minimumOccurrences: 2)
        guard !repeatedRecoveryLimits.isEmpty else { return [] }

        let increment = 15
        let reason = "Progress has plateaued, and the same recovery interval repeatedly leaves the following set at the floor or below even when you follow the prescribed rest. Adding rest may help recovery and performance."

        let currentEvidence = recoveryEvidence(in: context.performance, context: context, mode: .prescribedRecoveryLimited)
        let targetIDs = Set(currentEvidence.keys).intersection(repeatedRecoveryLimits)
        guard !targetIDs.isEmpty else { return [] }

        var events: [SuggestionEventDraft] = []
        for targetID in targetIDs {
            guard let evidence = currentEvidence[targetID], let setPrescription = targetSet(for: evidence.restOwnerSet) else { continue }
            let current = setPrescription.targetRest
            let newValue = current + increment

            events.append(makeSetEvent(context: context, ruleID: .stagnationIncreaseRest, category: .recovery, setPrescription: setPrescription, evidenceStrength: .heuristic, changes: [makeChangeDraft(changeType: .increaseRest, previousValue: Double(current), newValue: Double(newValue))], reasoning: reason))
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

        guard let dropSet = targetDrop, let setPrescription = targetSet(for: dropSet) else { return [] }

        let reason = "Drop sets work best after a heavy working set. Converting the first drop set to regular gives it a proper anchor."

        return [makeSetEvent(context: context, ruleID: .dropSetWithoutBase, category: .structure, setPrescription: setPrescription, changes: [makeChangeDraft(changeType: .changeSetType, previousValue: Double(setPrescription.type.rawValue), newValue: Double(ExerciseSetType.working.rawValue))], reasoning: reason)]
    }

    private static func calibrateWarmupWeights(_ context: ExerciseSuggestionContext) -> [SuggestionEventDraft] {
        guard supportsLoadChangeSuggestions(for: context) else { return [] }
        let recent = recentPerformances(context)
        guard recent.count >= 2 else { return [] }

        let evidenceWindow = Array(recent.prefix(3))
        var events: [SuggestionEventDraft] = []

        for setPrescription in context.prescription.sortedSets where setPrescription.type == .warmup {
            let increment = defaultWeightIncrement(for: max(setPrescription.targetWeight, 1), context: context)
            guard increment > 0 else { continue }

            var warmupWeights: [Double] = []
            var anchorWeights: [Double] = []
            var includesCurrent = false

            for performance in evidenceWindow {
                guard let warmupSet = matchingSetPerformance(in: performance, for: setPrescription, context: context), warmupSet.complete, warmupSet.type == .warmup, let anchorWeight = warmupAnchorWeight(in: performance, context: context) else { continue }

                if performance.id == context.performance.id { includesCurrent = true }

                warmupWeights.append(warmupSet.weight)
                anchorWeights.append(anchorWeight)
            }

            guard includesCurrent, warmupWeights.count >= 2, anchorWeights.count == warmupWeights.count else { continue }

            let currentTargetWeight = setPrescription.targetWeight
            let ratioSamples = zip(warmupWeights, anchorWeights)
                .map { weight, anchor in
                    guard anchor > 0 else { return 0.0 }
                    return weight / anchor
                }

            let aboveTargetCount = warmupWeights.filter { $0 >= currentTargetWeight + increment * 0.8 }.count
            guard aboveTargetCount >= 2 else { continue }

            guard let minRatio = ratioSamples.min(), let maxRatio = ratioSamples.max(), maxRatio - minRatio <= 0.15 else { continue }

            let suggestedWeight = roundSuggestedWeight(median(of: warmupWeights), context: context)
            guard suggestedWeight >= currentTargetWeight + increment * 0.8 else { continue }

            let currentAnchor = anchorWeights.first ?? 0
            guard currentAnchor > 0, suggestedWeight < currentAnchor * 0.9 else { continue }

            let reason = "You've consistently used a heavier warmup as your working sets have climbed. Increase this warmup weight so it better bridges into your main sets."
            events.append(makeSetEvent(context: context, ruleID: .calibrateWarmupWeights, category: .warmupCalibration, setPrescription: setPrescription, changes: [makeChangeDraft(changeType: .increaseWeight, previousValue: currentTargetWeight, newValue: suggestedWeight)], reasoning: reason))
        }

        return events
    }

    private static func progressionWeightChangeIndices(_ context: ExerciseSuggestionContext) -> Set<Int> {
        // Returns the set indices that would receive a progression-based weight change.
        guard supportsLoadChangeSuggestions(for: context) else { return [] }
        let recent = recentPerformances(context)
        guard recent.count >= 2 else { return [] }

        let lastTwo = Array(recent.prefix(2))
        let repRange = context.prescription.repRange ?? RepRangePolicy()
        let profile = progressionProfile(for: context)
        guard repRange.activeMode != .notSet else { return [] }
        let progressionSets = primaryProgressionSets(from: context.performance, context: context)
        guard !progressionSets.isEmpty else { return [] }

        switch repRange.activeMode {
        case .range:
            let warrantedInBoth = lastTwo.allSatisfy { performance in
                guard let performanceRepRange = historicalOrCurrentRepRange(for: performance, context: context), performanceRepRange.mode == .range else { return false }
                let sets = primaryProgressionSets(from: performance, context: context)
                guard !sets.isEmpty else { return false }
                let threshold = max(performanceRepRange.lower, performanceRepRange.upper - profile.confirmedRangeMargin)
                return sets.allSatisfy { $0.reps >= threshold }
            }
            guard warrantedInBoth else { return [] }
            return Set(progressionSets.map(\.index))

        case .target:
            let warrantedInBoth = lastTwo.allSatisfy { performance in
                guard let performanceRepRange = historicalOrCurrentRepRange(for: performance, context: context), performanceRepRange.mode == .target else { return false }
                let sets = primaryProgressionSets(from: performance, context: context)
                guard !sets.isEmpty else { return false }
                let threshold = max(1, performanceRepRange.target - profile.confirmedTargetMargin)
                return sets.allSatisfy { $0.reps >= threshold }
            }
            guard warrantedInBoth else { return [] }
            return Set(progressionSets.map(\.index))

        case .notSet: return []
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
                guard let maxWeight = regularSets.map(\.weight).max(), maxWeight > 0, let maxWorkingEstimated1RM = regularSets.compactMap(\.estimated1RM).max(), maxWorkingEstimated1RM > 0 else { continue }
                guard let set = matchingSetPerformance(in: performance, for: setPrescription, context: context) else { continue }

                // A heavy feeder warmup in an ascending pyramid can legitimately sit near the
                // top working weight. Only reclassify it when it also behaves like working
                // effort, not just when the load is heavy.
                let warmupLooksWorking = (set.estimated1RM ?? 0) >= maxWorkingEstimated1RM * 0.95

                if set.weight >= maxWeight * 0.9 && warmupLooksWorking { hitCount += 1 }
            }

            guard hitCount >= 2 else { continue }

            let reason = "This warmup set is within 10% of your top working weight in recent sessions. Consider marking it as a regular set."
            events.append(
                makeSetEvent(context: context, ruleID: .warmupActingLikeWorkingSet, category: .structure, setPrescription: setPrescription, changes: [makeChangeDraft(changeType: .changeSetType, previousValue: Double(setPrescription.type.rawValue), newValue: Double(ExerciseSetType.working.rawValue))], reasoning: reason)
            )
        }

        return events
    }

    private static func regularActingLikeWarmup(_ context: ExerciseSuggestionContext) -> [SuggestionEventDraft] {
        // Cleanup: only demote an early working set when it consistently behaves like an isolated
        // light outlier before the real working cluster, not merely because the session ramps.
        switch context.resolvedTrainingStyle {
        case .ascending, .ascendingPyramid, .topSetBackoffs, .feederRamp: return []
        case .straightSets, .descendingPyramid, .reversePyramid, .restPauseCluster, .dropSetCluster, .unknown: break
        }

        let recent = recentPerformances(context)
        guard recent.count >= 2 else { return [] }

        // Evidence window: last 2 sessions.
        let lastTwo = Array(recent.prefix(2))
        var events: [SuggestionEventDraft] = []

        for setPrescription in context.prescription.sortedSets where setPrescription.type == .working && setPrescription.index <= 1 {
            var hitCount = 0

            for performance in lastTwo {
                let regularSets = performance.sortedSets.filter { $0.complete && $0.type == .working }
                guard let maxWeight = regularSets.map(\.weight).max(), maxWeight > 0 else { continue }
                guard let maxWorkingEstimated1RM = regularSets.compactMap(\.estimated1RM).max(), maxWorkingEstimated1RM > 0 else { continue }
                guard let set = matchingSetPerformance(in: performance, for: setPrescription, context: context) else { continue }
                guard set.weight < maxWeight * 0.7 else { continue }
                guard isolatedLightSetLeadsIntoWorkingCluster(set: set, in: regularSets, maxWeight: maxWeight) else { continue }

                let setEstimated1RM = set.estimated1RM ?? 0
                guard setEstimated1RM < maxWorkingEstimated1RM * 0.8 else { continue }

                hitCount += 1
            }

            guard hitCount >= 2 else { continue }

            let reason = "This early set consistently behaves like a light feeder before your true working cluster. Consider marking it as a warmup."
            events.append(
                makeSetEvent(context: context, ruleID: .regularActingLikeWarmup, category: .structure, setPrescription: setPrescription, changes: [makeChangeDraft(changeType: .changeSetType, previousValue: Double(setPrescription.type.rawValue), newValue: Double(ExerciseSetType.warmup.rawValue))], reasoning: reason))
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
            case .range: targetFloor = performanceRepRange.lower
            case .target: targetFloor = performanceRepRange.target
            case .notSet: continue
            }
            let progressionSets = primaryProgressionSets(from: performance, context: context)
            guard !progressionSets.isEmpty else { continue }

            // Check if any progression sets were below floor
            let anyBelowFloor = progressionSets.contains { $0.reps < targetFloor }

            // Treat "at the floor" as struggling, but do not penalize floor+1 in range mode.
            // That rep count is still normal in-range execution during consolidation phases.
            let barelyHitting = progressionSets.allSatisfy { $0.reps <= targetFloor }

            if anyBelowFloor || barelyHitting { strugglingCount += 1 }
        }

        // Require at least 2 of 3 sessions showing struggle
        return strugglingCount >= 2
    }

    private static func setTypeMismatch(_ context: ExerciseSuggestionContext) -> [SuggestionEventDraft] {
        // Cleanup: set type mismatch across two sessions -> update prescription set type.
        let recent = recentPerformances(context)
        guard recent.count >= 2 else { return [] }

        let evidenceWindow = Array(recent.prefix(3))
        var events: [SuggestionEventDraft] = []

        for setPrescription in context.prescription.sortedSets {
            var types: [ExerciseSetType] = []

            for performance in evidenceWindow {
                guard let set = matchingSetPerformance(in: performance, for: setPrescription, context: context) else { continue }
                types.append(set.type)
            }

            let requiredEvidence = requiredSetTypeMismatchEvidence(from: setPrescription.type, toLoggedTypeInRecentSessions: types.first)
            guard types.count >= requiredEvidence else { continue }

            let recentTypes = Array(types.prefix(requiredEvidence))
            guard let firstType = recentTypes.first, recentTypes.allSatisfy({ $0 == firstType }) else { continue }
            guard firstType != setPrescription.type else { continue }

            let reason = "You've logged this set as \(firstType.displayName) for the last \(requiredEvidence) sessions. Update the prescription to match."

            events.append(makeSetEvent(context: context, ruleID: .setTypeMismatch, category: .structure, setPrescription: setPrescription, changes: [makeChangeDraft(changeType: .changeSetType, previousValue: Double(setPrescription.type.rawValue), newValue: Double(firstType.rawValue))], reasoning: reason))
        }

        return events
    }

    private static func requiredSetTypeMismatchEvidence(from prescribedType: ExerciseSetType, toLoggedTypeInRecentSessions loggedType: ExerciseSetType?) -> Int {
        guard let loggedType else { return 2 }
        return prescribedType == .dropSet || loggedType == .dropSet ? 3 : 2
    }

    private enum RecoveryEvidenceMode {
        case underRested
        case prescribedRecoveryLimited
    }

    private struct RecoveryEvidence {
        let restOwnerSet: SetPerformance
        let laggingSet: SetPerformance
        let targetRest: Int
        let actualRest: Int
        let repDrop: Int
        let floor: Int
        let belowFloor: Bool
        let atFloor: Bool
    }

    private static func primaryProgressionSets(from performance: ExercisePerformance, context: ExerciseSuggestionContext) -> [SetPerformance] { MetricsCalculator.selectProgressionSets(from: performance, overrideStyle: context.resolvedTrainingStyle) }

    private static func hasStrongComparableContextMiss(in performance: ExercisePerformance, primarySets: [SetPerformance], repThreshold: Int) -> Bool {
        guard !primarySets.isEmpty, repThreshold > 0 else { return false }

        let contextualSets = performance.sortedSets.filter { set in set.complete && set.type == .working && !MetricsCalculator.isPlanAnchored(set) }
        guard !contextualSets.isEmpty else { return false }

        let maxPrimaryWeight = primarySets.map(\.weight).max() ?? 0
        guard maxPrimaryWeight > 0 else { return false }

        let comparableWeightFloor = maxPrimaryWeight * 0.9
        let primaryMinReps = primarySets.map(\.reps).min() ?? repThreshold

        return contextualSets.contains { set in
            guard set.weight >= comparableWeightFloor else { return false }
            let clearlyBelowTarget = set.reps <= repThreshold - 2
            let clearlyBelowPrimaryCluster = set.reps <= primaryMinReps - 3
            return clearlyBelowTarget || clearlyBelowPrimaryCluster
        }
    }

    private static func qualifiesForImmediateLoadProgression(_ context: ExerciseSuggestionContext) -> Bool {
        let repRange = context.prescription.repRange ?? RepRangePolicy()
        let profile = progressionProfile(for: context)
        guard profile.allowsImmediateLoadProgression else { return false }
        let progressionSets = primaryProgressionSets(from: context.performance, context: context)
        guard !progressionSets.isEmpty else { return false }

        switch repRange.activeMode {
        case .range:
            guard progressionSets.allSatisfy({ $0.reps >= repRange.upperRange }) else { return false }
            return !hasStrongComparableContextMiss(in: context.performance, primarySets: progressionSets, repThreshold: repRange.upperRange)
        case .target:
            let threshold = repRange.targetReps + 1
            guard progressionSets.allSatisfy({ $0.reps >= threshold }) else { return false }
            return !hasStrongComparableContextMiss(in: context.performance, primarySets: progressionSets, repThreshold: threshold)
        case .notSet: return false
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
            guard allInRange && closeToProgression else { return false }
            return !hasStrongComparableContextMiss(in: context.performance, primarySets: progressionSets, repThreshold: max(lower, upper - 1))
        case .target:
            let target = repRange.targetReps
            let onTrack = progressionSets.allSatisfy { $0.reps >= target - 1 }
            let closeToProgression = progressionSets.allSatisfy { $0.reps >= target }
            guard onTrack && closeToProgression else { return false }
            return !hasStrongComparableContextMiss(in: context.performance, primarySets: progressionSets, repThreshold: target)
        case .notSet: return false
        }
    }

    /// Returns a multiplier for weight increments based on training style.
    /// Top-set styles can handle slightly larger jumps because backoff volume provides recovery stimulus.
    private static func styleIncrementMultiplier(_ context: ExerciseSuggestionContext) -> Double {
        switch context.resolvedTrainingStyle {
        case .topSetBackoffs: return 1.25
        case .reversePyramid: return 1.25
        default: return 1.0
        }
    }

    private static func repFloor(for repRange: RepRangeSnapshot) -> Int? {
        switch repRange.mode {
        case .range: return repRange.lower
        case .target: return repRange.target
        case .notSet: return nil
        }
    }

    private static func recoveryEvidence(in performance: ExercisePerformance, context: ExerciseSuggestionContext, mode: RecoveryEvidenceMode) -> [UUID: RecoveryEvidence] {
        let sets = performance.sortedSets
        guard let repRange = historicalOrCurrentRepRange(for: performance, context: context), let floor = repFloor(for: repRange) else { return [:] }

        var evidenceByTargetID: [UUID: RecoveryEvidence] = [:]

        for idx in 1..<sets.count {
            let currentSet = sets[idx]
            guard currentSet.complete, currentSet.type == .working else { continue }

            let prevSet = sets[idx - 1]
            let effectiveRest = performance.effectiveRestSeconds(after: prevSet)
            guard effectiveRest > 0 else { continue }

            guard let restOwnerTarget = historicalOrCurrentTargetSet(for: prevSet, context: context), let targetSetID = restOwnerTarget.targetSetID else { continue }

            let targetRest = restOwnerTarget.targetRest
            let restDelta = targetRest - effectiveRest

            switch mode {
            case .underRested: guard restDelta >= 15 else { continue }
            case .prescribedRecoveryLimited: guard abs(restDelta) <= 15 else { continue }
            }

            let previousRegular = sets[..<idx].last { $0.type == .working && $0.complete }
            let repDrop = previousRegular.map { $0.reps - currentSet.reps } ?? 0
            let belowFloor = currentSet.reps < floor
            let atFloor = currentSet.reps == floor
            let clearlyFatigueLimited = belowFloor || (atFloor && repDrop >= 4)
            guard clearlyFatigueLimited else { continue }

            evidenceByTargetID[targetSetID] = RecoveryEvidence(restOwnerSet: prevSet, laggingSet: currentSet, targetRest: targetRest, actualRest: effectiveRest, repDrop: repDrop, floor: floor, belowFloor: belowFloor, atFloor: atFloor)
        }

        return evidenceByTargetID
    }

    private static func recentRecoveryEvidence(context: ExerciseSuggestionContext, performances: [ExercisePerformance], mode: RecoveryEvidenceMode, minimumOccurrences: Int? = nil) -> Set<UUID> {
        let evidenceMaps = performances.map { recoveryEvidence(in: $0, context: context, mode: mode) }
        guard !evidenceMaps.isEmpty else { return [] }

        if let minimumOccurrences {
            let counts = evidenceMaps.reduce(into: [UUID: Int]()) { partialResult, evidence in for targetID in evidence.keys { partialResult[targetID, default: 0] += 1 } }

            return Set(counts.compactMap { targetID, count in count >= minimumOccurrences ? targetID : nil })
        }

        guard evidenceMaps.allSatisfy({ !$0.isEmpty }) else { return [] }

        var overlappingTargetIDs = Set(evidenceMaps[0].keys)
        for evidence in evidenceMaps.dropFirst() { overlappingTargetIDs.formIntersection(evidence.keys) }
        return overlappingTargetIDs
    }

    private static func recentPerformances(_ context: ExerciseSuggestionContext) -> [ExercisePerformance] {
        // Include the current session at the front of the historical list.
        [context.performance] + context.history
    }

    private static func repEvidence(_ context: ExerciseSuggestionContext, sessionsRequired: Int = 3) -> RepEvidence? {
        let performances = Array(recentPerformances(context).prefix(sessionsRequired))
        guard performances.count >= sessionsRequired else { return nil }

        var representativeReps: [Int] = []
        var sessionFloors: [Int] = []
        var sessionCeilings: [Int] = []

        for performance in performances {
            let progressionSets = primaryProgressionSets(from: performance, context: context).filter(\.complete)
            let reps = progressionSets.map(\.reps).filter { $0 > 0 }
            guard !reps.isEmpty else { return nil }

            let sortedReps = reps.sorted()
            representativeReps.append(lowerMedian(of: sortedReps))
            sessionFloors.append(sortedReps.first ?? 0)
            sessionCeilings.append(sortedReps.last ?? 0)
        }

        return RepEvidence(sessionCount: performances.count, representativeReps: representativeReps, sessionFloors: sessionFloors, sessionCeilings: sessionCeilings)
    }

    private static func lowerMedian(of sortedValues: [Int]) -> Int {
        guard !sortedValues.isEmpty else { return 0 }
        let index = (sortedValues.count - 1) / 2
        return sortedValues[index]
    }

    private static func median(of values: [Double]) -> Double {
        let sortedValues = values.sorted()
        guard !sortedValues.isEmpty else { return 0 }
        let index = (sortedValues.count - 1) / 2
        return sortedValues[index]
    }

    private static func normalizedRange(evidence: RepEvidence) -> (lower: Int, upper: Int)? {
        guard let representativeMin = evidence.representativeMin, let representativeMax = evidence.representativeMax, let robustFloor = evidence.sessionFloors.sorted()[safe: evidence.sessionFloors.count / 2], let robustCeiling = evidence.sessionCeilings.sorted()[safe: evidence.sessionCeilings.count / 2] else {
            return nil
        }

        let lower = max(1, min(representativeMin, robustFloor))
        let upper = max(lower + 2, max(representativeMax, robustCeiling))
        guard upper - lower <= 4 else { return nil }
        return (lower, upper)
    }

    private static func suggestInitialRange(_ context: ExerciseSuggestionContext) -> SuggestionEventDraft? {
        let repRange = context.prescription.repRange ?? RepRangePolicy()
        guard repRange.activeMode == .notSet else { return nil }
        guard let evidence = repEvidence(context), evidence.sessionCount >= 3 else { return nil }
        guard let desiredRange = normalizedRange(evidence: evidence) else { return nil }

        let reason = "You've trained this exercise consistently for recent sessions without a rep range set. Add a range that matches how you already perform it."
        return makeRepRangeEvent(context: context, ruleID: .suggestInitialRange, category: .repRangeConfiguration, desiredMode: .range, desiredLower: desiredRange.lower, desiredUpper: desiredRange.upper, desiredTarget: repRange.targetReps, reasoning: reason)
    }

    private static func suggestTargetToRange(_ context: ExerciseSuggestionContext) -> SuggestionEventDraft? {
        let repRange = context.prescription.repRange ?? RepRangePolicy()
        guard repRange.activeMode == .target else { return nil }
        guard let evidence = repEvidence(context), evidence.sessionCount >= 3 else { return nil }
        guard let desiredRange = normalizedRange(evidence: evidence), let representativeMin = evidence.representativeMin, let representativeMax = evidence.representativeMax, let observedBandWidth = evidence.observedBandWidth else { return nil }
        guard observedBandWidth >= 2 || representativeMin != representativeMax else { return nil }
        guard desiredRange.lower >= max(1, repRange.targetReps - 1) else { return nil }
        guard desiredRange.upper >= repRange.targetReps + 1 else { return nil }

        let reason = "You perform this exercise across a rep band rather than one exact target. Switching to a range should better match how you train it."
        return makeRepRangeEvent(context: context, ruleID: .suggestTargetToRange, category: .repRangeConfiguration, desiredMode: .range, desiredLower: desiredRange.lower, desiredUpper: desiredRange.upper, desiredTarget: repRange.targetReps, reasoning: reason)
    }

    private enum RangeShiftDirection {
        case up
        case down
    }

    private static func suggestShiftedRange(_ context: ExerciseSuggestionContext, direction: RangeShiftDirection) -> SuggestionEventDraft? {
        let repRange = context.prescription.repRange ?? RepRangePolicy()
        guard repRange.activeMode == .range else { return nil }
        guard let evidence = repEvidence(context), evidence.sessionCount >= 3 else { return nil }
        guard let desiredRange = normalizedRange(evidence: evidence), let representativeMin = evidence.representativeMin, let representativeMax = evidence.representativeMax else { return nil }

        switch direction {
        case .up:
            guard representativeMin >= repRange.upperRange - 1 else { return nil }
            guard representativeMax >= repRange.upperRange + 1 else { return nil }
            guard desiredRange.lower > repRange.lowerRange || desiredRange.upper > repRange.upperRange else { return nil }

            let reason = "You're consistently performing above your current rep band. Shift the range up so the prescription better matches your training."
            return makeRepRangeEvent(context: context, ruleID: .suggestShiftedRangeUp, category: .repRangeConfiguration, desiredMode: .range, desiredLower: desiredRange.lower, desiredUpper: desiredRange.upper, desiredTarget: repRange.targetReps, reasoning: reason)

        case .down:
            guard representativeMax <= repRange.lowerRange + 1 else { return nil }
            guard representativeMin <= repRange.lowerRange - 1 else { return nil }
            guard desiredRange.lower < repRange.lowerRange || desiredRange.upper < repRange.upperRange else { return nil }

            let reason = "You're consistently performing below your current rep band. Shift the range down so the prescription better matches your training."
            return makeRepRangeEvent(context: context, ruleID: .suggestShiftedRangeDown, category: .repRangeConfiguration, desiredMode: .range, desiredLower: desiredRange.lower, desiredUpper: desiredRange.upper, desiredTarget: repRange.targetReps, reasoning: reason)
        }
    }

    private static func historicalOrCurrentRepRange(for performance: ExercisePerformance, context: ExerciseSuggestionContext) -> RepRangeSnapshot? {
        if performance.id == context.performance.id { return RepRangeSnapshot(policy: context.prescription.repRange) }

        return performance.originalTargetSnapshot?.repRange
    }

    private static func historicalOrCurrentTargetSet(for set: SetPerformance, context: ExerciseSuggestionContext) -> TargetSetContext? {
        guard let performance = set.exercise else { return nil }

        if performance.id == context.performance.id {
            guard let prescription = set.prescription else { return nil }
            return TargetSetContext(snapshot: SetTargetSnapshot(prescription: prescription))
        }

        guard let targetSetID = set.originalTargetSetID else { return nil }
        guard let snapshot = performance.originalTargetSnapshot?.sets.first(where: { $0.targetSetID == targetSetID }) else { return nil }

        return TargetSetContext(snapshot: snapshot)
    }

    private static func targetSet(for set: SetPerformance) -> SetPrescription? { set.prescription }

    private static func warmupAnchorWeight(in performance: ExercisePerformance, context: ExerciseSuggestionContext) -> Double? {
        let progressionSets = primaryProgressionSets(from: performance, context: context).filter { $0.complete && $0.type == .working }
        if let anchor = progressionSets.map(\.weight).max(), anchor > 0 { return anchor }

        let workingSets = performance.sortedSets.filter { $0.complete && $0.type == .working }
        guard let fallback = workingSets.map(\.weight).max(), fallback > 0 else { return nil }
        return fallback
    }

    private static func isolatedLightSetLeadsIntoWorkingCluster(set: SetPerformance, in regularSets: [SetPerformance], maxWeight: Double) -> Bool {
        let orderedWorkingSets = regularSets.sorted { $0.index < $1.index }
        let laterWorkingSets = orderedWorkingSets.filter { $0.index > set.index }
        guard laterWorkingSets.count >= 2 else { return false }

        let heavyThreshold = maxWeight * 0.9
        let heavyLaterSets = laterWorkingSets.filter { $0.weight >= heavyThreshold }
        guard heavyLaterSets.count >= 2 else { return false }

        let allLaterSetsAreClustered = laterWorkingSets.allSatisfy { $0.weight >= heavyThreshold }
        guard allLaterSetsAreClustered else { return false }

        let firstLaterWeight = laterWorkingSets.first?.weight ?? 0
        let clusterAverage = laterWorkingSets.map(\.weight).reduce(0, +) / Double(laterWorkingSets.count)

        return firstLaterWeight >= set.weight * 1.2 && clusterAverage >= maxWeight * 0.92
    }

    private static func matchingSetPerformance(in performance: ExercisePerformance, for setPrescription: SetPrescription, context: ExerciseSuggestionContext, requireComplete: Bool = true) -> SetPerformance? {
        let candidateSets = requireComplete ? performance.sortedSets.filter(\.complete) : performance.sortedSets

        if performance.id == context.performance.id { return candidateSets.first(where: { $0.prescription?.id == setPrescription.id }) }

        return candidateSets.first(where: { $0.originalTargetSetID == setPrescription.id })
    }

    private static func defaultWeightIncrement(for weight: Double, context: ExerciseSuggestionContext) -> Double {
        let primaryMuscle = context.prescription.musclesTargeted.first ?? context.performance.musclesTargeted.first ?? .chest
        return MetricsCalculator.weightIncrement(for: weight, primaryMuscle: primaryMuscle, equipmentType: context.prescription.equipmentType, catalogID: context.prescription.catalogID)
    }

    private static func suggestedWeightStep(for weight: Double, context: ExerciseSuggestionContext) -> Double {
        if let preferredWeightChange = context.preferredWeightChange, preferredWeightChange > 0 { return preferredWeightChange }
        return defaultWeightIncrement(for: weight, context: context)
    }

    private static func supportsLoadChangeSuggestions(for context: ExerciseSuggestionContext) -> Bool {
        guard context.prescription.equipmentType == .bodyweight else { return true }

        // Pure bodyweight movements should still progress through reps/range first.
        // Once the athlete explicitly logs external load, allow normal load progression.
        if context.prescription.sortedSets.contains(where: { $0.targetWeight > 0 }) { return true }

        return primaryProgressionSets(from: context.performance, context: context).contains { $0.weight > 0 }
    }

    private static func progressionProfile(for context: ExerciseSuggestionContext) -> ProgressionProfile {
        let primaryMuscle = context.prescription.musclesTargeted.first ?? context.performance.musclesTargeted.first ?? .chest
        return MetricsCalculator.progressionProfile(primaryMuscle: primaryMuscle, equipmentType: context.prescription.equipmentType, catalogID: context.prescription.catalogID)
    }

    private static func attemptedWeightTolerance(for targetWeight: Double, context: ExerciseSuggestionContext, profile: ProgressionProfile) -> Double {
        let increment = defaultWeightIncrement(for: targetWeight, context: context)
        return max(1.25, increment * profile.attemptedWeightToleranceIncrementMultiplier)
    }

    private static func meaningfulReducedLoadThreshold(for targetWeight: Double, context: ExerciseSuggestionContext, profile: ProgressionProfile) -> Double {
        let increment = defaultWeightIncrement(for: targetWeight, context: context)
        return max(1.25, increment * profile.reducedLoadIncrementMultiplier)
    }

    private static func roundSuggestedWeight(_ value: Double, context: ExerciseSuggestionContext) -> Double { return MetricsCalculator.roundSuggestedWeight(value, equipmentType: context.prescription.equipmentType, weightUnit: context.weightUnit) }

    private static func harderLoadChange(from currentWeight: Double, amount: Double, context: ExerciseSuggestionContext) -> (changeType: ChangeType, newWeight: Double)? {
        guard amount > 0 else { return nil }

        let effectiveAmount = roundedPreferredWeightAmount(for: amount, context: context)
        let newWeight =
            if context.prescription.equipmentType.usesAssistanceWeightSemantics {
                adjustedWeight(from: currentWeight, delta: -effectiveAmount, context: context)
            } else {
                adjustedWeight(from: currentWeight, delta: effectiveAmount, context: context)
            }

        guard abs(newWeight - currentWeight) > 0.001 else { return nil }
        let changeType: ChangeType = context.prescription.equipmentType.usesAssistanceWeightSemantics ? .decreaseWeight : .increaseWeight
        return (changeType, newWeight)
    }

    private static func easierLoadChange(from currentWeight: Double, amount: Double, context: ExerciseSuggestionContext) -> (changeType: ChangeType, newWeight: Double)? {
        guard amount > 0 else { return nil }

        let effectiveAmount = roundedPreferredWeightAmount(for: amount, context: context)
        let newWeight =
            if context.prescription.equipmentType.usesAssistanceWeightSemantics {
                adjustedWeight(from: currentWeight, delta: effectiveAmount, context: context)
            } else {
                adjustedWeight(from: currentWeight, delta: -effectiveAmount, context: context)
            }

        guard abs(newWeight - currentWeight) > 0.001 else { return nil }
        let changeType: ChangeType = context.prescription.equipmentType.usesAssistanceWeightSemantics ? .increaseWeight : .decreaseWeight
        return (changeType, newWeight)
    }

    private static func harderLoadAction(_ context: ExerciseSuggestionContext) -> String { context.prescription.equipmentType.usesAssistanceWeightSemantics ? "Decrease assistance" : "Increase weight" }

    private static func easierLoadAction(_ context: ExerciseSuggestionContext) -> String { context.prescription.equipmentType.usesAssistanceWeightSemantics ? "Increase assistance slightly" : "Reduce weight slightly" }

    private static func resetRepsReason(lower: Int, context: ExerciseSuggestionContext) -> String { context.prescription.equipmentType.usesAssistanceWeightSemantics ? "Reset reps to \(lower) to account for the harder assistance setting." : "Reset reps to \(lower) to account for the added weight." }

    private static func matchActualWeightReason(newWeight: Double, sessionsRequired: Int, context: ExerciseSuggestionContext) -> String {
        if context.prescription.equipmentType.usesAssistanceWeightSemantics { return "You've used about \(context.weightUnit.display(newWeight)) of assistance for \(sessionsRequired) sessions. Update the prescription to match your current assistance setting." }
        if context.prescription.equipmentType == .dumbbells || context.prescription.equipmentType == .cables { return "You've used about \(context.weightUnit.display(newWeight)) per side for \(sessionsRequired) sessions. Update the prescription to match your working weight." }
        return "You've used about \(context.weightUnit.display(newWeight)) for \(sessionsRequired) sessions. Update the prescription to match your working weight."
    }

    private static func roundedPreferredWeightAmount(for amount: Double, context: ExerciseSuggestionContext) -> Double {
        guard let preferredWeightChange = context.preferredWeightChange, preferredWeightChange > 0 else { return amount }
        let multiple = max(1, Int(ceil(amount / preferredWeightChange)))
        return preferredWeightChange * Double(multiple)
    }

    private static func adjustedWeight(from currentWeight: Double, delta: Double, context: ExerciseSuggestionContext) -> Double {
        guard let preferredWeightChange = context.preferredWeightChange, preferredWeightChange > 0 else { return roundSuggestedWeight(max(0, currentWeight + delta), context: context) }
        return max(0, currentWeight + delta)
    }

    private static func makeChangeDraft(changeType: ChangeType, previousValue: Double, newValue: Double) -> PrescriptionChangeDraft { PrescriptionChangeDraft(changeType: changeType, previousValue: previousValue, newValue: newValue) }

    private static func makeSetEvent(context: ExerciseSuggestionContext, ruleID: SuggestionRule, category: SuggestionCategory, setPrescription: SetPrescription, evidenceStrength: SuggestionEvidenceStrength = .pattern, changes: [PrescriptionChangeDraft], reasoning: String?) -> SuggestionEventDraft {
        SuggestionEventDraft(category: category, targetExercisePrescription: context.prescription, targetSetPrescription: setPrescription, triggerTargetSetID: setPrescription.id, rule: ruleID, evidenceStrength: evidenceStrength, changeReasoning: reasoning, changes: changes)
    }

    private static func makeExerciseEvent(context: ExerciseSuggestionContext, ruleID: SuggestionRule, category: SuggestionCategory, evidenceStrength: SuggestionEvidenceStrength = .pattern, changes: [PrescriptionChangeDraft], reasoning: String?) -> SuggestionEventDraft {
        SuggestionEventDraft(category: category, targetExercisePrescription: context.prescription, rule: ruleID, evidenceStrength: evidenceStrength, changeReasoning: reasoning, changes: changes)
    }

    private static func makeRepRangeEvent(context: ExerciseSuggestionContext, ruleID: SuggestionRule, category: SuggestionCategory, desiredMode: RepRangeMode, desiredLower: Int, desiredUpper: Int, desiredTarget: Int, reasoning: String?) -> SuggestionEventDraft? {
        guard let repRange = context.prescription.repRange else { return nil }

        var changes: [PrescriptionChangeDraft] = []

        if repRange.activeMode != desiredMode { changes.append(makeChangeDraft(changeType: .changeRepRangeMode, previousValue: Double(repRange.activeMode.rawValue), newValue: Double(desiredMode.rawValue))) }
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
        return makeExerciseEvent(context: context, ruleID: ruleID, category: category, changes: changes, reasoning: reasoning)
    }

    private static func combineReasoning(_ reasons: String?...) -> String? {
        let parts = reasons.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }

        guard !parts.isEmpty else { return nil }

        var uniqueParts: [String] = []
        for part in parts where !uniqueParts.contains(part) { uniqueParts.append(part) }

        return uniqueParts.joined(separator: " ")
    }
}

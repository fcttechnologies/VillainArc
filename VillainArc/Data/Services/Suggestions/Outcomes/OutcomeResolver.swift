import Foundation
import SwiftData

// MARK: - Rule Signal

struct OutcomeSignal {
    let outcome: Outcome
    let confidence: Double
    let reason: String
}

struct AIOutcomeContextFields: Equatable {
    let postWorkoutEffort: Int?
    let preWorkoutFeeling: AIMoodLevel?
    let tookPreWorkout: Bool?
}

// MARK: - Internal Grouping

private struct OutcomeGroup {
    let event: SuggestionEvent
    let exercisePerf: ExercisePerformance
    let prescription: ExercisePrescription
    let setPrescription: SetPrescription?

    var changes: [PrescriptionChange] { event.sortedChanges }
}

private struct OutcomeScoreTotals {
    let netScore: Double
    let bucketTotals: [Outcome: Double]
}

private enum FinalizationDecision {
    case pending
    case escalateToThree
    case finalize(outcome: Outcome, reason: String)
}

// MARK: - Resolver

struct OutcomeResolver {

    // MARK: - Public Entry Point

    static func resolveOutcomes(for workout: WorkoutSession, context: ModelContext) async {
        guard workout.workoutPlan != nil else { return }

        // Step 1: Gather eligible events
        let eligible = gatherEligibleEvents(for: workout)
        guard !eligible.isEmpty else { return }

        // Build performance lookups for this workout.
        let perfByPrescriptionID = Dictionary(uniqueKeysWithValues: workout.sortedExercises.compactMap { perf in perf.prescription.map { ($0.id, perf) } })
        // Step 2: Group changes (same structure as SuggestionGrouping) and match performances.
        let groups = buildGroups(eligible: eligible, perfByPrescriptionID: perfByPrescriptionID)

        // Step 3: Rules phase — evaluate each change individually, track results.
        var ruleResults: [UUID: OutcomeSignal?] = [:]
        for group in groups {
            let groupTrainingStyle = resolvedTrainingStyle(for: group)
            for change in group.changes {
                ruleResults[change.id] = OutcomeRuleEngine.evaluate(change: change, event: group.event, exercisePerf: group.exercisePerf, trainingStyle: groupTrainingStyle)
            }
        }

        // Step 4: Build AI inputs per group and run AI in parallel.
        var aiGroupInputs: [(eventID: UUID, input: AIOutcomeGroupInput, rejected: Bool)] = []

        for group in groups {
            let groupRuleSignal = aggregateRuleSignal(changes: group.changes, ruleResults: ruleResults)
            guard shouldRunAI(for: groupRuleSignal) else { continue }
            guard let aiInput = buildAIGroupInput(group: group, groupRuleSignal: groupRuleSignal) else { continue }
            aiGroupInputs.append((group.event.id, aiInput, isRejectedGroup(group)))
        }

        let aiResults = await withTaskGroup(of: (UUID, AIOutcomeInferenceOutput?).self) { taskGroup in
            for pair in aiGroupInputs {
                taskGroup.addTask {
                    let result: AIOutcomeInferenceOutput?
                    if pair.rejected {
                        result = await AIOutcomeInferrer.inferRejected(input: pair.input)
                    } else {
                        result = await AIOutcomeInferrer.inferApplied(input: pair.input)
                    }
                    return (pair.eventID, result)
                }
            }
            var results: [UUID: AIOutcomeInferenceOutput] = [:]
            for await (eventID, output) in taskGroup {
                if let output { results[eventID] = output }
            }
            return results
        }

        // Step 5: Merge phase — apply outcome entries to each event.
        var processedEventIDs = Set<UUID>()

        for group in groups {
            applyOutcomeIfPossible(event: group.event, changes: group.changes, exercisePerf: group.exercisePerf, ruleResults: ruleResults, aiOutput: aiResults[group.event.id], sessionID: workout.id, processedIDs: &processedEventIDs)
        }

        // Step 6: Persist
        try? context.save()
    }

    // MARK: - Gather Eligible Events

    private static func gatherEligibleEvents(for workout: WorkoutSession) -> [SuggestionEvent] {
        let prescriptions = workout.sortedExercises.compactMap { $0.prescription }
        guard !prescriptions.isEmpty else { return [] }

        var seen = Set<UUID>()
        var eligible: [SuggestionEvent] = []

        for prescription in prescriptions {
            for event in prescription.suggestionEvents ?? [] {
                guard event.outcome == .pending, event.createdAt < workout.startedAt, event.decision == .accepted || event.decision == .rejected else { continue }
                if seen.insert(event.id).inserted { eligible.append(event) }
            }
            for set in prescription.sortedSets {
                for event in set.suggestionEvents ?? [] {
                    guard event.outcome == .pending, event.createdAt < workout.startedAt, event.decision == .accepted || event.decision == .rejected else { continue }
                    if seen.insert(event.id).inserted { eligible.append(event) }
                }
            }
        }

        return eligible
    }

    // MARK: - Build Groups

    private static func buildGroups(eligible: [SuggestionEvent], perfByPrescriptionID: [UUID: ExercisePerformance]) -> [OutcomeGroup] {
        eligible.compactMap { event in
            guard let prescription = event.targetExercisePrescription else { return nil }
            guard let exercisePerf = perfByPrescriptionID[prescription.id] else { return nil }
            return OutcomeGroup(event: event, exercisePerf: exercisePerf, prescription: prescription, setPrescription: event.targetSetPrescription)
        }
    }

    // MARK: - Build AI Group Input

    private static func buildAIGroupInput(group: OutcomeGroup, groupRuleSignal: OutcomeSignal?) -> AIOutcomeGroupInput? {
        guard canEvaluateWithCurrentPerformance(group: group) else { return nil }

        // Convert changes to AI-friendly format.
        let aiChanges: [AIOutcomeChange] = group.changes.map { change in
            AIOutcomeChange(changeType: change.changeType, scope: group.event.isSetScoped ? .set : .exercise, triggerTargetSetIndex: group.event.triggerTargetSetIndex, previousValue: formattedChangeValue(change.previousValue, changeType: change.changeType), newValue: formattedChangeValue(change.newValue, changeType: change.changeType))
        }
        guard !aiChanges.isEmpty else { return nil }

        // Build prescription snapshot (the "before" state) from the frozen trigger target snapshot.
        guard let prescriptionSnapshot = buildPrescriptionSnapshot(group: group) else { return nil }
        guard let triggerPerf = group.event.triggerPerformance, let triggerTargetSnapshot = group.event.triggerTargetSnapshot else { return nil }

        let triggerPerformanceSnapshot = ExercisePerformanceSnapshot(performance: triggerPerf)
        let triggerSnapshot = buildAIPerformanceSnapshot(from: triggerPerformanceSnapshot, targetSnapshot: triggerTargetSnapshot, prescription: group.prescription, date: group.event.createdAt)

        // Actual performance: what the user did this time.
        let actualSnapshot = AIExercisePerformanceSnapshot(performance: group.exercisePerf)

        // Aggregate rule outcome for the group — use the most common or most severe.
        let style = resolvedTrainingStyle(for: group)
        let contextFields = aiContextFields(for: group.exercisePerf.workoutSession)

        return AIOutcomeGroupInput(category: group.event.category, categoryGuidance: group.event.category.guidance(isSetScoped: group.event.isSetScoped, targetSetType: group.event.targetSetPrescription?.type, changeTypes: group.changes.map(\.changeType)), changes: aiChanges, prescription: prescriptionSnapshot, triggerPerformance: triggerSnapshot, actualPerformance: actualSnapshot, trainingStyle: style != .unknown ? style : nil, postWorkoutEffort: contextFields.postWorkoutEffort, preWorkoutFeeling: contextFields.preWorkoutFeeling, tookPreWorkout: contextFields.tookPreWorkout, ruleOutcome: groupRuleSignal.flatMap { AIOutcome(from: $0.outcome) }, ruleConfidence: groupRuleSignal?.confidence, ruleReason: groupRuleSignal?.reason)
    }

    static func aiContextFields(for workout: WorkoutSession?) -> AIOutcomeContextFields {
        let effort = workout.flatMap { (1...10).contains($0.postEffort) ? $0.postEffort : nil }
        let feeling = workout?.preWorkoutContext.map(\.feeling).flatMap(AIMoodLevel.init(from:))
        let tookPreWorkout = workout?.preWorkoutContext?.tookPreWorkout == true ? true : nil
        return AIOutcomeContextFields(postWorkoutEffort: effort, preWorkoutFeeling: feeling, tookPreWorkout: tookPreWorkout)
    }

    static func hasSufficientCurrentEvidence(for event: SuggestionEvent, in exercisePerf: ExercisePerformance) -> Bool {
        guard event.isSetScoped else { return true }
        guard let setPrescriptionID = event.targetSetPrescription?.id else { return false }

        let completedSets = exercisePerf.sortedSets.filter(\.complete)
        guard let targetedSet = completedSets.first(where: { $0.prescription?.id == setPrescriptionID }) else { return false }

        let changeTypes = Set(event.sortedChanges.map(\.changeType))
        let isRecoveryEvent = changeTypes.contains(.increaseRest) || changeTypes.contains(.decreaseRest)
        guard isRecoveryEvent else { return true }

        return completedSets.contains { set in set.index > targetedSet.index && set.type == .working && set.prescription != nil }
    }

    private static func canEvaluateWithCurrentPerformance(group: OutcomeGroup) -> Bool { hasSufficientCurrentEvidence(for: group.event, in: group.exercisePerf) }

    private static func resolvedTrainingStyle(for group: OutcomeGroup) -> TrainingStyle {
        let storedStyle = group.event.trainingStyle
        return storedStyle != .unknown ? storedStyle : MetricsCalculator.detectTrainingStyle(group.exercisePerf.sortedSets)
    }

    private static func buildPrescriptionSnapshot(group: OutcomeGroup) -> AIExercisePrescriptionSnapshot? {
        guard let targetSnapshot = group.event.triggerTargetSnapshot else { return nil }
        return AIExercisePrescriptionSnapshot(exercise: AIExerciseIdentitySnapshot(prescription: group.prescription), targetSnapshot: targetSnapshot)
    }

    /// Returns true when the change represents the core progression intent of a group.
    /// Weight changes anchor multi-change bundles; secondary changes (rep resets, rest
    /// adjustments) are companions that refine, not drive, the progression decision.
    private static func isPrimaryChange(_ change: PrescriptionChange) -> Bool {
        change.changeType == .increaseWeight || change.changeType == .decreaseWeight
    }

    /// Picks the most representative rule signal for a group.
    /// When the group contains a primary (weight) change, that change's signal anchors the
    /// result — secondary signals (rep resets, rest adjustments) cannot promote the outcome
    /// above what the primary reports. A tooAggressive secondary can still escalate upward
    /// for safety: companion reps below the floor reveal real overload even when the
    /// weight-change evaluator has already classified the primary outcome as good.
    private static func aggregateRuleSignal(changes: [PrescriptionChange], ruleResults: [UUID: OutcomeSignal?]) -> OutcomeSignal? {
        let signals = changes.compactMap { ruleResults[$0.id] ?? nil }
        guard !signals.isEmpty else { return nil }

        let priority: [Outcome] = [.tooAggressive, .insufficient, .good, .tooEasy, .ignored]

        let primarySignals = changes.compactMap { isPrimaryChange($0) ? ruleResults[$0.id] ?? nil : nil }

        // No primary change in this group — fall back to severity-priority across all signals.
        guard !primarySignals.isEmpty else {
            for outcome in priority { if let signal = signals.first(where: { $0.outcome == outcome }) { return signal } }
            return signals.first
        }

        // Anchor on the most-severe primary signal.
        var anchorSignal: OutcomeSignal?
        for outcome in priority {
            if let signal = primarySignals.first(where: { $0.outcome == outcome }) {
                anchorSignal = signal
                break
            }
        }
        guard let anchor = anchorSignal else { return primarySignals.first }

        // Allow a tooAggressive secondary to escalate for safety — a companion reps signal
        // below the floor reveals real overload even when the primary anchor is good.
        // Secondary signals can never promote the result upward past the primary anchor.
        if anchor.outcome != .tooAggressive {
            let secondarySignals = changes.compactMap { !isPrimaryChange($0) ? ruleResults[$0.id] ?? nil : nil }
            if let aggressiveSecondary = secondarySignals.first(where: { $0.outcome == .tooAggressive }) { return aggressiveSecondary }
        }

        return anchor
    }

    private static func isRejectedGroup(_ group: OutcomeGroup) -> Bool { group.event.decision != .accepted }

    // MARK: - Helpers

    private static func formattedChangeValue(_ value: Double, changeType: ChangeType) -> String {
        let roundedInt = Int(value.rounded())

        switch changeType {
        case .increaseWeight, .decreaseWeight: return value.formatted(.number.precision(.fractionLength(0...2)))
        case .increaseReps, .decreaseReps, .increaseRepRangeLower, .decreaseRepRangeLower, .increaseRepRangeUpper, .decreaseRepRangeUpper, .increaseRepRangeTarget, .decreaseRepRangeTarget, .increaseRest, .decreaseRest: return String(roundedInt)
        case .changeSetType:
            if let type = ExerciseSetType(rawValue: roundedInt) { return type.displayName }
            return String(roundedInt)
        case .changeRepRangeMode:
            if let mode = RepRangeMode(rawValue: roundedInt) { return mode.displayName }
            return String(roundedInt)
        }
    }

    // MARK: - Merge

    struct ResolvedOutcome {
        let outcome: Outcome
        let confidence: Double
        let reason: String
    }

    static func shouldRunAI(for rule: OutcomeSignal?) -> Bool {
        guard let rule else { return true }
        return rule.confidence < 0.85
    }

    static func shouldPreferAIOverride(rule: OutcomeSignal, ai: AIOutcomeInferenceOutput) -> Bool {
        guard ai.outcome.outcome != rule.outcome else { return false }

        if rule.confidence < 0.7 { return ai.confidence >= 0.75 }

        return ai.confidence >= max(0.85, rule.confidence + 0.05)
    }

    static func mergeOutcome(rule: OutcomeSignal?, ai: AIOutcomeInferenceOutput?) -> ResolvedOutcome? {
        if rule == nil {
            guard let ai else { return nil }
            return ResolvedOutcome(outcome: ai.outcome.outcome, confidence: ai.confidence, reason: "[AI] \(ai.reason)")
        }

        let ruleOutcome = rule!

        guard let ai else { return ResolvedOutcome(outcome: ruleOutcome.outcome, confidence: ruleOutcome.confidence, reason: "[Rules] \(ruleOutcome.reason)") }

        if shouldPreferAIOverride(rule: ruleOutcome, ai: ai) { return ResolvedOutcome(outcome: ai.outcome.outcome, confidence: ai.confidence, reason: "[AI override] \(ai.reason)") }

        return ResolvedOutcome(outcome: ruleOutcome.outcome, confidence: ruleOutcome.confidence, reason: "[Rules] \(ruleOutcome.reason)")
    }

    static func adjustedConfidence(_ baseConfidence: Double, for outcome: Outcome, workout: WorkoutSession?) -> Double {
        guard outcome != .ignored else { return min(1.0, max(0.0, baseConfidence)) }

        var adjusted = baseConfidence
        let isNegative = isNegativeOutcome(outcome)
        let isPositive = isPositiveOutcome(outcome)

        if let workout, (1...10).contains(workout.postEffort) {
            switch workout.postEffort {
            case 9...10:
                if isNegative { adjusted *= 1.2 }
                if isPositive { adjusted *= 0.9 }
            case 1...4:
                if isNegative { adjusted *= 0.85 }
                if isPositive { adjusted *= 1.1 }
            default: break
            }
        }

        if let feeling = workout?.preWorkoutContext?.feeling {
            switch feeling {
            case .tired: if isNegative { adjusted *= 0.85 }
            case .good, .great: if isNegative { adjusted *= 1.05 }
            case .okay, .notSet: break
            }
        }

        if workout?.preWorkoutContext?.tookPreWorkout == true {
            if isNegative { adjusted *= 1.05 }
            if isPositive { adjusted *= 0.95 }
        }

        return min(1.0, max(0.0, adjusted))
    }

    private static func applyOutcomeIfPossible(event: SuggestionEvent, changes: [PrescriptionChange], exercisePerf: ExercisePerformance, ruleResults: [UUID: OutcomeSignal?], aiOutput: AIOutcomeInferenceOutput?, sessionID: UUID, processedIDs: inout Set<UUID>) {
        guard event.outcome == .pending, event.evaluatedAt == nil else { return }
        // Within-invocation dedup: prevents both the AI pass and the fallback pass from appending in the same call.
        guard processedIDs.insert(event.id).inserted else { return }
        // Cross-invocation dedup: check stored scalar on evaluations to avoid traversing relationships.
        let existingEvaluations = event.evaluations ?? []
        guard !existingEvaluations.contains(where: { $0.sourceWorkoutSessionID == sessionID }) else { return }

        let groupRuleSignal = aggregateRuleSignal(changes: changes, ruleResults: ruleResults)
        guard let resolved = mergeOutcome(rule: groupRuleSignal, ai: aiOutput) else { return }
        let evaluationConfidence = adjustedConfidence(resolved.confidence, for: resolved.outcome, workout: exercisePerf.workoutSession)
        let evaluation = SuggestionEvaluation(event: event, performance: exercisePerf, sourceWorkoutSessionID: sessionID, partialOutcome: resolved.outcome, confidence: evaluationConfidence, reason: resolved.reason)
        exercisePerf.modelContext?.insert(evaluation)

        let allEvaluations = existingEvaluations + [evaluation]
        guard allEvaluations.count >= event.requiredEvaluationCount else { return }

        switch finalizationDecision(for: allEvaluations, requiredEvaluationCount: event.requiredEvaluationCount) {
        case .pending: return
        case .escalateToThree:
            event.outcome = .pending
            event.outcomeReason = nil
            event.evaluatedAt = nil
            event.requiredEvaluationCount = max(event.requiredEvaluationCount, 3)
        case .finalize(let outcome, let reason):
            event.outcome = outcome
            event.outcomeReason = reason
            event.evaluatedAt = Date()
        }
    }

    private static func finalizationDecision(for evaluations: [SuggestionEvaluation], requiredEvaluationCount: Int) -> FinalizationDecision {
        let totals = scoreTotals(for: evaluations)
        let outcomes = Set(evaluations.map(\.partialOutcome))
        let hasDirectionalEvidence = outcomes.contains(where: isNegativeOutcome) || outcomes.contains(where: isPositiveOutcome)

        if !hasDirectionalEvidence, evaluations.count >= requiredEvaluationCount, let reason = aggregateReason(for: .ignored, evaluations: evaluations) { return .finalize(outcome: .ignored, reason: reason) }

        if requiredEvaluationCount == 2, evaluations.count == 2, outcomes.contains(where: isNegativeOutcome), outcomes.contains(where: isPositiveOutcome) {
            if outcomes == Set([.tooAggressive, .tooEasy]) { return .escalateToThree }
            if abs(totals.netScore) < 0.75 { return .escalateToThree }
        }

        if totals.netScore <= -0.75, let outcome = dominantNegativeOutcome(from: totals.bucketTotals), let reason = aggregateReason(for: outcome, evaluations: evaluations) {
            return .finalize(outcome: outcome, reason: reason)
        }

        if totals.netScore >= 0.75, let outcome = dominantPositiveOutcome(from: totals.bucketTotals), let reason = aggregateReason(for: outcome, evaluations: evaluations) {
            return .finalize(outcome: outcome, reason: reason)
        }

        if evaluations.count >= 3, let reason = aggregateReason(for: .ignored, evaluations: evaluations) { return .finalize(outcome: .ignored, reason: reason) }

        return .pending
    }

    private static func scoreTotals(for evaluations: [SuggestionEvaluation]) -> OutcomeScoreTotals {
        var netScore = 0.0
        var bucketTotals: [Outcome: Double] = [:]

        for evaluation in evaluations {
            let bucketValue = abs(scoreValue(for: evaluation.partialOutcome)) * evaluation.confidence
            bucketTotals[evaluation.partialOutcome, default: 0] += bucketValue
            netScore += scoreValue(for: evaluation.partialOutcome) * evaluation.confidence
        }

        return OutcomeScoreTotals(netScore: netScore, bucketTotals: bucketTotals)
    }

    private static func dominantNegativeOutcome(from bucketTotals: [Outcome: Double]) -> Outcome? {
        let tooAggressiveScore = bucketTotals[.tooAggressive, default: 0]
        let insufficientScore = bucketTotals[.insufficient, default: 0]
        guard tooAggressiveScore > 0 || insufficientScore > 0 else { return nil }
        return tooAggressiveScore >= insufficientScore ? .tooAggressive : .insufficient
    }

    private static func dominantPositiveOutcome(from bucketTotals: [Outcome: Double]) -> Outcome? {
        let goodScore = bucketTotals[.good, default: 0]
        let tooEasyScore = bucketTotals[.tooEasy, default: 0]
        guard goodScore > 0 || tooEasyScore > 0 else { return nil }
        return goodScore >= tooEasyScore ? .good : .tooEasy
    }

    private static func aggregateReason(for outcome: Outcome, evaluations: [SuggestionEvaluation]) -> String? {
        let relevantEvaluations: [SuggestionEvaluation]

        if outcome == .ignored {
            relevantEvaluations = evaluations
        } else {
            relevantEvaluations = evaluations.filter { $0.partialOutcome == outcome }
        }

        guard let winningEvaluation = relevantEvaluations.max(by: { $0.confidence < $1.confidence }) else { return nil }
        return "[Aggregate] \(winningEvaluation.reason)"
    }

    private static func scoreValue(for outcome: Outcome) -> Double {
        switch outcome {
        case .tooAggressive: return -2
        case .insufficient: return -1
        case .ignored, .pending: return 0
        case .tooEasy: return 1
        case .good: return 2
        }
    }

    private static func isNegativeOutcome(_ outcome: Outcome) -> Bool {
        outcome == .tooAggressive || outcome == .insufficient
    }

    private static func isPositiveOutcome(_ outcome: Outcome) -> Bool {
        outcome == .good || outcome == .tooEasy
    }

    private static func buildAIPerformanceSnapshot(from snapshot: ExercisePerformanceSnapshot, targetSnapshot: ExerciseTargetSnapshot, prescription: ExercisePrescription, date: Date) -> AIExercisePerformanceSnapshot {
        AIExercisePerformanceSnapshot(exercise: AIExerciseIdentitySnapshot(prescription: prescription), date: date, snapshot: snapshot, targetSnapshot: targetSnapshot)
    }
}

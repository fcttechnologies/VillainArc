import Foundation
import SwiftData

// MARK: - Rule Signal

struct OutcomeSignal {
    let outcome: Outcome
    let confidence: Double
    let reason: String
}

// MARK: - Internal Grouping

private struct OutcomeGroup {
    let event: SuggestionEvent
    let exercisePerf: ExercisePerformance
    let prescription: ExercisePrescription
    let setPrescription: SetPrescription?

    var changes: [PrescriptionChange] { event.sortedChanges }
}

// MARK: - Resolver

@MainActor
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
                if let output {
                    results[eventID] = output
                }
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

        func appendIfEligible(_ event: SuggestionEvent?) {
            guard let event, event.outcome == .pending, event.createdAt < workout.startedAt, event.decision == .accepted || event.decision == .rejected else { return }
            if seen.insert(event.id).inserted {
                eligible.append(event)
            }
        }

        for prescription in prescriptions {
            for event in prescription.suggestionEvents ?? [] {
                appendIfEligible(event)
            }
            for set in prescription.sortedSets {
                for event in set.suggestionEvents ?? [] {
                    appendIfEligible(event)
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
        let prescriptionSnapshot = buildPrescriptionSnapshot(group: group)

        let triggerSnapshot = buildAIPerformanceSnapshot(from: group.event.triggerPerformanceSnapshot, targetSnapshot: group.event.triggerTargetSnapshot, prescription: group.prescription, date: group.event.createdAt)

        // Actual performance: what the user did this time.
        let actualSnapshot = AIExercisePerformanceSnapshot(performance: group.exercisePerf)

        // Aggregate rule outcome for the group — use the most common or most severe.
        let style = resolvedTrainingStyle(for: group)

        return AIOutcomeGroupInput(category: group.event.category, categoryGuidance: group.event.category.guidance(isSetScoped: group.event.isSetScoped, targetSetType: group.event.targetSetPrescription?.type, changeTypes: group.changes.map(\.changeType)), changes: aiChanges, prescription: prescriptionSnapshot, triggerPerformance: triggerSnapshot, actualPerformance: actualSnapshot, trainingStyle: style != .unknown ? style : nil, ruleOutcome: groupRuleSignal.flatMap { AIOutcome(from: $0.outcome) }, ruleConfidence: groupRuleSignal?.confidence, ruleReason: groupRuleSignal?.reason)
    }

    static func hasSufficientCurrentEvidence(for event: SuggestionEvent, in exercisePerf: ExercisePerformance) -> Bool {
        guard event.isSetScoped else { return true }
        guard let setPrescriptionID = event.targetSetPrescription?.id else { return false }

        let completedSets = exercisePerf.sortedSets.filter(\.complete)
        guard let targetedSet = completedSets.first(where: { $0.prescription?.id == setPrescriptionID }) else {
            return false
        }

        let changeTypes = Set(event.sortedChanges.map(\.changeType))
        let isRecoveryEvent = changeTypes.contains(.increaseRest) || changeTypes.contains(.decreaseRest)
        guard isRecoveryEvent else { return true }

        return completedSets.contains { set in
            set.index > targetedSet.index &&
            set.type == .working &&
            set.prescription != nil
        }
    }

    private static func canEvaluateWithCurrentPerformance(group: OutcomeGroup) -> Bool {
        hasSufficientCurrentEvidence(for: group.event, in: group.exercisePerf)
    }

    private static func resolvedTrainingStyle(for group: OutcomeGroup) -> TrainingStyle {
        let storedStyle = group.event.trainingStyle
        return storedStyle != .unknown ? storedStyle : MetricsCalculator.detectTrainingStyle(group.exercisePerf.sortedSets)
    }

    private static func buildPrescriptionSnapshot(group: OutcomeGroup) -> AIExercisePrescriptionSnapshot {
        AIExercisePrescriptionSnapshot(exercise: AIExerciseIdentitySnapshot(prescription: group.prescription), targetSnapshot: group.event.triggerTargetSnapshot)
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
            for outcome in priority {
                if let signal = signals.first(where: { $0.outcome == outcome }) { return signal }
            }
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
            if let aggressiveSecondary = secondarySignals.first(where: { $0.outcome == .tooAggressive }) {
                return aggressiveSecondary
            }
        }

        return anchor
    }

    private static func isRejectedGroup(_ group: OutcomeGroup) -> Bool {
        group.event.decision != .accepted
    }

    // MARK: - Helpers

    private static func formattedChangeValue(_ value: Double, changeType: ChangeType) -> String {
        let roundedInt = Int(value.rounded())

        switch changeType {
        case .increaseWeight, .decreaseWeight:
            return value.formatted(.number.precision(.fractionLength(0...2)))
        case .increaseReps, .decreaseReps,
             .increaseRepRangeLower, .decreaseRepRangeLower,
             .increaseRepRangeUpper, .decreaseRepRangeUpper,
             .increaseRepRangeTarget, .decreaseRepRangeTarget,
             .increaseRest, .decreaseRest:
            return String(roundedInt)
        case .changeSetType:
            if let type = ExerciseSetType(rawValue: roundedInt) {
                return type.displayName
            }
            return String(roundedInt)
        case .changeRepRangeMode:
            if let mode = RepRangeMode(rawValue: roundedInt) {
                return mode.displayName
            }
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

        if rule.confidence < 0.7 {
            return ai.confidence >= 0.75
        }

        return ai.confidence >= max(0.85, rule.confidence + 0.05)
    }

    static func mergeOutcome(rule: OutcomeSignal?, ai: AIOutcomeInferenceOutput?) -> ResolvedOutcome? {
        if rule == nil {
            guard let ai else { return nil }
            return ResolvedOutcome(outcome: ai.outcome.outcome, confidence: ai.confidence, reason: "[AI] \(ai.reason)")
        }

        let ruleOutcome = rule!

        guard let ai else {
            return ResolvedOutcome(outcome: ruleOutcome.outcome, confidence: ruleOutcome.confidence, reason: "[Rules] \(ruleOutcome.reason)")
        }

        if shouldPreferAIOverride(rule: ruleOutcome, ai: ai) {
            return ResolvedOutcome(outcome: ai.outcome.outcome, confidence: ai.confidence, reason: "[AI override] \(ai.reason)")
        }

        return ResolvedOutcome(outcome: ruleOutcome.outcome, confidence: ruleOutcome.confidence, reason: "[Rules] \(ruleOutcome.reason)")
    }

    private static func applyOutcomeIfPossible(event: SuggestionEvent, changes: [PrescriptionChange], exercisePerf: ExercisePerformance, ruleResults: [UUID: OutcomeSignal?], aiOutput: AIOutcomeInferenceOutput?, sessionID: UUID, processedIDs: inout Set<UUID>) {
        guard event.outcome == .pending, event.evaluatedAt == nil else { return }
        // Within-invocation dedup: prevents both the AI pass and the fallback pass from appending in the same call.
        guard processedIDs.insert(event.id).inserted else { return }
        // Cross-invocation dedup: prevents repeated resolver calls for the same workout from inflating the history.
        guard !event.evaluationHistory.contains(where: { $0.sourceSessionID == sessionID }) else { return }

        let groupRuleSignal = aggregateRuleSignal(changes: changes, ruleResults: ruleResults)
        guard let resolved = mergeOutcome(rule: groupRuleSignal, ai: aiOutput) else { return }

        let entry = EvaluationHistoryEntry(sourceSessionID: sessionID, snapshot: ExercisePerformanceSnapshot(performance: exercisePerf), partialOutcome: resolved.outcome, confidence: resolved.confidence, reason: resolved.reason)
        event.evaluationHistory.append(entry)

        // Only tooAggressive always resolves immediately — one session showing the change is
        // actively too hard is sufficient to stop. good, tooEasy, and ignored should honor the
        // threshold so a single noisy workout doesn't short-circuit multi-session confirmation.
        let isDecisive: Bool
        switch resolved.outcome {
        case .tooAggressive:
            isDecisive = true
        case .tooEasy, .ignored, .good, .insufficient:
            isDecisive = false
        default:
            isDecisive = false
        }
        guard isDecisive || event.evaluationHistory.count >= event.requiredEvaluationCount else { return }

        // Safety-weighted priority across all accumulated entries.
        let priority: [Outcome] = [.tooAggressive, .insufficient, .good, .tooEasy, .ignored]
        guard let winning = priority.first(where: { o in event.evaluationHistory.contains { $0.partialOutcome == o } }), let winningEntry = event.evaluationHistory.first(where: { $0.partialOutcome == winning }) else { return }

        event.outcome = winning
        event.outcomeReason = winningEntry.reason
        event.evaluatedAt = Date()
    }

    private static func buildAIPerformanceSnapshot(from snapshot: ExercisePerformanceSnapshot, targetSnapshot: ExerciseTargetSnapshot, prescription: ExercisePrescription, date: Date) -> AIExercisePerformanceSnapshot {
        AIExercisePerformanceSnapshot(exercise: AIExerciseIdentitySnapshot(prescription: prescription), date: date, snapshot: snapshot, targetSnapshot: targetSnapshot)
    }
}

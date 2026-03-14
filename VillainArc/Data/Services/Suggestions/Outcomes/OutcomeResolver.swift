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
                ruleResults[change.id] = OutcomeRuleEngine.evaluate(change: change, exercisePerf: group.exercisePerf, trainingStyle: groupTrainingStyle)
            }
        }

        // Step 4: Build AI inputs per group and run AI in parallel.
        var aiGroupInputs: [(group: OutcomeGroup, input: AIOutcomeGroupInput, rejected: Bool)] = []

        for group in groups {
            guard let aiInput = buildAIGroupInput(group: group, ruleResults: ruleResults) else { continue }
            aiGroupInputs.append((group, aiInput, isRejectedGroup(group)))
        }

        let aiResults = await withTaskGroup(of: (Int, AIOutcomeInferenceOutput?).self) { taskGroup in
            for (index, pair) in aiGroupInputs.enumerated() {
                taskGroup.addTask {
                    let result: AIOutcomeInferenceOutput?
                    if pair.rejected {
                        result = await AIOutcomeInferrer.inferRejected(input: pair.input)
                    } else {
                        result = await AIOutcomeInferrer.inferApplied(input: pair.input)
                    }
                    return (index, result)
                }
            }
            var results: [Int: AIOutcomeInferenceOutput] = [:]
            for await (index, output) in taskGroup {
                if let output {
                    results[index] = output
                }
            }
            return results
        }

        // Step 5: Merge phase — apply outcomes to each event.
        for (index, pair) in aiGroupInputs.enumerated() {
            let aiOutput = aiResults[index]
            applyOutcomeIfPossible(event: pair.group.event, changes: pair.group.changes, exercisePerf: pair.group.exercisePerf, ruleResults: ruleResults, aiOutput: aiOutput)
        }

        // Apply rule-only results for any remaining pending events.
        for group in groups {
            applyOutcomeIfPossible(event: group.event, changes: group.changes, exercisePerf: group.exercisePerf, ruleResults: ruleResults, aiOutput: nil)
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
            guard let event,
                  event.outcome == .pending,
                  event.createdAt < workout.startedAt,
                  event.decision == .accepted || event.decision == .rejected else { return }
            if seen.insert(event.id).inserted {
                eligible.append(event)
            }
        }

        for prescription in prescriptions {
            for change in prescription.changes ?? [] {
                appendIfEligible(change.event)
            }
            for set in prescription.sortedSets {
                for change in set.changes ?? [] {
                    appendIfEligible(change.event)
                }
            }
        }

        return eligible
    }

    // MARK: - Build Groups

    private static func buildGroups(eligible: [SuggestionEvent], perfByPrescriptionID: [UUID: ExercisePerformance]) -> [OutcomeGroup] {
        eligible.compactMap { event in
            guard let prescription = event.changes?.compactMap(\.targetExercisePrescription).first else { return nil }
            guard let exercisePerf = perfByPrescriptionID[prescription.id] else { return nil }
            let setPrescription = event.changes?.compactMap(\.targetSetPrescription).first
            return OutcomeGroup(event: event, exercisePerf: exercisePerf, prescription: prescription, setPrescription: setPrescription)
        }
    }

    // MARK: - Build AI Group Input

    private static func buildAIGroupInput(group: OutcomeGroup, ruleResults: [UUID: OutcomeSignal?]) -> AIOutcomeGroupInput? {
        guard canEvaluateWithCurrentPerformance(group: group) else { return nil }

        // Convert changes to AI-friendly format.
        let aiChanges: [AIOutcomeChange] = group.changes.map { change in
            AIOutcomeChange(
                changeType: change.changeType,
                scope: (change.targetSetIndex != nil || change.targetSetPrescription != nil) ? .set : .exercise,
                targetSetIndex: change.targetSetIndex ?? change.targetSetPrescription?.index,
                previousValue: formattedChangeValue(change.previousValue, changeType: change.changeType),
                newValue: formattedChangeValue(change.newValue, changeType: change.changeType)
            )
        }
        guard !aiChanges.isEmpty else { return nil }

        // Build prescription snapshot (the "before" state) from the frozen trigger target snapshot.
        let prescriptionSnapshot = buildPrescriptionSnapshot(group: group)

        let triggerSnapshot = buildAIPerformanceSnapshot(from: group.event.triggerPerformanceSnapshot, prescription: group.prescription, date: group.event.createdAt)

        // Actual performance: what the user did this time.
        let actualSnapshot = AIExercisePerformanceSnapshot(performance: group.exercisePerf)

        // Aggregate rule outcome for the group — use the most common or most severe.
        let groupRuleSignal = aggregateRuleSignal(changes: group.changes, ruleResults: ruleResults)

        let style = resolvedTrainingStyle(for: group)

        return AIOutcomeGroupInput(changes: aiChanges, prescription: prescriptionSnapshot, triggerPerformance: triggerSnapshot, actualPerformance: actualSnapshot, trainingStyle: style != .unknown ? style : nil, ruleOutcome: groupRuleSignal.flatMap { AIOutcome(from: $0.outcome) }, ruleConfidence: groupRuleSignal?.confidence, ruleReason: groupRuleSignal?.reason)
    }

    private static func canEvaluateWithCurrentPerformance(group: OutcomeGroup) -> Bool {
        guard group.changes.contains(where: { $0.targetSetIndex != nil || $0.targetSetPrescription != nil }) else { return true }
        guard let setPrescriptionID = group.setPrescription?.id else { return false }
        return group.exercisePerf.sortedSets.contains { set in
            set.complete && set.prescription?.id == setPrescriptionID
        }
    }

    private static func resolvedTrainingStyle(for group: OutcomeGroup) -> TrainingStyle {
        let storedStyle = group.event.trainingStyle
        return storedStyle != .unknown ? storedStyle : MetricsCalculator.detectTrainingStyle(group.exercisePerf.sortedSets)
    }

    private static func buildPrescriptionSnapshot(group: OutcomeGroup) -> AIExercisePrescriptionSnapshot {
        AIExercisePrescriptionSnapshot(
            exercise: AIExerciseIdentitySnapshot(prescription: group.prescription),
            targetSnapshot: group.event.triggerTargetSnapshot
        )
    }

    /// Picks the most representative rule signal for a group.
    private static func aggregateRuleSignal(changes: [PrescriptionChange], ruleResults: [UUID: OutcomeSignal?]) -> OutcomeSignal? {
        let signals = changes.compactMap { ruleResults[$0.id] ?? nil }
        guard !signals.isEmpty else { return nil }

        // Priority: tooAggressive > good > tooEasy > ignored (for safety).
        let priority: [Outcome] = [.tooAggressive, .good, .tooEasy, .ignored]
        for outcome in priority {
            if let signal = signals.first(where: { $0.outcome == outcome }) {
                return signal
            }
        }
        return signals.first
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

    private struct ResolvedOutcome {
        let outcome: Outcome
        let reason: String
    }

    private static func mergeOutcome(rule: OutcomeSignal?, ai: AIOutcomeInferenceOutput?) -> ResolvedOutcome? {
        if rule == nil {
            guard let ai else { return nil }
            return ResolvedOutcome(outcome: ai.outcome.outcome, reason: "[AI] \(ai.reason)")
        }

        let ruleOutcome = rule!

        guard let ai else {
            return ResolvedOutcome(outcome: ruleOutcome.outcome, reason: "[Rules] \(ruleOutcome.reason)")
        }

        if ai.outcome.outcome != ruleOutcome.outcome && ruleOutcome.confidence < 0.7 && ai.confidence >= 0.75 {
            return ResolvedOutcome(outcome: ai.outcome.outcome, reason: "[AI override] \(ai.reason)")
        }

        return ResolvedOutcome(outcome: ruleOutcome.outcome, reason: "[Rules] \(ruleOutcome.reason)")
    }

    private static func applyOutcomeIfPossible(event: SuggestionEvent, changes: [PrescriptionChange], exercisePerf: ExercisePerformance, ruleResults: [UUID: OutcomeSignal?], aiOutput: AIOutcomeInferenceOutput?) {
        guard event.outcome == .pending, event.evaluatedAt == nil else { return }
        let groupRuleSignal = aggregateRuleSignal(changes: changes, ruleResults: ruleResults)
        guard let resolved = mergeOutcome(rule: groupRuleSignal, ai: aiOutput) else { return }
        applyResolvedOutcome(resolved, to: event, exercisePerf: exercisePerf)
    }

    private static func applyResolvedOutcome(_ resolved: ResolvedOutcome, to event: SuggestionEvent, exercisePerf: ExercisePerformance) {
        event.outcome = resolved.outcome
        event.outcomeReason = resolved.reason
        event.evaluatedAt = Date()
        event.evaluatedPerformanceSnapshot = ExercisePerformanceSnapshot(performance: exercisePerf)
    }

    private static func buildAIPerformanceSnapshot(from snapshot: ExercisePerformanceSnapshot, prescription: ExercisePrescription, date: Date) -> AIExercisePerformanceSnapshot {
        AIExercisePerformanceSnapshot(
            exercise: AIExerciseIdentitySnapshot(prescription: prescription),
            date: date,
            snapshot: snapshot
        )
    }
}

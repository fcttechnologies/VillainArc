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
    let changes: [PrescriptionChange]
    let exercisePerf: ExercisePerformance
    let prescription: ExercisePrescription
    let setPrescription: SetPrescription?
    let policy: ChangePolicy?
}

// MARK: - Resolver

@MainActor
struct OutcomeResolver {

    // MARK: - Public Entry Point

    static func resolveOutcomes(for workout: WorkoutSession, context: ModelContext) async {
        guard workout.workoutPlan != nil else { return }

        // Step 1: Gather eligible changes
        let eligible = gatherEligibleChanges(for: workout)
        guard !eligible.isEmpty else { return }

        // Build performance lookups for this workout.
        let perfByPrescriptionID = Dictionary(uniqueKeysWithValues: workout.sortedExercises.compactMap { perf in perf.prescription.map { ($0.id, perf) } })
        // Step 2: Group changes (same structure as SuggestionGrouping) and match performances.
        let groups = buildGroups(eligible: eligible, perfByPrescriptionID: perfByPrescriptionID)

        // Step 3: Rules phase — evaluate each change individually, track results.
        var ruleResults: [UUID: OutcomeSignal?] = [:]
        for group in groups {
            for change in group.changes {
                ruleResults[change.id] = OutcomeRuleEngine.evaluate(change: change, exercisePerf: group.exercisePerf)
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

        // Step 5: Merge phase — apply outcomes to each change.
        for (index, pair) in aiGroupInputs.enumerated() {
            let aiOutput = aiResults[index]
            for change in pair.group.changes {
                applyOutcomeIfPossible(change: change, ruleResults: ruleResults, aiOutput: aiOutput, workout: workout)
            }
        }

        // Apply rule-only results for any remaining pending changes.
        for group in groups {
            for change in group.changes {
                applyOutcomeIfPossible(change: change, ruleResults: ruleResults, aiOutput: nil, workout: workout)
            }
        }

        // Step 6: Persist
        try? context.save()
    }

    // MARK: - Gather Eligible Changes

    private static func gatherEligibleChanges(for workout: WorkoutSession) -> [PrescriptionChange] {
        let prescriptions = workout.sortedExercises.compactMap { $0.prescription }
        guard !prescriptions.isEmpty else { return [] }

        var seen = Set<UUID>()
        var eligible: [PrescriptionChange] = []

        func appendIfEligible(_ change: PrescriptionChange) {
            guard change.outcome == .pending, change.createdAt < workout.startedAt else { return }

            if seen.insert(change.id).inserted {
                eligible.append(change)
            }
        }

        for prescription in prescriptions {
            for change in prescription.changes {
                appendIfEligible(change)
            }
        }

        return eligible
    }

    // MARK: - Build Groups

    private static func buildGroups(eligible: [PrescriptionChange], perfByPrescriptionID: [UUID: ExercisePerformance]) -> [OutcomeGroup] {
        // Group by exercise prescription, then by set or policy (mirrors SuggestionGrouping).
        let byExercise = Dictionary(grouping: eligible) { $0.targetExercisePrescription?.id }

        var groups: [OutcomeGroup] = []

        for (_, exerciseChanges) in byExercise {
            guard let prescription = exerciseChanges.first?.targetExercisePrescription else { continue }

            // Find the matching performance in the current workout.
            guard let exercisePerf = perfByPrescriptionID[prescription.id] else { continue } // Exercise not performed — leave pending.

            // Split into set-level vs exercise-level.
            let setChanges = exerciseChanges.filter { $0.targetSetPrescription != nil }
            let exerciseLevelChanges = exerciseChanges.filter { $0.targetSetPrescription == nil }

            // Group set changes by set ID.
            let bySet = Dictionary(grouping: setChanges) { $0.targetSetPrescription!.id }
            for (_, changes) in bySet {
                groups.append(OutcomeGroup(changes: changes, exercisePerf: exercisePerf, prescription: prescription, setPrescription: changes.first?.targetSetPrescription, policy: nil))
            }

            // Group exercise-level changes by policy.
            let byPolicy = Dictionary(grouping: exerciseLevelChanges) { $0.changeType.policy }
            for (policy, changes) in byPolicy {
                groups.append(OutcomeGroup(changes: changes, exercisePerf: exercisePerf, prescription: prescription, setPrescription: nil, policy: policy))
            }
        }

        return groups
    }

    // MARK: - Build AI Group Input

    private static func buildAIGroupInput(group: OutcomeGroup, ruleResults: [UUID: OutcomeSignal?]) -> AIOutcomeGroupInput? {
        // Convert changes to AI-friendly format.
        let aiChanges: [AIOutcomeChange] = group.changes.map { change in AIOutcomeChange(changeType: change.changeType, previousValue: formattedChangeValue(change.previousValue, changeType: change.changeType), newValue: formattedChangeValue(change.newValue, changeType: change.changeType), targetSetIndex: change.targetSetPrescription?.index) }
        guard !aiChanges.isEmpty else { return nil }

        // Build prescription snapshot (the "before" state).
        let prescriptionSnapshot = buildPrescriptionSnapshot(group: group)

        // Trigger performance: what the user did last time (from the session that created these changes).
        // All changes in a group come from the same exercise, so use the first available.
        guard let triggerExercisePerf = group.changes.compactMap({ $0.sourceExercisePerformance }).first else {
            return nil
        }
        let triggerSnapshot = AIExercisePerformanceSnapshot(performance: triggerExercisePerf)

        // Actual performance: what the user did this time.
        let actualSnapshot = AIExercisePerformanceSnapshot(performance: group.exercisePerf)

        // Aggregate rule outcome for the group — use the most common or most severe.
        let groupRuleSignal = aggregateRuleSignal(changes: group.changes, ruleResults: ruleResults)

        // Detect training style from the current workout's completed sets.
        let completeSets = group.exercisePerf.sortedSets
        let style = MetricsCalculator.detectTrainingStyle(completeSets)

        return AIOutcomeGroupInput(changes: aiChanges, prescription: prescriptionSnapshot, triggerPerformance: triggerSnapshot, actualPerformance: actualSnapshot, trainingStyle: style != .unknown ? style : nil, ruleOutcome: groupRuleSignal.flatMap { AIOutcome(from: $0.outcome) }, ruleConfidence: groupRuleSignal?.confidence, ruleReason: groupRuleSignal?.reason)
    }

    /// Builds the prescription snapshot representing the state BEFORE changes were applied.
    /// For accepted changes, we revert newValue → previousValue on the live prescription.
    /// For rejected/deferred, the live prescription already IS the old state.
    private static func buildPrescriptionSnapshot(group: OutcomeGroup) -> AIExercisePrescriptionSnapshot {
        let base = AIExercisePrescriptionSnapshot(from: group.prescription)

        // If any change was accepted, the live prescription has the new values baked in.
        // We need to revert those accepted changes to get the "before" state.
        let acceptedChanges = group.changes.filter { $0.decision == .accepted || $0.decision == .userOverride }
        guard !acceptedChanges.isEmpty else { return base }

        var snapshot = base
        for change in acceptedChanges {
            snapshot = revertChange(snapshot: snapshot, change: change)
        }
        return snapshot
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

    /// A group is "rejected mode" for AI if none of its changes were applied.
    /// We treat `accepted` and `userOverride` as applied; everything else as not applied.
    private static func isRejectedGroup(_ group: OutcomeGroup) -> Bool {
        !group.changes.contains { change in
            change.decision == .accepted || change.decision == .userOverride
        }
    }

    // MARK: - Helpers

    private static func formattedChangeValue(_ value: Double?, changeType: ChangeType) -> String? {
        guard let value else { return nil }

        let roundedInt = Int(value.rounded())

        switch changeType {
        case .increaseWeight, .decreaseWeight:
            return formatWeight(value)
        case .increaseReps, .decreaseReps,
             .increaseRepRangeLower, .decreaseRepRangeLower,
             .increaseRepRangeUpper, .decreaseRepRangeUpper,
             .increaseRepRangeTarget, .decreaseRepRangeTarget,
             .increaseRest, .decreaseRest,
             .increaseRestTimeSeconds, .decreaseRestTimeSeconds,
             .removeSet:
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
        case .changeRestTimeMode:
            if let mode = RestTimeMode(rawValue: roundedInt) {
                return mode.displayName
            }
            return String(roundedInt)
        }
    }

    private static func formatWeight(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }

    // MARK: - Revert Accepted Changes

    private static func revertChange(snapshot: AIExercisePrescriptionSnapshot, change: PrescriptionChange) -> AIExercisePrescriptionSnapshot {
        let oldValue = change.previousValue

        switch change.changeType {
        case .increaseWeight, .decreaseWeight:
            return withRevertedSet(snapshot: snapshot, change: change) { set in
                AISetPrescriptionSnapshot(index: set.index, setType: set.setType, targetWeight: oldValue ?? set.targetWeight, targetReps: set.targetReps, targetRest: set.targetRest)
            }
        case .increaseReps, .decreaseReps:
            return withRevertedSet(snapshot: snapshot, change: change) { set in
                AISetPrescriptionSnapshot(index: set.index, setType: set.setType, targetWeight: set.targetWeight, targetReps: oldValue.map { Int($0) } ?? set.targetReps, targetRest: set.targetRest)
            }
        case .increaseRest, .decreaseRest:
            return withRevertedSet(snapshot: snapshot, change: change) { set in
                AISetPrescriptionSnapshot(index: set.index, setType: set.setType, targetWeight: set.targetWeight, targetReps: set.targetReps, targetRest: oldValue.map { Int($0) } ?? set.targetRest)
            }
        case .changeSetType:
            return withRevertedSet(snapshot: snapshot, change: change) { set in
                let oldType = oldValue.flatMap { ExerciseSetType(rawValue: Int($0)) }.map { AIExerciseSetType(from: $0) } ?? set.setType
                return AISetPrescriptionSnapshot(index: set.index, setType: oldType, targetWeight: set.targetWeight, targetReps: set.targetReps, targetRest: set.targetRest)
            }
        case .changeRepRangeMode:
            let oldMode: AIRepRangeMode?
            if let raw = oldValue.map({ Int($0) }), let mode = RepRangeMode(rawValue: raw) {
                oldMode = (mode == .range) ? .range : (mode == .target) ? .target : nil
            } else {
                oldMode = snapshot.repRangeMode
            }
            return AIExercisePrescriptionSnapshot(exerciseName: snapshot.exerciseName, repRangeMode: oldMode, repRangeLower: snapshot.repRangeLower, repRangeUpper: snapshot.repRangeUpper, repRangeTarget: snapshot.repRangeTarget, restTimePolicy: snapshot.restTimePolicy, sets: snapshot.sets)
        case .changeRestTimeMode:
            let oldMode: AIRestTimeMode
            if let raw = oldValue.map({ Int($0) }), let mode = RestTimeMode(rawValue: raw) {
                oldMode = AIRestTimeMode(from: mode)
            } else {
                oldMode = snapshot.restTimePolicy.mode
            }
            let oldPolicy = AIRestTimePolicy(mode: oldMode, allSameSeconds: snapshot.restTimePolicy.allSameSeconds)
            return AIExercisePrescriptionSnapshot(exerciseName: snapshot.exerciseName, repRangeMode: snapshot.repRangeMode, repRangeLower: snapshot.repRangeLower, repRangeUpper: snapshot.repRangeUpper, repRangeTarget: snapshot.repRangeTarget, restTimePolicy: oldPolicy, sets: snapshot.sets)
        case .increaseRepRangeLower, .decreaseRepRangeLower:
            return AIExercisePrescriptionSnapshot(exerciseName: snapshot.exerciseName, repRangeMode: snapshot.repRangeMode, repRangeLower: oldValue.map { Int($0) }, repRangeUpper: snapshot.repRangeUpper, repRangeTarget: snapshot.repRangeTarget, restTimePolicy: snapshot.restTimePolicy, sets: snapshot.sets)
        case .increaseRepRangeUpper, .decreaseRepRangeUpper:
            return AIExercisePrescriptionSnapshot(exerciseName: snapshot.exerciseName, repRangeMode: snapshot.repRangeMode, repRangeLower: snapshot.repRangeLower, repRangeUpper: oldValue.map { Int($0) }, repRangeTarget: snapshot.repRangeTarget, restTimePolicy: snapshot.restTimePolicy, sets: snapshot.sets)
        case .increaseRepRangeTarget, .decreaseRepRangeTarget:
            return AIExercisePrescriptionSnapshot(exerciseName: snapshot.exerciseName, repRangeMode: snapshot.repRangeMode, repRangeLower: snapshot.repRangeLower, repRangeUpper: snapshot.repRangeUpper, repRangeTarget: oldValue.map { Int($0) }, restTimePolicy: snapshot.restTimePolicy, sets: snapshot.sets)
        case .increaseRestTimeSeconds, .decreaseRestTimeSeconds:
            let oldPolicy = AIRestTimePolicy(mode: snapshot.restTimePolicy.mode, allSameSeconds: oldValue.map { Int($0) } ?? snapshot.restTimePolicy.allSameSeconds)
            return AIExercisePrescriptionSnapshot(exerciseName: snapshot.exerciseName, repRangeMode: snapshot.repRangeMode, repRangeLower: snapshot.repRangeLower, repRangeUpper: snapshot.repRangeUpper, repRangeTarget: snapshot.repRangeTarget, restTimePolicy: oldPolicy, sets: snapshot.sets)
        case .removeSet:
            // Volume change — snapshot doesn't need structural revert, the set count is captured in previousValue/newValue.
            return snapshot
        }
    }

    private static func withRevertedSet(snapshot: AIExercisePrescriptionSnapshot, change: PrescriptionChange, transform: (AISetPrescriptionSnapshot) -> AISetPrescriptionSnapshot) -> AIExercisePrescriptionSnapshot {
        guard let targetIndex = change.targetSetPrescription?.index else { return snapshot }
        let sets = snapshot.sets.map { set in
            set.index == targetIndex ? transform(set) : set
        }
        return AIExercisePrescriptionSnapshot(exerciseName: snapshot.exerciseName, repRangeMode: snapshot.repRangeMode, repRangeLower: snapshot.repRangeLower, repRangeUpper: snapshot.repRangeUpper, repRangeTarget: snapshot.repRangeTarget, restTimePolicy: snapshot.restTimePolicy, sets: sets)
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

        if ai.outcome.outcome != ruleOutcome.outcome && ai.confidence >= 0.5 {
            return ResolvedOutcome(outcome: ai.outcome.outcome, reason: "[AI override] \(ai.reason)")
        }

        return ResolvedOutcome(outcome: ruleOutcome.outcome, reason: "[Rules] \(ruleOutcome.reason)")
    }

    private static func applyOutcomeIfPossible(change: PrescriptionChange, ruleResults: [UUID: OutcomeSignal?], aiOutput: AIOutcomeInferenceOutput?, workout: WorkoutSession) {
        guard change.outcome == .pending, change.evaluatedAt == nil else { return }
        let ruleSignal = ruleResults[change.id] ?? nil
        guard let resolved = mergeOutcome(rule: ruleSignal, ai: aiOutput) else { return }
        applyResolvedOutcome(resolved, to: change, workout: workout)
    }

    private static func applyResolvedOutcome(_ resolved: ResolvedOutcome, to change: PrescriptionChange, workout: WorkoutSession) {
        change.outcome = resolved.outcome
        change.outcomeReason = resolved.reason
        change.evaluatedAt = Date()
        change.evaluatedInSession = workout
    }
}

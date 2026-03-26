import Foundation
import FoundationModels

struct AIOutcomeInferrer {
    /// Evaluates outcome for groups that were accepted/applied in the plan.
    static func inferApplied(input: AIOutcomeGroupInput) async -> AIOutcomeInferenceOutput? {
        await infer(input: input, instructions: appliedInstructions, promptHeader: "Evaluate this accepted or applied change group using the current workout.")
    }

    /// Evaluates outcome for groups that were rejected/not applied in the plan.
    static func inferRejected(input: AIOutcomeGroupInput) async -> AIOutcomeInferenceOutput? {
        await infer(input: input, instructions: rejectedInstructions, promptHeader: "Evaluate this rejected change group and decide whether the athlete followed it anyway.")
    }

    /// Backward-compatible convenience entry point.
    static func infer(input: AIOutcomeGroupInput, rejected: Bool = false) async -> AIOutcomeInferenceOutput? {
        rejected ? await inferRejected(input: input) : await inferApplied(input: input)
    }

    private static func infer(input: AIOutcomeGroupInput, instructions: String, promptHeader: String) async -> AIOutcomeInferenceOutput? {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return nil }

        do {
            let session = LanguageModelSession(instructions: instructions)
            let prompt = Prompt {
                promptHeader
                ""
                input
            }
            let response = try await session.respond(to: prompt, generating: AIOutcomeInferenceOutput.self)
            return validate(response.content)
        } catch { return nil }
    }

    private static var appliedInstructions: String {
        """
        Return one AIOutcome, one confidence from 0 to 1, and one short evidence sentence.
        Compare actualPerformance to the suggested targets, with triggerPerformance as the baseline.
        Use categoryGuidance as the main task-specific lens.
        Use triggerTargetSetIndex or originalTargetSetIndex instead of raw set order when possible.

        Outcome meanings:
        - Good: the athlete attempted the new targets and landed in a reasonable zone.
        - Too Aggressive: the athlete attempted the new targets and clearly struggled.
        - Too Easy: the athlete attempted the new targets and clearly exceeded the targets.
        - Insufficient: the athlete followed the change, but it did not meaningfully solve the problem or improve the downstream set enough.
        - Ignored: the athlete stayed close to the old targets or evidence of attempting the change is weak.

        Guidelines:
        - For set-level changes, judge the targeted slot first.
        - Use postWorkoutEffort, preWorkoutFeeling, and tookPreWorkout as supporting context hints, not ground truth.
        - High postWorkoutEffort strengthens negative evidence.
        - Sick or tired pre-workout context weakens negative evidence from one bad session.
        - Took pre-workout and still struggled slightly strengthens negative evidence.
        - Context should not override strong direct performance evidence by itself.
        - Weight within one normal increment, reps within 1, and rest within 15 seconds usually count as attempted.
        - Use trainingStyle to focus on the sets that matter most.
        - In Top Set Then Backoffs, weigh the heavy top sets more than the lighter backoff sets.
        - Use ruleOutcome, ruleConfidence, and ruleReason as hints, not ground truth.
        - If evidence is ambiguous, prefer Ignored or the rule hint.
        - Keep the reason to one short sentence and use high confidence only when evidence is clear.
        """
    }

    private static var rejectedInstructions: String {
        """
        Return one AIOutcome, one confidence from 0 to 1, and one short evidence sentence.
        Decide whether the athlete effectively followed the suggested targets anyway, or whether the missed change was validated by performance.
        Use categoryGuidance as the main task-specific lens.
        Use triggerTargetSetIndex or originalTargetSetIndex instead of raw set order when possible.

        Outcome meanings:
        - Good: they substantially matched the suggested targets anyway, or performance clearly validates a safety-oriented suggestion they skipped.
        - Insufficient: they effectively followed the suggested targets, but the result still did not solve the problem.
        - Ignored: default when they stayed near the old targets or evidence is mixed.
        - Too Aggressive: they effectively followed the suggested targets and clearly struggled.
        - Too Easy: they effectively followed the suggested targets and clearly exceeded them.

        Guidelines:
        - Compare actualPerformance to the suggested targets, with triggerPerformance as baseline.
        - Use postWorkoutEffort, preWorkoutFeeling, and tookPreWorkout as supporting context hints, not ground truth.
        - High postWorkoutEffort strengthens negative evidence.
        - Sick or tired pre-workout context weakens negative evidence from one bad session.
        - Took pre-workout and still struggled slightly strengthens negative evidence.
        - Context should not override strong direct performance evidence by itself.
        - Weight within one normal increment, reps within 1, and rest within 15 seconds can count as following.
        - Use trainingStyle to focus on the sets that matter most.
        - Use ruleOutcome, ruleConfidence, and ruleReason as hints, not ground truth.
        - If evidence is ambiguous, prefer Ignored with lower confidence.
        - Keep the reason to one short sentence.
        """
    }

    static func validate(_ output: AIOutcomeInferenceOutput) -> AIOutcomeInferenceOutput? {
        guard (0.0...1.0).contains(output.confidence) else { return nil }

        let trimmedReason = output.reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedReason.isEmpty, trimmedReason.count <= 160, !trimmedReason.contains("\n") else { return nil }

        return AIOutcomeInferenceOutput(outcome: output.outcome, confidence: output.confidence, reason: trimmedReason)
    }
}

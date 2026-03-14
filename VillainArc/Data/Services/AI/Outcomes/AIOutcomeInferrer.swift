import Foundation
import FoundationModels

struct AIOutcomeInferrer {
    /// Evaluates outcome for groups that were accepted/applied in the plan.
    static func inferApplied(input: AIOutcomeGroupInput) async -> AIOutcomeInferenceOutput? {
        await infer(
            input: input,
            instructions: appliedInstructions,
            promptHeader: "Evaluate the outcome of these accepted or applied prescription changes based on the user's actual performance."
        )
    }

    /// Evaluates outcome for groups that were rejected/not applied in the plan.
    static func inferRejected(input: AIOutcomeGroupInput) async -> AIOutcomeInferenceOutput? {
        await infer(
            input: input,
            instructions: rejectedInstructions,
            promptHeader: "These prescription changes were suggested but not applied. Determine whether the user followed them anyway."
        )
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
            let response = try await session.respond(
                to: prompt,
                generating: AIOutcomeInferenceOutput.self
            )
            return validate(response.content)
        } catch {
            return nil
        }
    }

    private static var appliedInstructions: String {
        """
        Evaluate one accepted or applied suggestion group and return one AIOutcome.
        Compare actualPerformance to the suggested targets, using triggerPerformance as the baseline.
        Use targetSetIndex or linkedTargetSetIndex over raw set order when possible.

        Outcome meanings:
        - Good: the athlete attempted the new targets and landed in a reasonable zone.
        - Too Aggressive: the athlete attempted the new targets and clearly struggled.
        - Too Easy: the athlete attempted the new targets and clearly exceeded the targets.
        - Ignored: the athlete stayed close to the old targets or evidence of attempting the change is weak.

        Guidelines:
        - Use category and categoryGuidance to choose the right evaluation lens before looking at individual changes.
        - For set-level changes, judge the targeted slot first.
        - For exercise-level rep-range changes, judge the working-set distribution against the new range or target.
        - For warmup calibration, judge adherence and whether the set still behaves like a warmup relative to the main working or top sets.
        - Weight within one normal increment, reps within 1, and rest within 15 seconds usually count as attempted.
        - For rest changes, matching the suggested rest alone is not enough; prefer Good only if performance also improved.
        - Use trainingStyle to focus on the sets that matter most.
        - In Top Set Then Backoffs, weigh the heavy top sets more than the lighter backoff sets.
        - Use ruleOutcome, ruleConfidence, and ruleReason as hints, not ground truth.
        - If evidence is ambiguous, prefer Ignored or the rule hint.
        - Keep reason brief. Use high confidence only when evidence is clear.
        """
    }

    private static var rejectedInstructions: String {
        """
        Evaluate one rejected suggestion group and return one AIOutcome.
        Decide whether the athlete effectively followed the suggested targets anyway, or whether the missed change was validated by performance.
        Use targetSetIndex or linkedTargetSetIndex over raw set order when possible.

        Outcome meanings:
        - Good: they substantially matched the suggested targets anyway, or performance clearly validates a safety-oriented suggestion they skipped.
        - Ignored: default when they stayed near the old targets or evidence is mixed.
        - Too Aggressive: they effectively followed the suggested targets and clearly struggled.
        - Too Easy: they effectively followed the suggested targets and clearly exceeded them.

        Guidelines:
        - Use category and categoryGuidance to choose the right evaluation lens before looking at individual changes.
        - Compare actualPerformance to the suggested targets, with triggerPerformance as baseline.
        - Weight within one normal increment, reps within 1, and rest within 15 seconds can count as following.
        - For warmup calibration, judge whether they effectively used the suggested warmup load while the set still behaved like a warmup.
        - For rest changes, matching rest alone is not enough; look for better performance too.
        - Use trainingStyle to focus on the sets that matter most.
        - Use ruleOutcome, ruleConfidence, and ruleReason as hints, not ground truth.
        - If evidence is ambiguous, prefer Ignored with lower confidence.
        - Keep reason brief.
        """
    }

    private static func validate(_ output: AIOutcomeInferenceOutput) -> AIOutcomeInferenceOutput? {
        let clampedConfidence = min(1.0, max(0.0, output.confidence))
        guard !output.reason.isEmpty else { return nil }
        return AIOutcomeInferenceOutput(outcome: output.outcome, confidence: clampedConfidence, reason: output.reason)
    }
}

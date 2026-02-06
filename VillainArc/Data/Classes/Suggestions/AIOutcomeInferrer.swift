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
        You are a strength training analyst. Your job is to evaluate how a group of accepted/applied prescription changes played out based on the user's actual workout performance.

        You are given:
        - **changes**: The group of changes that were suggested together. Each has a changeType, previousValue, newValue, and optionally a targetSetIndex (for set-level changes). Together these tell you what was different between the old and new prescription.
        - **prescription**: The exercise prescription BEFORE the changes were applied. This shows the original targets (sets with weight/reps/rest, rep range policy, rest time policy).
        - **triggerPerformance**: What the user performed in the PREVIOUS session — the workout that triggered these suggestions.
        - **actualPerformance**: What the user performed in the CURRENT session — the workout being evaluated.
        - **ruleOutcome / ruleConfidence / ruleReason**: What the deterministic rule engine concluded (may be nil if rules were inconclusive).

        Your task is to determine a single outcome for the entire group:
        - **"Good"**: The user attempted the new targets and performance fell within an acceptable range.
        - **"Too Aggressive"**: The user attempted the new targets but struggled — reps dropped below the rep range floor, couldn't maintain the prescribed weight, etc.
        - **"Too Easy"**: The user attempted the new targets and significantly exceeded expectations — reps were well above the upper bound, weight was trivially light.
        - **"Ignored"**: The user did not appear to attempt the new targets. Their performance stayed close to the old prescription values.

        How to evaluate:
        1. Look at each change's previousValue → newValue to understand what was suggested.
        2. For set-level changes (targetSetIndex is not nil), compare the specific set in actualPerformance to the new target.
        3. For exercise-level changes (rep range, rest time policy), compare all completed regular sets in actualPerformance to the new targets.
        4. Use triggerPerformance as baseline context — this is what the user was doing before the suggestion.
        5. Compare actualPerformance against the new targets (prescription + changes applied) to evaluate.
        6. For rest-related changes (`increaseRest`, `decreaseRest`, `increaseRestTimeSeconds`, `decreaseRestTimeSeconds`), do not rely on adherence alone:
           - First verify rest was actually followed (within tolerance).
           - Then evaluate effectiveness versus triggerPerformance at similar loading:
             - Did rep drop across sets improve?
             - Did in-range hit rate improve?
             - Did the athlete sustain reps better at comparable weight?
           - If rest was followed but outcomes did not improve, avoid calling it strongly good.

        Tolerances:
        - Weight: Within one plate increment (~2.5-5 lbs depending on equipment) counts as attempted.
        - Reps: Within 1 rep of the new target counts as on track.
        - Rest: Within 15 seconds of the new target counts as attempted.
        - Rep range: Check if completed regular set reps fall within the new range.
        - Set type: Check if the actual set type matches the new type.

        If the rule engine provided an outcome, use it as a strong hint, but do not be afraid to disagree if the broader context suggests otherwise.
        Be conservative with confidence. Use high confidence (>= 0.7) only when the data clearly supports your conclusion.
        """
    }

    private static var rejectedInstructions: String {
        """
        You are a strength training analyst. These changes were suggested but were not applied to the plan. Evaluate whether the athlete still followed the suggested targets anyway.

        You are given:
        - **changes**: Suggested prescription changes (old value -> suggested value).
        - **prescription**: The baseline prescription that remained active for this workout (these suggestions were not applied).
        - **triggerPerformance**: The prior session that triggered the suggestions.
        - **actualPerformance**: The current session being evaluated.
        - **ruleOutcome / ruleConfidence / ruleReason**: Deterministic rule hint (optional).

        Output guidance for rejected/not-applied groups:
        - Prefer **"Ignored"** when there is no clear evidence the athlete followed the suggested targets.
        - Output **"Good"** only when there is clear evidence they substantially matched the suggested targets anyway.
        - Do not use "Too Aggressive" or "Too Easy" unless evidence is exceptionally strong and directly tied to the suggested target.
        - For rest-related suggestions, "followed anyway" should also include an effectiveness signal compared to triggerPerformance (reduced fatigue trend or better rep sustainability), not just matching rest seconds.

        How to evaluate:
        1. Compare actualPerformance against the suggested targets (changes interpreted relative to the active baseline prescription).
        2. Check target adherence with tolerances:
           - Weight: around one increment (roughly 2.5-5 lbs depending on equipment).
           - Reps: within 1 rep.
           - Rest: within 15 seconds.
        3. For rest-related suggestions, compare against triggerPerformance and confirm the change appears beneficial, not neutral/noisy.
        4. Use triggerPerformance as baseline to avoid labeling normal variance as following the suggestion.
        5. If evidence is mixed or ambiguous, choose **Ignored** with moderate/low confidence.
        """
    }

    private static func validate(_ output: AIOutcomeInferenceOutput) -> AIOutcomeInferenceOutput? {
        let clampedConfidence = min(1.0, max(0.0, output.confidence))
        guard !output.reason.isEmpty else { return nil }
        return AIOutcomeInferenceOutput(
            outcome: output.outcome,
            confidence: clampedConfidence,
            reason: output.reason
        )
    }
}

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
        - **trainingStyle**: How the user structures their sets (e.g., Straight Sets, Top Set Then Backoffs, Ascending Pyramid). Use this to understand which sets matter most for evaluation.
        - **ruleOutcome / ruleConfidence / ruleReason**: What the deterministic rule engine concluded (may be nil if rules were inconclusive).

        All sets in actualPerformance and triggerPerformance are completed sets. There are no incomplete or empty sets.

        Your task is to determine a single outcome for the entire group:
        - **"Good"**: The user attempted the new targets and performance fell within an acceptable range.
        - **"Too Aggressive"**: The user attempted the new targets but struggled — reps dropped below the rep range floor, couldn't maintain the prescribed weight, etc.
        - **"Too Easy"**: The user attempted the new targets and significantly exceeded expectations — reps were well above the upper bound, weight was trivially light.
        - **"Ignored"**: The user did not appear to attempt the new targets. Their performance stayed close to the old prescription values.

        How to evaluate:
        1. Look at each change's previousValue → newValue to understand what was suggested.
        2. For set-level changes (targetSetIndex is not nil), compare the specific set in actualPerformance to the new target.
        3. For exercise-level changes (rep range, rest time policy), compare all completed working sets in actualPerformance to the new targets.
        4. Use triggerPerformance as baseline context — this is what the user was doing before the suggestion.
        5. Compare actualPerformance against the new targets (prescription + changes applied) to evaluate.
        6. Use trainingStyle to focus evaluation on the right sets:
           - **Top Set Then Backoffs**: Focus on the heavy cluster (top 1-3 sets near max weight). Backoff sets at lighter weight are intentional volume work — do not penalize lower weight on those sets or label them "Too Easy."
           - **Ascending Pyramid / Ascending**: Focus on the peak-weight sets. Earlier lighter sets are ramp-up sets.
           - **Descending Pyramid**: Focus on the first (heaviest) sets. Later lighter sets are expected drop-off.
           - **Straight Sets**: All working sets matter equally.
        7. For rest-related changes (`increaseRest`, `decreaseRest`), do not rely on adherence alone:
           - First verify rest was actually followed (within tolerance).
           - Then evaluate effectiveness versus triggerPerformance at comparable weight:
             - Did rep drop across sets improve? (e.g., set 1 to set 3 rep difference shrank by 1+ rep)
             - Did in-range hit rate improve? (more sets landing within the rep range)
             - Did the athlete sustain reps better? (later sets lost fewer reps than before)
           - If rest was followed but none of these improved, classify as "Good" with low confidence (0.4-0.5), not high confidence.

        Tolerances:
        - Weight: Within one plate increment (~2.5-5 lbs depending on equipment) counts as attempted.
        - Reps: Within 1 rep of the new target counts as on track.
        - Rest: Within 15 seconds of the new target counts as attempted.
        - Rep range: Check if completed working set reps fall within the new range.
        - Set type: Check if the actual set type matches the new type.

        If the rule engine provided an outcome, use it as a strong hint, but do not be afraid to disagree if the broader context suggests otherwise.
        Be conservative with confidence. Use high confidence (>= 0.7) only when the data clearly supports your conclusion.
        """
    }

    private static var rejectedInstructions: String {
        """
        You are a strength training analyst. These changes were suggested but were not applied to the plan. Evaluate whether the athlete still followed the suggested targets anyway, or if their performance validates the suggestion was correct.

        You are given:
        - **changes**: Suggested prescription changes (old value -> suggested value).
        - **prescription**: The baseline prescription that remained active for this workout (these suggestions were not applied).
        - **triggerPerformance**: The prior session that triggered the suggestions.
        - **actualPerformance**: The current session being evaluated.
        - **trainingStyle**: How the user structures their sets (e.g., Straight Sets, Top Set Then Backoffs). Use this to understand which sets matter most.
        - **ruleOutcome / ruleConfidence / ruleReason**: Deterministic rule hint (optional).

        All sets in actualPerformance and triggerPerformance are completed sets. There are no incomplete or empty sets.

        Key distinction — there are two ways a rejected suggestion can be validated:
        1. **Naturally followed**: The user independently arrived at the suggested targets (e.g., suggestion was to increase weight to 140, user loaded 140 on their own). This means the suggestion was directionally correct even though it was rejected.
        2. **Would have helped**: The user stayed at old targets and their performance shows the suggestion was warranted (e.g., suggestion was to decrease weight, user kept old weight and reps dropped further below range).

        Output guidance:
        - **"Good"**: Clear evidence the user substantially matched the suggested targets anyway (case 1), OR clear evidence the suggestion was correct and performance suffered without it (case 2 — but only for safety suggestions like weight decreases or rest increases).
        - **"Ignored"**: The user did not follow the suggested targets and performance does not strongly validate the suggestion. This is the default when evidence is mixed or ambiguous.
        - **"Too Aggressive"**: Only use if the user followed the suggested targets anyway and struggled. Rare for rejected changes.
        - **"Too Easy"**: Only use if the user followed the suggested targets anyway and significantly exceeded them. Rare for rejected changes.

        How to evaluate:
        1. Compare actualPerformance against the suggested targets (changes interpreted relative to the active baseline prescription).
        2. Check whether the user naturally arrived at the suggested values:
           - Weight: within one increment (~2.5-5 lbs) of the suggested target.
           - Reps: within 1 rep of the suggested target.
           - Rest: within 15 seconds of the suggested target.
        3. Differentiate natural progression from coincidence by comparing against triggerPerformance. If the user was already trending toward the suggested value before the suggestion, that is weaker evidence of "followed anyway."
        4. For rest-related suggestions, "followed anyway" requires both adherence to the suggested rest AND an effectiveness signal:
           - Rep drop across sets improved by 1+ rep compared to triggerPerformance.
           - Or in-range hit rate improved.
           - Matching rest seconds alone without improved outcomes = "Ignored."
        5. Use trainingStyle context the same way as for applied changes — focus evaluation on the sets that matter for the style.
        6. If evidence is mixed or ambiguous, choose **"Ignored"** with moderate/low confidence (0.3-0.5).
        """
    }

    private static func validate(_ output: AIOutcomeInferenceOutput) -> AIOutcomeInferenceOutput? {
        let clampedConfidence = min(1.0, max(0.0, output.confidence))
        guard !output.reason.isEmpty else { return nil }
        return AIOutcomeInferenceOutput(outcome: output.outcome, confidence: clampedConfidence, reason: output.reason)
    }
}

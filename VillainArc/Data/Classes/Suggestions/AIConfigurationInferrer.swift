import Foundation
import FoundationModels

struct AIConfigurationInferrer {
    /// Asks the on-device model to classify rep range and training style for an exercise.
    /// Returns nil if the model is unavailable or inference fails.
    static func infer(exerciseName: String, catalogID: String, primaryMuscle: String, performance: AIExercisePerformanceSnapshot) async -> AIInferenceOutput? {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return nil }

        let tools: [any Tool] = [
            RecentExercisePerformancesTool()
        ]

        let input = AIInferenceInput(
            catalogID: catalogID,
            exerciseName: exerciseName,
            primaryMuscle: primaryMuscle,
            performance: performance
        )

        do {
            let session = LanguageModelSession(tools: tools, instructions: instructions)
            let prompt = Prompt {
                "Classify the training style and rep range for this exercise based on the performance data."
                ""
                input
            }
            let response = try await session.respond(
                to: prompt,
                generating: AIInferenceOutput.self
            )
            return validate(response.content)
        } catch {
            return nil
        }
    }

    private static var instructions: String {
        """
        You are a strength training analyst. Your job is to classify two things about an exercise based on performance data:

        1. **Rep Range Classification** — Determine the rep range mode and values the user is training in.
           - "Range" mode: the user trains within a consistent rep range (e.g., 8-12 reps). Provide lowerRange and upperRange.
           - "Target" mode: the user consistently hits the same rep count (e.g., always 5 reps). Provide targetReps.
           - IMPORTANT: You must ONLY classify as "Range" or "Target". Never suggest any other mode.
           - If you cannot confidently determine the rep range, return null for repRangeClassification.
           - Look at rep counts across working sets (not warmups) for consistency.

        2. **Training Style Classification** — Determine how the user structures their sets by weight pattern.
           - "Straight Sets": All sets at roughly the same weight (within ~10%).
           - "Ascending Pyramid": Weight increases then decreases, peak weight is in the middle sets.
           - "Descending Pyramid": Heaviest set first, weight drops each subsequent set.
           - "Ascending": Weights ramp up set by set, heaviest set is the last one.
           - "Top Set Then Backoffs": 1-3 heavy sets at similar weight, then lighter backoff sets (or warmups leading to top sets). Common pattern: warmup → warmup → 2-3 heavy working sets.
           - "Unknown": If the pattern doesn't clearly match any of the above.
           - Focus on completed sets. Warmup sets ramp up to working weight; working sets are the heavy ones.

        Tools available:
        - getRecentExercisePerformances(catalogID: String, limit: Int)
          Returns last N detailed performances (max 5, sorted recent-first).
          Use this if the current session data alone is ambiguous and you need more sessions to identify a pattern.
          Start with limit=2-3 for efficiency.

        Be conservative — only classify when the data clearly supports it. Return null fields when uncertain.
        """
    }

    private static func validate(_ output: AIInferenceOutput) -> AIInferenceOutput? {
        // Validate rep range classification has sensible values.
        var repRange = output.repRangeClassification
        if let classification = repRange {
            switch classification.mode {
            case .range:
                if classification.lowerRange <= 0 || classification.upperRange <= 0
                    || classification.lowerRange >= classification.upperRange {
                    repRange = nil
                }
            case .target:
                if classification.targetReps <= 0 {
                    repRange = nil
                }
            }
        }

        let style = output.trainingStyleClassification

        // If both are nil after validation, there's nothing useful.
        guard repRange != nil || style != nil else { return nil }

        return AIInferenceOutput(
            repRangeClassification: repRange,
            trainingStyleClassification: style
        )
    }
}

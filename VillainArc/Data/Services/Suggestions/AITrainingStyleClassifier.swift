import Foundation
import FoundationModels

struct AITrainingStyleClassifier {
    /// Asks the on-device model to classify training style for an exercise.
    /// Returns nil if the model is unavailable or inference fails.
    static func infer(exerciseName: String, catalogID: String, primaryMuscle: String, performance: AIExercisePerformanceSnapshot) async -> AIInferenceOutput? {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return nil }

        let tools: [any Tool] = [
            RecentExercisePerformancesTool()
        ]

        let input = AIInferenceInput(catalogID: catalogID, exerciseName: exerciseName, primaryMuscle: primaryMuscle, performance: performance)

        do {
            let session = LanguageModelSession(tools: tools, instructions: instructions)
            let prompt = Prompt {
                "Classify the training style for this exercise based on the performance data."
                ""
                input
            }
            let response = try await session.respond(to: prompt, generating: AIInferenceOutput.self)
            return validate(response.content)
        } catch {
            return nil
        }
    }

    private static var instructions: String {
        """
        You are a strength training analyst. Your job is to classify the training style of an exercise based on performance data.

        **Training Style Classification** — Determine how the user structures their sets by analyzing the weight pattern across completed sets.
           - "Straight Sets": All working sets at roughly the same weight (within ~10%). The most common style.
           - "Ascending Pyramid": Weight increases then decreases across sets, with peak weight in the middle sets (not first or last).
           - "Descending Pyramid": Heaviest set is first, weight drops each subsequent set.
           - "Ascending": Weights ramp up set by set monotonically, heaviest set is the last one.
           - "Top Set Then Backoffs": 1-3 heavy sets clustered near max weight, with remaining sets clearly lighter (at least 20% lighter). Common patterns include: warmup → warmup → 2-3 heavy working sets, or heavy working sets followed by lighter backoff volume.
           - "Unknown": If the pattern doesn't clearly match any of the above, or if there are fewer than 3 sets making classification unreliable.

        Important classification guidelines:
        - Pay attention to set type labels when present. Sets labeled "Warm Up Set" are warmups regardless of weight. Sets labeled "Working Set" are the main work sets. Do not count warmup sets when determining the weight pattern of working sets.
        - If all sets are labeled "Working Set" and weights are similar (~10%), that is Straight Sets — even if the first set is slightly lighter.
        - A session with 3 sets at the same weight labeled as working sets, preceded by 1-2 lighter warmup sets, is Straight Sets (not Ascending or Top Set Then Backoffs).
        - Top Set Then Backoffs requires a clear split: heavy cluster AND distinctly lighter sets. A gradual taper is more likely Descending Pyramid.
        - When only 1-2 sets exist, return "Unknown" — there is not enough data to classify.

        Tools available:
        - getRecentExercisePerformances(catalogID: String, limit: Int)
          Returns last N detailed performances (max 5, sorted recent-first).
          Use this if the current session data alone is ambiguous and you need more sessions to identify a consistent pattern.
          Start with limit=2-3 for efficiency.

        Be conservative — only classify when the data clearly supports it. If the style returned by the tool is nil, the classification was not possible.
        """
    }

    private static func validate(_ output: AIInferenceOutput) -> AIInferenceOutput? {
        // If training style is nil, there's nothing useful.
        guard output.trainingStyleClassification != nil else { return nil }
        return output
    }
}

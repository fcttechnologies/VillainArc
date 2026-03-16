import Foundation
import FoundationModels

struct AITrainingStyleClassifier {
    /// Asks the on-device model to classify training style for an exercise.
    /// Returns nil if the model is unavailable or inference fails.
    static func infer(performance: AIExercisePerformanceSnapshot) async -> AIInferenceOutput? {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return nil }

        let tools: [any Tool] = [RecentExercisePerformancesTool()]

        let input = AIInferenceInput(performance: performance)

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
        Classify the exercise into one TrainingStyle value.
        Use the current session first.
        Explicit warmup sets are strong evidence that the real training style starts after them.
        Explicit drop sets are strong evidence of a fatigue cluster and usually should not drive normal progression.
        If working-set evidence is clear, ignore warmup and drop sets when deciding the base style.

        Definitions:
        - Straight Sets: working sets stay at similar weight, about within 10%.
        - Ascending Pyramid: weight rises, then falls, with the heaviest set in the middle.
        - Descending Pyramid: the heaviest set is first, then weight drops.
        - Ascending: weight rises monotonically and the heaviest set is last.
        - Feeder Ramp: lighter lead-in working sets climb into a flat top cluster of 2-3 heavy sets at the end.
        - Reverse Pyramid: the first working set is the heaviest, then later working sets form a lighter cluster rather than a long smooth descent.
        - Top Set Then Backoffs: 1-3 heavy top sets plus clearly lighter backoff sets, about 20% lighter.
        - Rest Pause / Cluster: same or near-same load repeated with very short rest and falling reps across mini-sets.
        - Drop Set Cluster: mostly explicit drop sets, usually with descending load and fatigue-driven continuation work.
        - Unknown: fewer than 3 useful sets or mixed evidence.

        Use getRecentExercisePerformances only if the current session is ambiguous.
        Prefer the narrowest clear style that matches the working-set structure.
        Be conservative and return Unknown when the evidence is weak or when two styles conflict closely.
        """
    }

    private static func validate(_ output: AIInferenceOutput) -> AIInferenceOutput? {
        // If training style is nil, there's nothing useful.
        guard output.trainingStyleClassification != nil else { return nil }
        return output
    }
}

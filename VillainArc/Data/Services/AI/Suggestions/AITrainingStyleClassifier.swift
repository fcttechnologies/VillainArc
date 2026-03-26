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
                "Classify the training style for this workout."
                ""
                input
            }
            let response = try await session.respond(to: prompt, generating: AIInferenceOutput.self)
            return validate(response.content)
        } catch { return nil }
    }

    private static var instructions: String {
        """
        Return one TrainingStyle and a confidence from 0 to 1.
        Use the current workout first. Use getRecentExercisePerformances only if it is ambiguous.
        Focus on working-set structure. Warmups are lead-ins. Drop sets usually do not define the base style.
        Be conservative. Return Unknown when evidence is weak or closely mixed.

        Style cues:
        - Straight Sets: working loads stay close.
        - Ascending Pyramid: load rises, then falls.
        - Descending Pyramid: heaviest set is first, then load falls.
        - Ascending: load rises and the heaviest set is last.
        - Feeder Ramp: lighter lead-in working sets build into a flat heavy cluster.
        - Reverse Pyramid: first working set is heaviest, then a lighter cluster follows.
        - Top Set Then Backoffs: 1-3 heavy top sets followed by clearly lighter backoffs.
        - Rest Pause / Cluster: same or near-same load with very short rest and falling reps.
        - Drop Set Cluster: mostly explicit drop sets with descending load.
        - Unknown: too few useful sets or mixed evidence.
        """
    }

    static func validate(_ output: AIInferenceOutput) -> AIInferenceOutput? {
        guard output.trainingStyleClassification != nil else { return nil }
        let clampedConfidence = min(1.0, max(0.0, output.confidence))
        guard clampedConfidence == output.confidence else { return nil }
        return AIInferenceOutput(trainingStyleClassification: output.trainingStyleClassification, confidence: clampedConfidence)
    }
}

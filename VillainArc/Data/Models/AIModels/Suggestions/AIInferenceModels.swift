import Foundation
import FoundationModels

@Generable
struct AIInferenceInput {
    @Guide(description: "Current performance.")
    let performance: AIExercisePerformanceSnapshot
}

@Generable
struct AIInferenceOutput {
    @Guide(description: "Training style.")
    let trainingStyleClassification: TrainingStyle?
}

import Foundation
import FoundationModels

@Generable
struct AIInferenceInput {
    @Guide(description: "Current workout.")
    let performance: AIExercisePerformanceSnapshot
}

@Generable
struct AIInferenceOutput {
    @Guide(description: "Training style.")
    let trainingStyleClassification: TrainingStyle?
    @Guide(description: "Confidence 0 to 1.", .range(0.0 ... 1.0))
    let confidence: Double
}

import Foundation
import FoundationModels

@Generable
struct AIInferenceInput {
    @Guide(description: "Current exercise performance.")
    let performance: AIExercisePerformanceSnapshot
}

@Generable
struct AIInferenceOutput {
    @Guide(description: "Classified training style. Nil if unable to determine.")
    let trainingStyleClassification: TrainingStyle?
}

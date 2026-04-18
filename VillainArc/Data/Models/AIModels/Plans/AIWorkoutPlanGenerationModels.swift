import Foundation
import FoundationModels

@Generable
struct AIWorkoutPlanGeneration {
    @Guide(description: "A short workout plan title.")
    let title: String

    @Guide(description: "The exercises in the plan.", .minimumCount(1), .maximumCount(12))
    let exercises: [AIWorkoutPlanExercise]
}

@Generable
struct AIWorkoutPlanExercise {
    @Guide(description: "An exercise identity from the existing catalog. Use the exercise search tool so the catalogID, name, muscles, and equipment match the real exercise.")
    let exercise: AIExerciseIdentitySnapshot

    @Guide(description: "Rep target configuration for this exercise.")
    let repRange: AIRepRangeSnapshot?

    @Guide(description: "How many working sets this exercise should have.", .range(1...8))
    let setCount: Int
}

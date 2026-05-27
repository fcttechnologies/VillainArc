import Foundation
import FoundationModels

@Generable
struct AIGeneratedPlan {
    @Guide(description: "Short, memorable plan name. 1–4 words.")
    let name: String

    @Guide(description: "One sentence summarizing the plan's training intent.")
    let summary: String

    @Guide(description: "Number of training days per week.", .range(1...6))
    let daysPerWeek: Int

    @Guide(description: "Per-training-day entries. Order matters: first day is Day 1 of the week.", .count(1...6))
    let days: [AIGeneratedPlanDay]
}

@Generable
struct AIGeneratedPlanDay {
    @Guide(description: "Short label for the day. Examples: Push, Pull, Legs, Upper A, Lower B, Full Body.")
    let name: String

    @Guide(description: "Major muscle groups this day targets. Pick from the Muscle enum.")
    let muscleGroups: [Muscle]

    @Guide(description: "One short coaching note for the day.")
    let notes: String

    @Guide(description: "Exercises in execution order. Compounds first, isolation last.", .count(3...8))
    let exercises: [AIGeneratedPlanExercise]
}

@Generable
struct AIGeneratedPlanExercise {
    @Guide(description: "Common gym name of the exercise. Use familiar names like Bench Press, Squat, Romanian Deadlift, Lat Pulldown.")
    let exerciseName: String

    @Guide(description: "Equipment used. This helps disambiguate exercises with the same name.")
    let equipment: EquipmentType

    @Guide(description: "Number of working sets.", .range(1...8))
    let targetSets: Int

    @Guide(description: "Lower bound of the rep range.", .range(1...30))
    let repsLow: Int

    @Guide(description: "Upper bound of the rep range. Use the same value as repsLow for fixed target reps.", .range(1...30))
    let repsHigh: Int

    @Guide(description: "Rest seconds between sets.", .range(30...300))
    let restSeconds: Int

    @Guide(description: "Target RPE on a 0–10 scale. Use 0 to leave unset.", .range(0...10))
    let rpe: Int
}

// MARK: - Materialized result

/// What the AI generator returns to the UI layer. Holds the resolved plan plus any exercise names
/// that could not be matched to the catalog (surfaced as a small warning).
struct AIGeneratedPlanResult {
    let name: String
    let summary: String
    let daysPerWeek: Int
    let days: [AIGeneratedPlanDayResult]
    let unresolvedExerciseNames: [String]

    var allTrainingDays: [AIGeneratedPlanDayResult] { days }
}

struct AIGeneratedPlanDayResult {
    let name: String
    let muscleGroups: [Muscle]
    let notes: String
    let exercises: [AIGeneratedPlanExerciseResult]
}

struct AIGeneratedPlanExerciseResult {
    /// Resolved catalog ID after fuzzy matching the AI's `exerciseName` against the catalog.
    let catalogID: String
    let originalAIName: String
    let sets: Int
    let repsLow: Int
    let repsHigh: Int
    let restSeconds: Int
    let rpe: Int
}

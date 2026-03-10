import Testing
@testable import VillainArc

struct ExerciseEntitySearchTests {
    @Test @MainActor
    func systemAlternateNamesIncludeEquipmentPrefixedVariants() {
        let exercise = Exercise(from: ExerciseCatalog.byID["barbell_incline_bench_press"]!)

        #expect(exercise.systemAlternateNames.contains("Incline Bench"))
        #expect(exercise.systemAlternateNames.contains("Incline Press"))
        #expect(exercise.systemAlternateNames.contains("Barbell Incline Bench Press"))
        #expect(exercise.systemAlternateNames.contains("Barbell Incline Bench"))
        #expect(exercise.systemAlternateNames.contains("Barbell Incline Press"))
    }

    @Test @MainActor
    func entitySearchScorePrefersExactEquipmentPrefixedMatch() {
        let barbellExercise = Exercise(from: ExerciseCatalog.byID["barbell_incline_bench_press"]!)
        let smithExercise = Exercise(from: ExerciseCatalog.byID["smith_machine_incline_bench_press"]!)

        let query = "barbell incline bench press"
        let barbellScore = exerciseEntitySearchScore(for: barbellExercise, query: query)
        let smithScore = exerciseEntitySearchScore(for: smithExercise, query: query)

        #expect(barbellScore > smithScore)
    }
}

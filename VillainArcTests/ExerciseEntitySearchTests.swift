import Testing

@testable import VillainArc

struct ExerciseEntitySearchTests {
    @Test @MainActor func systemAlternateNamesIncludeEquipmentPrefixedVariants() {
        let exercise = Exercise(from: ExerciseCatalog.byID["barbell_incline_bench_press"]!)
        let expectedNames = [
            "Incline Bench",
            "Incline Press",
            "Barbell Incline Bench Press",
            "Barbell Incline Bench",
            "Barbell Incline Press"
        ]
        #expect(expectedNames.allSatisfy(exercise.systemAlternateNames.contains))
    }

    @Test @MainActor func entitySearchScorePrefersExactEquipmentPrefixedMatch() {
        let barbellExercise = Exercise(from: ExerciseCatalog.byID["barbell_incline_bench_press"]!)
        let smithExercise = Exercise(from: ExerciseCatalog.byID["smith_machine_incline_bench_press"]!)
        let query = "barbell incline bench press"
        let barbellScore = exerciseEntitySearchScore(for: barbellExercise, query: query)
        let smithScore = exerciseEntitySearchScore(for: smithExercise, query: query)
        #expect(barbellScore > smithScore)
    }

    @Test @MainActor func systemAlternateNamesDeduplicateAliasesAndExcludePrimaryName() {
        let exercise = Exercise(from: ExerciseCatalog.byID["barbell_incline_bench_press"]!)
        exercise.aliases = [
            "Incline Bench",
            "incline bench",
            "  Incline Bench  ",
            "Incline Bench Press"
        ]

        let alternateNames = exercise.systemAlternateNames
        let primaryNormalized = normalizedSearchPhrase(exercise.name)
        let inclineBenchCount = alternateNames.filter { normalizedSearchPhrase($0) == "incline bench" }.count

        #expect(alternateNames.contains(where: { normalizedSearchPhrase($0) == "incline bench" }))
        #expect(alternateNames.contains(where: { normalizedSearchPhrase($0) == primaryNormalized }) == false)
        #expect(inclineBenchCount == 1)
    }
}

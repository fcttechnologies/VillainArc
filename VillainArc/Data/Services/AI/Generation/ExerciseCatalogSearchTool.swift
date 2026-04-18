import Foundation
import FoundationModels
import SwiftData

struct ExerciseCatalogSearchTool: Tool, Sendable {
    let name = "searchExercises"
    let description = "Search the Villain Arc exercise catalog for real exercises. Always use this before returning exercises so catalogID, name, muscles, and equipment match an existing exercise."

    @Generable
    struct Arguments {
        @Guide(description: "The exercise search query, like 'incline dumbbell chest press' or 'hamstring curl'.")
        let query: String

        @Guide(description: "How many matches to return.", .range(1...8))
        let limit: Int
    }

    func call(arguments: Arguments) async throws -> [AIExerciseIdentitySnapshot] {
        let context = ModelContext(SharedModelContainer.container)
        let query = arguments.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }

        let exercises = (try? context.fetch(Exercise.catalogExercises)) ?? []
        let queryTokens = normalizedTokens(for: query)
        let limit = max(1, min(arguments.limit, 8))

        let scored = exercises.compactMap { exercise -> ExerciseSearchMatch? in
            let score = exerciseSearchScore(for: exercise, queryTokens: queryTokens)
            guard score > 0 else { return nil }
            return ExerciseSearchMatch(exercise: exercise, score: score)
        }
        .sorted { left, right in
            if left.score != right.score { return left.score > right.score }
            return left.exercise.name.localizedCaseInsensitiveCompare(right.exercise.name) == .orderedAscending
        }

        if !scored.isEmpty {
            return scored.prefix(limit).map { AIExerciseIdentitySnapshot(exercise: $0.exercise) }
        }

        let fuzzyMatches = exercises.filter { exercise in
            matchesExerciseFuzzy(exercise, queryTokens: queryTokens)
        }
        .sorted { left, right in
            left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
        }

        return fuzzyMatches.prefix(limit).map(AIExerciseIdentitySnapshot.init(exercise:))
    }
}

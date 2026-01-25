import AppIntents
import SwiftData

struct ExerciseEntity: AppEntity, Identifiable {
    nonisolated static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Exercise")
    nonisolated static let defaultQuery = ExerciseEntityQuery()

    nonisolated let id: String
    nonisolated let name: String
    nonisolated let muscles: String

    nonisolated var displayRepresentation: DisplayRepresentation {
        if muscles.isEmpty {
            return DisplayRepresentation(title: "\(name)")
        }
        return DisplayRepresentation(title: "\(name)", subtitle: "\(muscles)")
    }
}

extension ExerciseEntity {
    init(exercise: Exercise) {
        id = exercise.catalogID
        name = exercise.name
        muscles = exercise.displayMuscles
    }
}

struct ExerciseEntityQuery: EntityQuery, EntityStringQuery {
    @MainActor
    func entities(for identifiers: [ExerciseEntity.ID]) async throws -> [ExerciseEntity] {
        guard !identifiers.isEmpty else { return [] }
        let context = SharedModelContainer.container.mainContext
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>(sortBy: Exercise.recentsSort))) ?? []
        let byID = Dictionary(exercises.map { ($0.catalogID, $0) }, uniquingKeysWith: { first, _ in first })
        return identifiers.compactMap { byID[$0] }.map(ExerciseEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [ExerciseEntity] {
        let context = SharedModelContainer.container.mainContext
        var descriptor = FetchDescriptor<Exercise>(sortBy: Exercise.recentsSort)
        descriptor.fetchLimit = 20
        let exercises = (try? context.fetch(descriptor)) ?? []
        return exercises.map(ExerciseEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [ExerciseEntity] {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let queryTokens = normalizedTokens(for: trimmed)
        let context = SharedModelContainer.container.mainContext
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>(sortBy: Exercise.recentsSort))) ?? []

        if queryTokens.isEmpty {
            return exercises.map(ExerciseEntity.init)
        }

        let exactFiltered = exercises.filter { exercise in
            matchesSearch(exercise, queryTokens: queryTokens)
        }

        if !exactFiltered.isEmpty {
            return exactFiltered.map(ExerciseEntity.init)
        }

        guard shouldUseFuzzySearch(queryTokens: queryTokens) else {
            return []
        }

        let fuzzyFiltered = exercises.filter { exercise in
            matchesSearchFuzzy(exercise, queryTokens: queryTokens)
        }
        return fuzzyFiltered.map(ExerciseEntity.init)
    }

    private func matchesSearch(_ exercise: Exercise, queryTokens: [String]) -> Bool {
        guard !queryTokens.isEmpty else { return true }
        let haystack = exercise.searchIndex
        return queryTokens.allSatisfy { haystack.contains($0) }
    }

    private func matchesSearchFuzzy(_ exercise: Exercise, queryTokens: [String]) -> Bool {
        guard !queryTokens.isEmpty else { return true }
        let haystackTokens = exercise.searchTokens

        return queryTokens.allSatisfy { queryToken in
            let maxDistance = maximumFuzzyDistance(for: queryToken)
            return haystackTokens.contains { token in
                if token == queryToken {
                    return true
                }
                if maxDistance == 0 {
                    return false
                }
                if abs(token.count - queryToken.count) > maxDistance {
                    return false
                }
                return levenshteinDistance(between: token, and: queryToken, maxDistance: maxDistance) <= maxDistance
            }
        }
    }
}

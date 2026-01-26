import AppIntents
import CoreSpotlight
import SwiftData

struct ExerciseEntity: AppEntity, IndexedEntity, Identifiable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Exercise")
    static let defaultQuery = ExerciseEntityQuery()

    let id: String
    let name: String
    let muscles: String
    let aliases: [String]

    var displayRepresentation: DisplayRepresentation {
        let synonyms = aliases.map { LocalizedStringResource(stringLiteral: $0) }
        if muscles.isEmpty {
            return DisplayRepresentation(title: "\(name)", synonyms: synonyms)
        }
        return DisplayRepresentation(title: "\(name)", subtitle: "\(muscles)", synonyms: synonyms)
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet()
        attributes.title = name
        attributes.displayName = name
        attributes.alternateNames = aliases
        attributes.contentDescription = muscles
        attributes.keywords = [name] + aliases + ["Exercise"]
        return attributes
    }
}

extension ExerciseEntity {
    init(exercise: Exercise) {
        id = exercise.catalogID
        name = exercise.name
        muscles = exercise.displayMuscles
        aliases = exercise.aliases
    }
}

struct ExerciseEntityQuery: EntityQuery, EntityStringQuery {
    @MainActor
    func entities(for identifiers: [ExerciseEntity.ID]) async throws -> [ExerciseEntity] {
        guard !identifiers.isEmpty else { return [] }
        let context = SharedModelContainer.container.mainContext
        let ids = identifiers
        let predicate = #Predicate<Exercise> { ids.contains($0.catalogID) }
        let descriptor = FetchDescriptor(predicate: predicate)
        let exercises = (try? context.fetch(descriptor)) ?? []
        let byID = Dictionary(exercises.map { ($0.catalogID, $0) }, uniquingKeysWith: { first, _ in first })
        return ids.compactMap { byID[$0] }.map(ExerciseEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [ExerciseEntity] {
        let context = SharedModelContainer.container.mainContext
        var descriptor = Exercise.all
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

import AppIntents
import CoreTransferable
import SwiftData

struct ExerciseEntity: AppEntity, IndexedEntity, Identifiable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Exercise")
    static let defaultQuery = ExerciseEntityQuery()

    let id: String
    let name: String
    let equipment: String
    let alternateNames: [String]

    var displayRepresentation: DisplayRepresentation {
        let synonyms = alternateNames.map { LocalizedStringResource(stringLiteral: $0) }
        return DisplayRepresentation(title: "\(name)", subtitle: "\(equipment)", synonyms: synonyms)
    }

}

extension ExerciseEntity {
    init(exercise: Exercise) {
        id = exercise.catalogID
        name = exercise.name
        equipment = exercise.equipmentType.displayName
        alternateNames = exercise.systemAlternateNames
    }
}

extension ExerciseEntity: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation { entity in
            "\(entity.name) — \(entity.equipment)"
        }
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
        let histories = (try? context.fetch(ExerciseHistory.recentCompleted(limit: 30))) ?? []
        let recentCatalogIDs = histories.map(\.catalogID)
        let recentExercises = fetchExercises(for: recentCatalogIDs, in: context)

        if recentExercises.count >= 30 {
            return Array(recentExercises.prefix(30)).map(ExerciseEntity.init)
        }

        let remainingCount = max(0, 30 - recentExercises.count)
        let fallbackExercises = remainingCount == 0
            ? []
            : ((try? context.fetch(Exercise.backfillExcludingCatalogIDs(recentCatalogIDs, limit: remainingCount))) ?? [])
        let seenCatalogIDs = Set(recentExercises.map(\.catalogID))
        let backfillExercises = fallbackExercises.filter { !seenCatalogIDs.contains($0.catalogID) }
        return Array((recentExercises + backfillExercises).prefix(30)).map(ExerciseEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [ExerciseEntity] {
        let context = SharedModelContainer.container.mainContext
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let histories = (try? context.fetch(ExerciseHistory.recentCompleted())) ?? []
        let ordering = ExerciseHistoryOrdering(histories: histories)
        let results = searchedExercises(in: exercises, query: string, orderedBy: ordering.isOrderedBefore, score: { exercise, query, queryTokens in
                exerciseEntitySearchScore(for: exercise, query: query, queryTokens: queryTokens)
            }, fuzzyAdditionalTokens: { exercise in
                exerciseEntitySearchTokens(for: exercise)
            })
        return results.map(ExerciseEntity.init)
    }

}

@MainActor
private func fetchExercises(for catalogIDs: [String], in context: ModelContext) -> [Exercise] {
    guard !catalogIDs.isEmpty else { return [] }
    let fetchedExercises = (try? context.fetch(Exercise.withCatalogIDs(catalogIDs))) ?? []
    let exerciseByCatalogID = Dictionary(uniqueKeysWithValues: fetchedExercises.map { ($0.catalogID, $0) })
    return catalogIDs.compactMap { exerciseByCatalogID[$0] }
}

@MainActor
func exerciseEntitySearchScore(for exercise: Exercise, query: String, queryTokens: [String]? = nil) -> Int {
    let resolvedQueryTokens = queryTokens ?? normalizedTokens(for: query)
    guard !resolvedQueryTokens.isEmpty else { return 0 }

    var score = exerciseSearchScore(for: exercise, queryTokens: resolvedQueryTokens)
    let normalizedQuery = normalizedSearchPhrase(query)
    if normalizedQuery.isEmpty {
        return score
    }

    let exactCandidates = [exercise.name] + exercise.systemAlternateNames
    for candidate in exactCandidates {
        let normalizedCandidate = normalizedSearchPhrase(candidate)
        guard !normalizedCandidate.isEmpty else { continue }

        if normalizedCandidate == normalizedQuery {
            score += 10_000
            continue
        }

        if normalizedCandidate.hasPrefix(normalizedQuery + " ") {
            score += 500
        }
    }

    return score
}

private func exerciseEntitySearchTokens(for exercise: Exercise) -> [String] {
    var tokens: [String] = []
    var seen = Set<String>()

    for value in exercise.systemAlternateNames {
        for token in normalizedTokens(for: value) {
            guard seen.insert(token).inserted else { continue }
            tokens.append(token)
        }
    }

    return tokens
}

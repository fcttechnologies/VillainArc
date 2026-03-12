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
        equipment = exercise.equipmentType.rawValue
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
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let histories = (try? context.fetch(ExerciseHistory.recentCompleted())) ?? []
        let sorted = sortExercisesByRecentCompletion(exercises, histories: histories)
        return Array(sorted.prefix(30)).map(ExerciseEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [ExerciseEntity] {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let queryTokens = normalizedTokens(for: trimmed)
        let context = SharedModelContainer.container.mainContext
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let histories = (try? context.fetch(ExerciseHistory.recentCompleted())) ?? []
        let historyByCatalogID = Dictionary(uniqueKeysWithValues: histories.map { ($0.catalogID, $0) })
        let sortedExercises = sortExercisesByRecentCompletion(exercises, histories: histories)

        if queryTokens.isEmpty {
            return sortedExercises.map(ExerciseEntity.init)
        }

        let scored = sortedExercises.compactMap { exercise in
            let score = exerciseEntitySearchScore(for: exercise, query: trimmed, queryTokens: queryTokens)
            return score > 0 ? ExerciseSearchMatch(exercise: exercise, score: score) : nil
        }
        if !scored.isEmpty {
            let sorted = scored.sorted { left, right in
                if left.score != right.score {
                    return left.score > right.score
                }
                return isOrderedBefore(left.exercise, right.exercise, historyByCatalogID: historyByCatalogID)
            }
            return sorted.map { ExerciseEntity(exercise: $0.exercise) }
        }

        guard shouldUseFuzzySearch(queryTokens: queryTokens) else {
            return []
        }

        let fuzzyFiltered = exercises.filter { exercise in
            matchesSearchFuzzy(exercise, queryTokens: queryTokens)
        }
        return fuzzyFiltered
            .sorted { isOrderedBefore($0, $1, historyByCatalogID: historyByCatalogID) }
            .map(ExerciseEntity.init)
    }
    
    @MainActor
    private func matchesSearchFuzzy(_ exercise: Exercise, queryTokens: [String]) -> Bool {
        guard !queryTokens.isEmpty else { return true }
        let haystackTokens = cachedExerciseSearchTokens(for: exercise) + exerciseEntitySearchTokens(for: exercise)

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

    private func isOrderedBefore(_ left: Exercise, _ right: Exercise, historyByCatalogID: [String: ExerciseHistory]) -> Bool {
        let leftDate = historyByCatalogID[left.catalogID]?.lastCompletedAt ?? .distantPast
        let rightDate = historyByCatalogID[right.catalogID]?.lastCompletedAt ?? .distantPast
        if leftDate != rightDate {
            return leftDate > rightDate
        }
        return left.name.localizedStandardCompare(right.name) == .orderedAscending
    }

    private func sortExercisesByRecentCompletion(_ exercises: [Exercise], histories: [ExerciseHistory]) -> [Exercise] {
        let historyByCatalogID = Dictionary(uniqueKeysWithValues: histories.map { ($0.catalogID, $0) })
        return exercises.sorted { isOrderedBefore($0, $1, historyByCatalogID: historyByCatalogID) }
    }
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

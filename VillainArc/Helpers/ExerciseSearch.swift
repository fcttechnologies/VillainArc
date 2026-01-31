import Foundation

struct ExerciseSearchMatch {
    let exercise: Exercise
    let score: Int
}

@MainActor
func exerciseSearchTokens(for exercise: Exercise) -> [String] {
    let combined = ([exercise.name] + exercise.aliases).joined(separator: " ")
    let baseTokens = normalizedTokens(for: combined)
    return expandedTokens(from: baseTokens)
}

@MainActor
func exerciseSearchScore(for exercise: Exercise, queryTokens: [String]) -> Int {
    guard !queryTokens.isEmpty else { return 0 }

    let baseNameTokens = normalizedTokens(for: exercise.name)
    let baseAliasTokens = exercise.aliases.map { normalizedTokens(for: $0) }
    let nameTokens = expandedTokens(from: baseNameTokens)
    let aliasTokenGroups = baseAliasTokens.map { expandedTokens(from: $0) }
    let aliasTokens = aliasTokenGroups.flatMap { $0 }
    let muscleTokenGroups = exercise.musclesTargeted.map { normalizedTokens(for: $0.rawValue) }
    let muscleTokens = muscleTokenGroups.flatMap { $0 }

    var score = 0
    var nameAliasMatchCount = 0
    var unmatchedTokens: [String] = []
    for token in queryTokens {
        if let tokenScore = tokenMatchScore(for: token, in: nameTokens, exact: 4, prefix: 3) {
            score += tokenScore
            nameAliasMatchCount += 1
            continue
        }
        if let tokenScore = tokenMatchScore(for: token, in: aliasTokens, exact: 3, prefix: 2) {
            score += tokenScore
            nameAliasMatchCount += 1
            continue
        }
        unmatchedTokens.append(token)
    }

    if !unmatchedTokens.isEmpty {
        if nameAliasMatchCount > 0 {
            return 0
        }
        if queryTokens.count == 1, let tokenScore = tokenMatchScore(for: queryTokens[0], in: muscleTokens, exact: 1, prefix: 0) {
            score += tokenScore
        } else if queryTokens.count > 1, muscleTokenGroups.contains(where: { phraseMatch(phraseTokens: queryTokens, in: $0) }) {
            score += 1
        } else {
            return 0
        }
    }

    if queryTokens.count > 1 {
        if phraseMatch(phraseTokens: queryTokens, in: baseNameTokens) {
            score += 6
        }
        if baseAliasTokens.contains(where: { phraseMatch(phraseTokens: queryTokens, in: $0) }) {
            score += 4
        }
    }

    if exercise.favorite {
        score += 1
    }

    return score
}

@MainActor
func exerciseSearchMatches(in exercises: [Exercise], queryTokens: [String]) -> [ExerciseSearchMatch] {
    guard !queryTokens.isEmpty else { return [] }
    return exercises.compactMap { exercise in
        let score = exerciseSearchScore(for: exercise, queryTokens: queryTokens)
        return score > 0 ? ExerciseSearchMatch(exercise: exercise, score: score) : nil
    }
}

private nonisolated func expandedTokens(from baseTokens: [String]) -> [String] {
    var tokens: [String] = []
    var seen = Set<String>()

    func appendToken(_ token: String) {
        guard !token.isEmpty, !seen.contains(token) else { return }
        seen.insert(token)
        tokens.append(token)
    }

    baseTokens.forEach(appendToken)
    let baseSet = Set(baseTokens)

    for (abbreviation, fullWord) in Exercise.singleWordAbbreviations {
        if baseSet.contains(abbreviation) {
            appendToken(fullWord)
        }
        if baseSet.contains(fullWord) {
            appendToken(abbreviation)
        }
    }

    for (abbreviation, words) in Exercise.phraseAbbreviations {
        if baseSet.contains(abbreviation) {
            words.forEach(appendToken)
        }
        if words.allSatisfy({ baseSet.contains($0) }) {
            appendToken(abbreviation)
        }
    }

    return tokens
}

private nonisolated func tokenMatchScore(for token: String, in tokens: [String], exact: Int, prefix: Int) -> Int? {
    if tokens.contains(token) {
        return exact
    }
    guard prefix > 0, token.count >= 1 else { return nil }
    if tokens.contains(where: { $0.hasPrefix(token) }) {
        return prefix
    }
    return nil
}

private nonisolated func phraseMatch(phraseTokens: [String], in tokens: [String]) -> Bool {
    guard !phraseTokens.isEmpty, tokens.count >= phraseTokens.count else { return false }
    let maxStart = tokens.count - phraseTokens.count
    for start in 0...maxStart {
        if Array(tokens[start..<(start + phraseTokens.count)]) == phraseTokens {
            return true
        }
    }
    return false
}

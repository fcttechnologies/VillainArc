import Foundation

struct ExerciseSearchMatch {
    let exercise: Exercise
    let score: Int
}

nonisolated func exerciseSearchTokens(for exercise: Exercise) -> [String] {
    let nameAndAliases = ([exercise.name] + exercise.aliases).joined(separator: " ")
    var seen = Set<String>()
    var tokens: [String] = []

    func add(_ string: String) {
        for token in normalizedTokens(for: string) {
            guard !token.isEmpty, seen.insert(token).inserted else { continue }
            tokens.append(token)
        }
    }

    add(nameAndAliases)
    add(exercise.equipmentType.rawValue)
    if let primaryMuscle = exercise.musclesTargeted.first {
        add(primaryMuscle.rawValue)
    }

    return tokens
}

@MainActor
func exerciseSearchScore(for exercise: Exercise, queryTokens: [String]) -> Int {
    guard !queryTokens.isEmpty else { return 0 }

    let nameTokens = normalizedTokens(for: exercise.name)
    let aliasTokenGroups = exercise.aliases.map { normalizedTokens(for: $0) }
    let aliasTokens = aliasTokenGroups.flatMap { $0 }
    let equipmentTokens = normalizedTokens(for: exercise.equipmentType.rawValue)
    let primaryMuscleTokens = exercise.musclesTargeted.first.map { normalizedTokens(for: $0.rawValue) } ?? []

    var score = 0
    for token in queryTokens {
        if let s = tokenMatchScore(for: token, in: nameTokens, exact: 4, prefix: 3) {
            score += s
        } else if let s = tokenMatchScore(for: token, in: aliasTokens, exact: 3, prefix: 2) {
            score += s
        } else if let s = tokenMatchScore(for: token, in: equipmentTokens, exact: 2, prefix: 1) {
            score += s
        } else if let s = tokenMatchScore(for: token, in: primaryMuscleTokens, exact: 1, prefix: 0) {
            score += s
        } else {
            return 0
        }
    }

    if queryTokens.count > 1 {
        if phraseMatch(phraseTokens: queryTokens, in: nameTokens) {
            score += 6
        }
        if aliasTokenGroups.contains(where: { phraseMatch(phraseTokens: queryTokens, in: $0) }) {
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

@MainActor
func cachedExerciseSearchTokens(for exercise: Exercise) -> [String] {
    if !exercise.searchTokens.isEmpty {
        return exercise.searchTokens
    }
    return exerciseSearchTokens(for: exercise)
}

private nonisolated func phraseMatch(phraseTokens: [String], in tokens: [String]) -> Bool {
    guard !phraseTokens.isEmpty, tokens.count >= phraseTokens.count else { return false }
    let maxStart = tokens.count - phraseTokens.count
    for start in 0...maxStart {
        var matches = true
        for offset in phraseTokens.indices {
            if tokens[start + offset] != phraseTokens[offset] {
                matches = false
                break
            }
        }
        if matches {
            return true
        }
    }
    return false
}

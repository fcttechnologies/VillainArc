import Foundation
import SwiftData

@Model
class Exercise {
    var catalogID: String = ""
    var name: String = ""
    var musclesTargeted: [Muscle] = []
    var lastUsed: Date? = nil
    var favorite: Bool = false
    var isCustom: Bool = false
    var searchIndex: String = ""
    var searchTokens: [String] = []

    var displayMuscles: String {
        let majors = musclesTargeted.filter(\.isMajor)
        let muscles = majors.isEmpty ? Array(musclesTargeted.prefix(1)) : majors
        return ListFormatter.localizedString(byJoining: muscles.map(\.rawValue))
    }

    init(from catalogItem: ExerciseCatalogItem) {
        catalogID = catalogItem.id
        name = catalogItem.name
        musclesTargeted = catalogItem.musclesTargeted
        rebuildSearchData()
    }
    
    func updateLastUsed(to time: Date = .now) {
        lastUsed = time
    }
    
    func toggleFavorite() {
        favorite.toggle()
    }

    @discardableResult
    func rebuildSearchData() -> Bool {
        let combined = ([name] + musclesTargeted.map(\.rawValue)).joined(separator: " ")
        let baseTokens = Exercise.normalizedTokens(for: combined)
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
        
        let updatedIndex = tokens.joined()
        if updatedIndex == searchIndex && tokens == searchTokens {
            return false
        }
        
        searchIndex = updatedIndex
        searchTokens = tokens
        return true
    }

    static func normalizedTokens(for value: String) -> [String] {
        let folded = value.folding(options: .diacriticInsensitive, locale: .current)
        let parts = folded.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
        return parts.filter { !$0.isEmpty }
    }

    private static let singleWordAbbreviations: [String: String] = [
        "db": "dumbbell",
        "bb": "barbell"
    ]

    private static let phraseAbbreviations: [String: [String]] = [
        "ohp": ["overhead", "press"],
        "rdl": ["romanian", "deadlift"]
    ]
}

extension Exercise {
    static var recentsSort: [SortDescriptor<Exercise>] {
        [
            SortDescriptor(\Exercise.lastUsed, order: .reverse),
            SortDescriptor(\Exercise.name)
        ]
    }

    static var catalogExercises: FetchDescriptor<Exercise> {
        let predicate = #Predicate<Exercise> { !$0.isCustom }
        return FetchDescriptor(predicate: predicate)
    }
}

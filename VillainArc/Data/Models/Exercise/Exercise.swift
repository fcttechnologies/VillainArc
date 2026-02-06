import Foundation
import SwiftData

@Model
class Exercise {
    var catalogID: String = ""
    var name: String = ""
    var musclesTargeted: [Muscle] = []
    var aliases: [String] = []
    var lastUsed: Date? = nil
    var favorite: Bool = false
    var isCustom: Bool = false
    var searchIndex: String = ""
    var searchTokens: [String] = []
    var equipmentType: EquipmentType = EquipmentType.bodyweight

    var displayMuscles: String {
        let majors = musclesTargeted.filter(\.isMajor)
        let muscles = majors.isEmpty ? Array(musclesTargeted.prefix(1)) : majors
        return ListFormatter.localizedString(byJoining: muscles.map(\.rawValue))
    }

    @MainActor
    init(from catalogItem: ExerciseCatalogItem) {
        catalogID = catalogItem.id
        name = catalogItem.name
        musclesTargeted = catalogItem.musclesTargeted
        aliases = catalogItem.aliases
        equipmentType = catalogItem.equipmentType
        rebuildSearchData()
    }
    
    func updateLastUsed(to time: Date = .now) {
        lastUsed = time
    }
    
    func toggleFavorite() {
        favorite.toggle()
    }

    @MainActor
    @discardableResult
    func rebuildSearchData() -> Bool {
        let tokens = exerciseSearchTokens(for: self)
        let updatedIndex = tokens.joined(separator: " ")
        if updatedIndex == searchIndex && tokens == searchTokens {
            return false
        }
        
        searchIndex = updatedIndex
        searchTokens = tokens
        return true
    }

    static let singleWordAbbreviations: [String: String] = [
        "db": "dumbbell",
        "bb": "barbell"
    ]

    static let phraseAbbreviations: [String: [String]] = [
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
    
    static var all: FetchDescriptor<Exercise> {
        FetchDescriptor(sortBy: Exercise.recentsSort)
    }
}

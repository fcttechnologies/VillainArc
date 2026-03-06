import Foundation
import SwiftData

@Model
class Exercise {
    #Index<Exercise>([\.catalogID], [\.favorite], [\.lastUsed])

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

    @MainActor
    @discardableResult
    func applyCatalogItem(_ catalogItem: ExerciseCatalogItem) -> Bool {
        var didChange = false
        var needsSearchIndex = false

        if name != catalogItem.name {
            name = catalogItem.name
            didChange = true
            needsSearchIndex = true
        }
        if musclesTargeted != catalogItem.musclesTargeted {
            musclesTargeted = catalogItem.musclesTargeted
            didChange = true
            needsSearchIndex = true
        }
        if aliases != catalogItem.aliases {
            aliases = catalogItem.aliases
            didChange = true
            needsSearchIndex = true
        }
        if equipmentType != catalogItem.equipmentType {
            equipmentType = catalogItem.equipmentType
            didChange = true
            needsSearchIndex = true
        }
        if needsSearchIndex {
            didChange = rebuildSearchData() || didChange
        }
        return didChange
    }

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

    static var spotlightEligible: FetchDescriptor<Exercise> {
        let predicate = #Predicate<Exercise> { $0.lastUsed != nil }
        return FetchDescriptor(predicate: predicate, sortBy: recentsSort)
    }
}

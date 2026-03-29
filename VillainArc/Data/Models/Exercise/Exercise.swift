import Foundation
import SwiftData

@Model final class Exercise {
    #Index<Exercise>([\.catalogID], [\.lastAddedAt], [\.favorite])

    var catalogID: String = ""
    var name: String = ""
    var musclesTargeted: [Muscle] = []
    var aliases: [String] = []
    var lastAddedAt: Date? = nil
    var favorite: Bool = false
    var isCustom: Bool = false
    var searchTokens: [String] = []
    var equipmentType: EquipmentType = EquipmentType.bodyweight
    var preferredWeightChange: Double?

    var displayMuscle: String { musclesTargeted.first?.displayName ?? String(localized: "Unknown Muscle") }

    var detailSubtitle: String {
        let majorMuscles = ListFormatter.localizedString(byJoining: Array(musclesTargeted.filter(\.isMajor).prefix(3).map(\.displayName)))
        let muscles = majorMuscles.isEmpty ? displayMuscle : majorMuscles
        let equipment = equipmentType.displayName
        return muscles.isEmpty ? equipment : "\(muscles) • \(equipment)"
    }

    var systemAlternateNames: [String] {
        var alternateNames: [String] = []
        var seen = Set<String>()
        let normalizedName = normalizedSearchPhrase(name)

        func add(_ candidate: String) {
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = normalizedSearchPhrase(trimmed)
            guard !trimmed.isEmpty, !normalized.isEmpty, normalized != normalizedName else { return }
            guard seen.insert(normalized).inserted else { return }
            alternateNames.append(trimmed)
        }

        for alias in aliases {
            add(alias)
        }

        for prefix in equipmentType.systemAlternateNamePrefixes {
            add("\(prefix) \(name)")
            for alias in aliases {
                add("\(prefix) \(alias)")
            }
        }

        return alternateNames
    }

    init(from catalogItem: ExerciseCatalogItem) {
        catalogID = catalogItem.id
        name = catalogItem.name
        musclesTargeted = catalogItem.musclesTargeted
        aliases = catalogItem.aliases
        equipmentType = catalogItem.equipmentType
        rebuildSearchData()
    }
    
    func updateLastAddedAt(to time: Date = .now) { lastAddedAt = time }
    
    func toggleFavorite() { favorite.toggle() }

    @discardableResult func rebuildSearchData() -> Bool {
        let tokens = exerciseSearchTokens(for: self)
        if tokens == searchTokens { return false }
        searchTokens = tokens
        return true
    }

    @discardableResult func applyCatalogItem(_ catalogItem: ExerciseCatalogItem) -> Bool {
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

        if needsSearchIndex { didChange = rebuildSearchData() || didChange }
        
        return didChange
    }

}

nonisolated func normalizedSearchPhrase(_ value: String) -> String { normalizedTokens(for: value).joined(separator: " ") }

extension Exercise {
    static var recentsSort: [SortDescriptor<Exercise>] { [SortDescriptor(\Exercise.lastAddedAt, order: .reverse), SortDescriptor(\Exercise.name)] }

    static var catalogExercises: FetchDescriptor<Exercise> {
        let predicate = #Predicate<Exercise> { !$0.isCustom }
        return FetchDescriptor(predicate: predicate)
    }

    static var all: FetchDescriptor<Exercise> { FetchDescriptor(sortBy: Exercise.recentsSort) }

    static func withCatalogID(_ catalogID: String) -> FetchDescriptor<Exercise> {
        let predicate = #Predicate<Exercise> { $0.catalogID == catalogID }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        return descriptor
    }

    static func withCatalogIDs(_ catalogIDs: [String]) -> FetchDescriptor<Exercise> {
        let predicate = #Predicate<Exercise> { catalogIDs.contains($0.catalogID) }
        return FetchDescriptor(predicate: predicate)
    }

    static func backfillExcludingCatalogIDs(_ catalogIDs: [String], limit: Int) -> FetchDescriptor<Exercise> {
        let excludedCatalogIDs = Set(catalogIDs)
        let predicate = #Predicate<Exercise> { !excludedCatalogIDs.contains($0.catalogID) }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: recentsSort)
        descriptor.fetchLimit = limit
        return descriptor
    }
}

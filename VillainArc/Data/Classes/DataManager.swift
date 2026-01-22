import SwiftUI
import SwiftData

@MainActor class DataManager {
    static func seedExercisesIfNeeded(context: ModelContext) {
        let storedVersion = UserDefaults.standard.integer(forKey: "exerciseCatalogVersion")
        guard ExerciseCatalog.catalogVersion != storedVersion else {
            return
        }

        syncExercises(context: context)
        UserDefaults.standard.set(ExerciseCatalog.catalogVersion, forKey: "exerciseCatalogVersion")
    }

    static func dedupeCatalogExercisesIfNeeded(context: ModelContext) {
        let catalogExercises = (try? context.fetch(Exercise.catalogExercises)) ?? []
        let grouped = Dictionary(grouping: catalogExercises, by: \.catalogID)
        var didChange = false

        for (catalogID, duplicates) in grouped where duplicates.count > 1 {
            let primary = primaryExercise(from: duplicates)
            if let catalogItem = ExerciseCatalog.byID[catalogID] {
                if primary.name != catalogItem.name {
                    primary.name = catalogItem.name
                    didChange = true
                }
                if primary.musclesTargeted != catalogItem.musclesTargeted {
                    primary.musclesTargeted = catalogItem.musclesTargeted
                    didChange = true
                }
            }
            didChange = mergeDuplicates(duplicates, keeping: primary, context: context) || didChange
            didChange = primary.rebuildSearchData() || didChange
        }

        if didChange {
            saveContext(context: context)
            print("Exercises deduped.")
        }
    }

    private static func syncExercises(context: ModelContext) {
        let catalogExercises = (try? context.fetch(Exercise.catalogExercises)) ?? []
        let exercisesByCatalogID = Dictionary(catalogExercises.map { ($0.catalogID, $0) }, uniquingKeysWith: { first, _ in first })
        var didChange = false

        for catalogItem in ExerciseCatalog.all {
            if let existing = exercisesByCatalogID[catalogItem.id] {
                var needsSearchIndex = false
                if existing.name != catalogItem.name {
                    existing.name = catalogItem.name
                    didChange = true
                    needsSearchIndex = true
                }
                if existing.musclesTargeted != catalogItem.musclesTargeted {
                    existing.musclesTargeted = catalogItem.musclesTargeted
                    didChange = true
                    needsSearchIndex = true
                }
                if needsSearchIndex {
                    didChange = existing.rebuildSearchData() || didChange
                }
            } else {
                context.insert(Exercise(from: catalogItem))
                didChange = true
            }
        }
        if didChange {
            saveContext(context: context)
            print("Exercises synced.")
        }
    }

    private static func mergeDuplicates(_ duplicates: [Exercise], keeping primary: Exercise, context: ModelContext) -> Bool {
        var didChange = false
        for duplicate in duplicates where duplicate !== primary {
            if duplicate.favorite && !primary.favorite {
                primary.favorite = true
                didChange = true
            }
            if let duplicateLastUsed = duplicate.lastUsed {
                if let primaryLastUsed = primary.lastUsed {
                    if duplicateLastUsed > primaryLastUsed {
                        primary.lastUsed = duplicateLastUsed
                        didChange = true
                    }
                } else {
                    primary.lastUsed = duplicateLastUsed
                    didChange = true
                }
            }
            context.delete(duplicate)
            didChange = true
        }
        return didChange
    }

    private static func primaryExercise(from duplicates: [Exercise]) -> Exercise {
        duplicates.max { left, right in
            let leftDate = left.lastUsed ?? .distantPast
            let rightDate = right.lastUsed ?? .distantPast
            if leftDate != rightDate {
                return leftDate < rightDate
            }
            if left.favorite != right.favorite {
                return !left.favorite && right.favorite
            }
            return false
        } ?? duplicates[0]
    }
}

@MainActor
func saveContext(context: ModelContext) {
    do {
        try context.save()
    } catch {
        print("Failed to save context: \(error)")
    }
}

@MainActor
private var pendingSaveTask: Task<Void, Never>?

@MainActor
func scheduleSave(context: ModelContext, delay: Duration = .milliseconds(500)) {
    pendingSaveTask?.cancel()
    pendingSaveTask = Task {
        do {
            try await Task.sleep(for: delay)
        } catch {
            return
        }
        saveContext(context: context)
    }
}

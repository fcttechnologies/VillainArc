import SwiftUI
import SwiftData

final class DataManager {
    static let exerciseCatalogVersionKey = "exerciseCatalogVersion"

    // MARK: - Onboarding Methods (First Launch)

    /// Onboarding-specific seeding - assumes CloudKit import already completed
    /// OnboardingManager handles the CloudKit wait before calling this
    @discardableResult
    static func seedExercisesForOnboarding() async throws -> Bool {
        try syncExercisesAndPersist()
    }

    // MARK: - Returning User Methods (Fast Path)

    /// Fast path for returning users - only checks catalog version
    @discardableResult
    static func seedExercisesIfNeeded() async throws -> Bool {
        let storedVersion = SharedModelContainer.sharedDefaults.string(forKey: exerciseCatalogVersionKey)
        guard ExerciseCatalog.catalogVersion != storedVersion else {
            return false
        }

        return try syncExercisesAndPersist()
    }

    static func hasCompletedInitialBootstrap() -> Bool {
        SharedModelContainer.sharedDefaults.string(forKey: exerciseCatalogVersionKey) != nil
    }

    static func catalogNeedsSync() -> Bool {
        SharedModelContainer.sharedDefaults.string(forKey: exerciseCatalogVersionKey) != ExerciseCatalog.catalogVersion
    }

    @discardableResult
    private static func syncExercisesAndPersist() throws -> Bool {
        let context = SharedModelContainer.container.mainContext
        let didChange = try syncExercises(context: context)
        if didChange {
            try context.save()
            print("Exercises synced.")
        }
        SharedModelContainer.sharedDefaults.set(ExerciseCatalog.catalogVersion, forKey: exerciseCatalogVersionKey)
        return didChange
    }

    private static func syncExercises(context: ModelContext) throws -> Bool {
        let catalogExercises = try context.fetch(Exercise.catalogExercises)
        let exercisesByCatalogID = Dictionary(catalogExercises.map { ($0.catalogID, $0) }, uniquingKeysWith: { first, _ in first })
        var didChange = false

        for catalogItem in ExerciseCatalog.all {
            if let existing = exercisesByCatalogID[catalogItem.id] {
                let metadataChanged =
                    existing.name != catalogItem.name ||
                    existing.musclesTargeted != catalogItem.musclesTargeted ||
                    existing.equipmentType != catalogItem.equipmentType

                didChange = existing.applyCatalogItem(catalogItem) || didChange

                if metadataChanged {
                    didChange = try syncExerciseSnapshots(for: catalogItem, context: context) || didChange
                }
            } else {
                let newExercise = Exercise(from: catalogItem)
                context.insert(newExercise)
                didChange = true
            }
        }
        return didChange
    }

    @discardableResult
    static func syncExerciseSnapshots(for catalogItem: ExerciseCatalogItem, context: ModelContext) throws -> Bool {
        var didChange = false

        let prescriptions = try context.fetch(ExercisePrescription.matching(catalogID: catalogItem.id))
        for prescription in prescriptions {
            didChange = prescription.applyCatalogMetadata(
                name: catalogItem.name,
                musclesTargeted: catalogItem.musclesTargeted,
                equipmentType: catalogItem.equipmentType
            ) || didChange
        }

        let performances = try context.fetch(ExercisePerformance.withCatalogID(catalogItem.id))
        for performance in performances {
            didChange = performance.applyCatalogMetadata(
                name: catalogItem.name,
                musclesTargeted: catalogItem.musclesTargeted,
                equipmentType: catalogItem.equipmentType
            ) || didChange
        }

        return didChange
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

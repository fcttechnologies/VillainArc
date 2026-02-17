import SwiftUI
import SwiftData
import CoreData

@MainActor class DataManager {

    // MARK: - Onboarding Methods (First Launch)

    /// Public version for onboarding - waits for CloudKit import with error handling
    static func waitForCloudKitImportPublic() async throws {
        await waitForCloudKitImport()
    }

    /// Onboarding-specific seeding - assumes CloudKit import already completed
    /// OnboardingManager handles the CloudKit wait before calling this
    static func seedExercisesForOnboarding(context: ModelContext) async throws {
        syncExercises(context: context)
        UserDefaults.standard.set(ExerciseCatalog.catalogVersion, forKey: "exerciseCatalogVersion")
    }

    // MARK: - Returning User Methods (Fast Path)

    /// Fast path for returning users - only checks catalog version
    static func seedExercisesIfNeeded(context: ModelContext) async {
        let storedVersion = UserDefaults.standard.integer(forKey: "exerciseCatalogVersion")
        guard ExerciseCatalog.catalogVersion != storedVersion else {
            return
        }

        syncExercises(context: context)
        UserDefaults.standard.set(ExerciseCatalog.catalogVersion, forKey: "exerciseCatalogVersion")
    }

    private static func waitForCloudKitImport() async {
        // Wait for CloudKit import notification (no timeout in onboarding context)
        // OnboardingManager already verified WiFi + CloudKit availability
        for await notification in NotificationCenter.default.notifications(named: NSPersistentCloudKitContainer.eventChangedNotification) {
            guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else { continue }

            // Wait for import to complete
            if event.type == .import && event.endDate != nil {
                if let error = event.error {
                    print("⚠️ CloudKit import completed with error: \(error)")
                } else {
                    print("✅ CloudKit import complete - safe to seed exercises")
                }
                return  // Import completed
            }
        }
    }

    private static func syncExercises(context: ModelContext) {
        let catalogExercises = (try? context.fetch(Exercise.catalogExercises)) ?? []
        let exercisesByCatalogID = Dictionary(catalogExercises.map { ($0.catalogID, $0) }, uniquingKeysWith: { first, _ in first })
        var didChange = false

        for catalogItem in ExerciseCatalog.all {
            if let existing = exercisesByCatalogID[catalogItem.id] {
                didChange = existing.applyCatalogItem(catalogItem) || didChange
            } else {
                let newExercise = Exercise(from: catalogItem)
                context.insert(newExercise)
                didChange = true
            }
        }
        if didChange {
            saveContext(context: context)
            print("Exercises synced.")
        }
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

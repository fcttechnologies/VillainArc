import SwiftUI
import SwiftData
import CoreData

@MainActor class DataManager {
    private static var hasWaitedForCloudKitImport = false

    static func seedExercisesIfNeeded(context: ModelContext) async {
        // Wait for CloudKit import to complete before seeding
        if !hasWaitedForCloudKitImport {
            await waitForCloudKitImport()
            hasWaitedForCloudKitImport = true
        }

        let storedVersion = UserDefaults.standard.integer(forKey: "exerciseCatalogVersion")
        guard ExerciseCatalog.catalogVersion != storedVersion else {
            return
        }

        syncExercises(context: context)
        UserDefaults.standard.set(ExerciseCatalog.catalogVersion, forKey: "exerciseCatalogVersion")
    }

    private static func waitForCloudKitImport() async {
        // Use modern async notifications (Swift 6 concurrency compliant)
        let importCompleted = await withTaskGroup(of: Bool.self) { group -> Bool in
            // Task 1: Wait for CloudKit import notification
            group.addTask {
                for await notification in NotificationCenter.default.notifications(
                    named: NSPersistentCloudKitContainer.eventChangedNotification
                ) {
                    guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                        as? NSPersistentCloudKitContainer.Event else { continue }

                    // Wait for import to complete
                    if event.type == .import && event.endDate != nil {
                        return true  // Import completed
                    }
                }
                return false
            }

            // Task 2: 5-second timeout
            group.addTask {
                try? await Task.sleep(for: .seconds(10))
                return false  // Timeout
            }

            // Wait for first task to complete, then cancel the other
            let result = await group.next() ?? false
            group.cancelAll()
            return result
        }

        // Single clean log message
        if importCompleted {
            print("✅ CloudKit import complete - safe to seed exercises")
        } else {
            print("⏱️ CloudKit import timeout - proceeding with seed")
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

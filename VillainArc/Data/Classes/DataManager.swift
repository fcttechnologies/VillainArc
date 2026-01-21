import SwiftUI
import SwiftData

@MainActor class DataManager {
    static func seedExercisesIfNeeded(context: ModelContext) {
        let catalogVersion = ExerciseDetails.allCases.count
        let storedVersion = UserDefaults.standard.integer(forKey: "exerciseCatalogVersion")

        if storedVersion != catalogVersion {
            syncExercises(context: context)
            UserDefaults.standard.set(catalogVersion, forKey: "exerciseCatalogVersion")
        }
    }

    private static func syncExercises(context: ModelContext) {
        let descriptor = FetchDescriptor<Exercise>()
        let existingNames = Set((try? context.fetch(descriptor))?.map(\.name) ?? [])

        for exerciseDetail in ExerciseDetails.allCases {
            let name = exerciseDetail.rawValue
            if !existingNames.contains(name) {
                context.insert(Exercise(from: exerciseDetail))
            }
        }
        saveContext(context: context)
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

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
        
        for exerciseDetail in ExerciseDetails.allCases {
            let name = exerciseDetail.rawValue
            let predicate = #Predicate<Exercise> { $0.name == name }
            let descriptor = FetchDescriptor(predicate: predicate)

            if (try? context.fetch(descriptor))?.isEmpty ?? true {
                context.insert(Exercise(from: exerciseDetail))
            }
        }
        saveContext(context: context)
    }
}

@MainActor func saveContext(context: ModelContext) {
    do {
        try context.save()
    } catch {
        print("Failed to save context: \(error)")
    }
}

import SwiftData
import Foundation

enum SharedModelContainer {

    static let appGroupID = "group.com.fcttechnologies.VillainArcCont"
    @MainActor static let sharedDefaults: UserDefaults = {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            fatalError("App Group defaults not found for \(appGroupID). Check App Groups capability + entitlements.")
        }
        return defaults
    }()

    static let schema = Schema([
        WorkoutSession.self,
        HealthWorkout.self,
        PreWorkoutContext.self,
        ExercisePerformance.self,
        SetPerformance.self,
        Exercise.self,
        AppSettings.self,
        UserProfile.self,
        ExerciseHistory.self,
        ProgressionPoint.self,
        RepRangePolicy.self,
        RestTimeHistory.self,
        WorkoutPlan.self,
        ExercisePrescription.self,
        SetPrescription.self,
        WorkoutSplit.self,
        WorkoutSplitDay.self,
        SuggestionEvent.self,
        PrescriptionChange.self,
        SuggestionEvaluation.self
    ])

    static let container: ModelContainer = {
        do {
            guard let url = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
                .appendingPathComponent("VillainArc.store")
            else {
                fatalError("App Group container URL not found for \(appGroupID). Check App Groups capability + entitlements.")
            }

            let configuration = ModelConfiguration(
                nil,
                schema: schema,
                url: url,
                allowsSave: true,
                cloudKitDatabase: .private("iCloud.com.fcttechnologies.VillainArcCont")
            )

            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create shared ModelContainer: \(error)")
        }
    }()
}

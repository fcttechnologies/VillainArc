import SwiftData
import Foundation

enum SharedModelContainer {

    static let appGroupID = "group.com.fcttechnologies.VillainArc.cont"

    static let schema = Schema([
        WorkoutSession.self,
        PreWorkoutStatus.self,
        ExercisePerformance.self,
        SetPerformance.self,
        Exercise.self,
        ExerciseHistory.self,
        ProgressionPoint.self,
        RepRangePolicy.self,
        RestTimeHistory.self,
        WorkoutPlan.self,
        ExercisePrescription.self,
        SetPrescription.self,
        WorkoutSplit.self,
        WorkoutSplitDay.self,
        PrescriptionChange.self
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
                cloudKitDatabase: .automatic
            )

            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create shared ModelContainer: \(error)")
        }
    }()
}

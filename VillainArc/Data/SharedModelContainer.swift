import SwiftData
import Foundation

enum SharedModelContainer {

    static let appGroupID = "group.com.fcttechnologies.VillainArc"

    static let schema = Schema([
        Workout.self,
        WorkoutExercise.self,
        ExerciseSet.self,
        Exercise.self,
        RepRangePolicy.self,
        RestTimePolicy.self,
        RestTimeHistory.self,
        WorkoutTemplate.self,
        TemplateExercise.self,
        TemplateSet.self,
        WorkoutSplit.self,
        WorkoutSplitDay.self
    ])

    static let container: ModelContainer = {
        do {
            let configuration: ModelConfiguration
            if let url = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
                .appendingPathComponent("VillainArc.store") {
                configuration = ModelConfiguration(
                    schema: schema,
                    url: url
                )
            } else {
                configuration = ModelConfiguration(schema: schema)
            }

            return try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
        } catch {
            fatalError("Failed to create shared ModelContainer: \(error)")
        }
    }()
}

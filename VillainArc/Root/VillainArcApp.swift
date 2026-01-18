import SwiftUI
import SwiftData

@main
struct VillainArcApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [Workout.self, WorkoutExercise.self, ExerciseSet.self, Exercise.self, RepRangePolicy.self, RestTimePolicy.self])
        }
    }
}

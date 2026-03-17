import Foundation
import SwiftData

@Model
final class HealthWorkout {
    #Index<HealthWorkout>([\.healthWorkoutUUID])

    var healthWorkoutUUID: UUID = UUID()
    var workoutSession: WorkoutSession?

    init(healthWorkoutUUID: UUID, workoutSession: WorkoutSession? = nil) {
        self.healthWorkoutUUID = healthWorkoutUUID
        self.workoutSession = workoutSession
    }
}

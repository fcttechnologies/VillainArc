import Foundation
import SwiftData

@Model
class PreWorkoutStatus {
    var feeling: MoodLevel = MoodLevel.notSet
    var tookPreWorkout: Bool = false
    var notes: String = ""
    var workoutSession: WorkoutSession?
    
    init() {}
}

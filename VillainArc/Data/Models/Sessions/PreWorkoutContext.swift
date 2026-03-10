import Foundation
import SwiftData

@Model
final class PreWorkoutContext {
    var feeling: MoodLevel = MoodLevel.notSet
    var tookPreWorkout: Bool = false
    var notes: String = ""
    var workoutSession: WorkoutSession?
    
    init() {}
}

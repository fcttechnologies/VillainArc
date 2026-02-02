import Foundation
import SwiftData

@Model
class PreWorkoutMood {
    var feeling: MoodLevel = MoodLevel.okay
    var notes: String = ""
    var workoutSession: WorkoutSession?
    
    init(workoutSession: WorkoutSession) {
        self.workoutSession = workoutSession
    }
}

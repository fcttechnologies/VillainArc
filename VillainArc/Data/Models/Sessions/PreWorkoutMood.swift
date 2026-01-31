import Foundation
import SwiftData

@Model
class PreWorkoutMood {
    var feeling: MoodLevel = MoodLevel.okay
    var notes: String?
    var workoutSession: WorkoutSession?
    
    init(feeling: MoodLevel, notes: String, workoutSession: WorkoutSession) {
        self.feeling = feeling
        self.notes = notes
        self.workoutSession = workoutSession
    }
}

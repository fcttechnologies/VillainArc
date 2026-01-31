import Foundation
import SwiftData

@Model
class PostWorkoutEffort {
    var rpe: Int = 5
    var notes: String?
    var workoutSession: WorkoutSession?
    
    init(rpe: Int, notes: String, workoutSession: WorkoutSession) {
        self.rpe = rpe
        self.notes = notes
        self.workoutSession = workoutSession
    }
}

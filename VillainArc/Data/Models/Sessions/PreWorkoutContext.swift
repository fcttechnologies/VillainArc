import Foundation
import SwiftData

@Model final class PreWorkoutContext {
    @Attribute(.preserveValueOnDeletion) var id: UUID = UUID()
    var feeling: MoodLevel = MoodLevel.notSet
    var tookPreWorkout: Bool = false
    var workoutSession: WorkoutSession?

    init() {}
}

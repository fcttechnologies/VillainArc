import Foundation
import SwiftData

@Model
class WorkoutSplitDay {
    var name: String = ""
    var index: Int = 0
    var weekday: Int = 1
    var isRestDay: Bool = false
    var targetMuscles: [Muscle] = []
    var split: WorkoutSplit?
    var workoutPlan: WorkoutPlan?

    var resolvedMuscles: [Muscle] {
        workoutPlan?.musclesArray ?? targetMuscles
    }
    
    init(weekday: Int, split: WorkoutSplit) {
        self.weekday = weekday
        self.split = split
    }
    
    init(index: Int, split: WorkoutSplit) {
        self.index = index
        self.split = split
    }
}

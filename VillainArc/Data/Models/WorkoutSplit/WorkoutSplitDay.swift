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

    // Test/sample initializer to reduce setup boilerplate.
    convenience init(weekday: Int, split: WorkoutSplit, name: String = "", isRestDay: Bool = false, targetMuscles: [Muscle] = []) {
        self.init(weekday: weekday, split: split)
        self.name = name
        self.isRestDay = isRestDay
        self.targetMuscles = targetMuscles
    }

    // Test/sample initializer to reduce setup boilerplate.
    convenience init(index: Int, split: WorkoutSplit, name: String = "", isRestDay: Bool = false, targetMuscles: [Muscle] = []) {
        self.init(index: index, split: split)
        self.name = name
        self.isRestDay = isRestDay
        self.targetMuscles = targetMuscles
    }
}

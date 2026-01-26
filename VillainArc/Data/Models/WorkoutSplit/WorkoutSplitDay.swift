import Foundation
import SwiftData

@Model
class WorkoutSplitDay {
    var index: Int = 0
    var weekday: Int = 1
    var isRestDay: Bool = false
    var split: WorkoutSplit
    @Relationship(deleteRule: .nullify)
    var template: WorkoutTemplate?
    
    init(index: Int, weekday: Int, isRestDay: Bool, split: WorkoutSplit) {
        self.index = index
        self.weekday = weekday
        self.isRestDay = isRestDay
        self.split = split
    }
}

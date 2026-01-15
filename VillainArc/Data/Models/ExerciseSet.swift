import Foundation
import SwiftData

@Model
class ExerciseSet {
    var index: Int = 0
    var type: ExerciseSetType = ExerciseSetType.regular
    var weight: Double = 0
    var reps: Int = 0
    var complete: Bool = false
    var restSeconds: Int = 0
    
    init(index: Int, type: ExerciseSetType = .regular, weight: Double = 0.0, reps: Int = 0, restSeconds: Int = 0) {
        self.index = index
        self.type = type
        self.weight = weight
        self.reps = reps
        self.restSeconds = restSeconds
    }
}

import Foundation
import SwiftData

@Model
class TemplateSet {
    var index: Int = 0
    var type: ExerciseSetType = ExerciseSetType.regular
    var restSeconds: Int = 0
    var exercise: TemplateExercise
    
    init(index: Int, type: ExerciseSetType = .regular, restSeconds: Int = 0, exercise: TemplateExercise) {
        self.index = index
        self.type = type
        self.restSeconds = restSeconds
        self.exercise = exercise
    }

    init(from exerciseSet: ExerciseSet, exercise: TemplateExercise) {
        index = exerciseSet.index
        type = exerciseSet.type
        restSeconds = exerciseSet.restSeconds
        self.exercise = exercise
    }
}

extension TemplateSet: RestTimeEditableSet {}

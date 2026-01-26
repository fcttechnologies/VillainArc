import Foundation
import SwiftData

@Model
class TemplateExercise {
    var index: Int
    var catalogID: String
    var name: String = ""
    var notes: String = ""
    @Relationship(deleteRule: .cascade)
    var repRange: RepRangePolicy = RepRangePolicy()
    var musclesTargeted: [Muscle] = []
    @Relationship(deleteRule: .cascade)
    var restTimePolicy: RestTimePolicy = RestTimePolicy()
    var template: WorkoutTemplate
    @Relationship(deleteRule: .cascade, inverse: \TemplateSet.exercise)
    var sets: [TemplateSet] = []
    
    var displayMuscle: String {
        if let major = musclesTargeted.first(where: \.isMajor) {
            return major.rawValue
        }
        return musclesTargeted.first?.rawValue ?? ""
    }
    
    var sortedSets: [TemplateSet] {
        sets.sorted { $0.index < $1.index }
    }
    
    init(from exercise: Exercise, template: WorkoutTemplate) {
        index = template.exercises.count
        catalogID = exercise.catalogID
        name = exercise.name
        musclesTargeted = exercise.musclesTargeted
        self.template = template
        addSet()
    }

    init(from workoutExercise: WorkoutExercise, template: WorkoutTemplate) {
        index = workoutExercise.index
        catalogID = workoutExercise.catalogID
        name = workoutExercise.name
        notes = workoutExercise.notes
        repRange = RepRangePolicy(previous: workoutExercise.repRange)
        musclesTargeted = workoutExercise.musclesTargeted
        restTimePolicy = RestTimePolicy(previous: workoutExercise.restTimePolicy)
        self.template = template
        sets = workoutExercise.sortedSets.map { TemplateSet(from: $0, exercise: self) }
    }
    
    init(index: Int, name: String, notes: String = "", repRange: RepRangePolicy = RepRangePolicy(), musclesTargeted: [Muscle] = [], template: WorkoutTemplate, catalogID: String) {
        self.index = index
        self.catalogID = catalogID
        self.name = name
        self.notes = notes
        self.repRange = repRange
        self.musclesTargeted = musclesTargeted
        self.template = template
    }
    
    func addSet() {
        if let previous = sortedSets.last {
            sets.append(TemplateSet(index: sets.count, restSeconds: previous.restSeconds, exercise: self))
        } else {
            let restSeconds = restTimePolicy.defaultRegularSeconds()
            sets.append(TemplateSet(index: sets.count, restSeconds: restSeconds, exercise: self))
        }
    }
    
    func removeSet(_ set: TemplateSet) {
        sets.removeAll { $0 == set }
        
        for (index, templateSet) in sortedSets.enumerated() {
            templateSet.index = index
        }
    }
}

extension TemplateExercise: RestTimeEditable {}

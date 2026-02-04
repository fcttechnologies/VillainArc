import Foundation
import SwiftData

@Model
class SetPrescription {
    var id: UUID = UUID()
    var index: Int = 0
    var type: ExerciseSetType = ExerciseSetType.regular
    var targetWeight: Double = 0
    var targetReps: Int = 0
    var targetRest: Int = 0
    var exercise: ExercisePrescription?
    @Relationship(deleteRule: .nullify, inverse: \PrescriptionChange.targetSetPrescription)
    var changes: [PrescriptionChange] = []
    
    // Adding set in workout plan creation
    init(exercisePrescription: ExercisePrescription, targetWeight: Double = 0, targetReps: Int = 0, targetRest: Int = 0) {
        self.index = exercisePrescription.sets.count
        self.exercise = exercisePrescription
        self.targetWeight = targetWeight
        self.targetReps = targetReps
        self.targetRest = targetRest
    }
    
    // Adding set from plan
    init(exercisePrescription: ExercisePrescription, setPerformance: SetPerformance) {
        index = setPerformance.index
        type = setPerformance.type
        targetWeight = setPerformance.weight
        targetReps = setPerformance.reps
        targetRest = setPerformance.restSeconds
        exercise = exercisePrescription
    }
}

extension SetPrescription: RestTimeEditableSet {
    var restSeconds: Int {
        get { targetRest }
        set { targetRest = newValue }
    }
}

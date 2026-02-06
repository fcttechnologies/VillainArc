import Foundation
import SwiftData

@Model
class SetPrescription {
    var id: UUID = UUID()
    var index: Int = 0
    var type: ExerciseSetType = ExerciseSetType.working
    var targetWeight: Double = 0
    var targetReps: Int = 0
    var targetRest: Int = 0
    var exercise: ExercisePrescription?
    @Relationship(deleteRule: .nullify, inverse: \PrescriptionChange.targetSetPrescription)
    var changes: [PrescriptionChange] = []
    
    // Adding set in workout plan creation
    init(exercisePrescription: ExercisePrescription, targetWeight: Double = 0, targetReps: Int = 0, targetRest: Int = 0) {
        index = exercisePrescription.sets.count
        exercise = exercisePrescription
        self.targetWeight = targetWeight
        self.targetReps = targetReps
        self.targetRest = targetRest
    }
    
    // Creation from sessinon performance
    init(exercisePrescription: ExercisePrescription, setPerformance: SetPerformance) {
        index = setPerformance.index
        type = setPerformance.type
        targetWeight = setPerformance.weight
        targetReps = setPerformance.reps
        targetRest = setPerformance.restSeconds
        exercise = exercisePrescription
        setPerformance.prescription = self
    }
    
    // Creates a copy with the same ID for edit tracking
    init(copying original: SetPrescription, exercise: ExercisePrescription) {
        id = original.id  // Same ID enables matching for change detection
        index = original.index
        type = original.type
        targetWeight = original.targetWeight
        targetReps = original.targetReps
        targetRest = original.targetRest
        self.exercise = exercise
        // DO NOT copy changes - they remain on the original prescription
    }
}

extension SetPrescription: RestTimeEditableSet {
    var restSeconds: Int {
        get { targetRest }
        set { targetRest = newValue }
    }
}

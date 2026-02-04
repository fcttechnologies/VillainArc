import Foundation
import SwiftData

@Model
class ExercisePrescription {
    var id: UUID = UUID()
    var index: Int = 0
    var catalogID: String = ""
    var name: String = ""
    var notes: String = ""
    var musclesTargeted: [Muscle] = []
    @Relationship(deleteRule: .cascade)
    var repRange: RepRangePolicy = RepRangePolicy()
    @Relationship(deleteRule: .cascade)
    var restTimePolicy: RestTimePolicy = RestTimePolicy()
    var workoutPlan: WorkoutPlan?
    @Relationship(deleteRule: .cascade, inverse: \SetPrescription.exercise)
    var sets: [SetPrescription] = []
    
    @Relationship(deleteRule: .nullify, inverse: \PrescriptionChange.targetExercisePrescription)
    var changes: [PrescriptionChange] = []
    
    var sortedSets: [SetPrescription] {
        sets.sorted { $0.index < $1.index }
    }

    var displayMuscle: String {
        return musclesTargeted.first?.rawValue ?? ""
    }
    
    // Adding exercise in workout plan creation
    init(exercise: Exercise, workoutPlan: WorkoutPlan) {
        index = workoutPlan.exercises.count
        catalogID = exercise.catalogID
        name = exercise.name
        musclesTargeted = exercise.musclesTargeted
        self.workoutPlan = workoutPlan
        addSet()
    }
    
    // Creating from session performance
    init(workoutPlan: WorkoutPlan, exercisePerformance: ExercisePerformance) {
        index = exercisePerformance.index
        catalogID = exercisePerformance.catalogID
        name = exercisePerformance.name
        notes = exercisePerformance.notes
        musclesTargeted = exercisePerformance.musclesTargeted
        repRange = RepRangePolicy(copying: exercisePerformance.repRange)
        restTimePolicy = RestTimePolicy(copying: exercisePerformance.restTimePolicy)
        self.workoutPlan = workoutPlan
        sets = exercisePerformance.sortedSets.map { SetPrescription(exercisePrescription: self, setPerformance: $0) }
    }

    func addSet() {
        if let previous = sortedSets.last {
            sets.append(SetPrescription(exercisePrescription: self, targetWeight: previous.targetWeight, targetReps: previous.targetReps, targetRest: previous.targetRest))
        } else {
            sets.append(SetPrescription(exercisePrescription: self, targetRest: restTimePolicy.defaultRegularSeconds()))
        }
    }
    
    func deleteSet(_ set: SetPrescription) {
        sets.removeAll(where: { $0 == set })
        reindexSets()
    }
    
    func reindexSets() {
        for (index, set) in sets.enumerated() {
            set.index = index
        }
    }
}

extension ExercisePrescription: RestTimeEditable {}

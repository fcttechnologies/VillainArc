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
        exercisePerformance.prescription = self
        sets = exercisePerformance.sortedSets.map { SetPrescription(exercisePrescription: self, setPerformance: $0) }
    }
    
    // Creates a copy with the same ID for edit tracking
    init(copying original: ExercisePrescription, workoutPlan: WorkoutPlan) {
        self.id = original.id  // Same ID enables matching for change detection
        self.index = original.index
        self.catalogID = original.catalogID
        self.name = original.name
        self.notes = original.notes
        self.musclesTargeted = original.musclesTargeted
        self.repRange = RepRangePolicy(copying: original.repRange)
        self.restTimePolicy = RestTimePolicy(copying: original.restTimePolicy)
        self.workoutPlan = workoutPlan
        // Copy sets with same IDs - NO changes copied (changes stay on original)
        self.sets = original.sortedSets.map { SetPrescription(copying: $0, exercise: self) }
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

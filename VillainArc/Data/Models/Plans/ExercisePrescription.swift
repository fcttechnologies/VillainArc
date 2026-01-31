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
    var planSnapshot: PlanSnapshot?
    @Relationship(deleteRule: .cascade, inverse: \SetPrescription.exercise)
    var sets: [SetPrescription] = []
    
    var sortedSets: [SetPrescription] {
        sets.sorted { $0.index < $1.index }
    }

    var displayMuscle: String {
        return musclesTargeted.first?.rawValue ?? ""
    }
    
    // Adding exercise in workout plan creation
    init(exercise: Exercise, planSnapshot: PlanSnapshot) {
        index = planSnapshot.exercises.count
        catalogID = exercise.catalogID
        name = exercise.name
        musclesTargeted = exercise.musclesTargeted
        self.planSnapshot = planSnapshot
        addSet()
    }
    
    // Adding exercise from session
    init(planSnapshot: PlanSnapshot, exercisePerformance: ExercisePerformance) {
        index = exercisePerformance.index
        catalogID = exercisePerformance.catalogID
        name = exercisePerformance.name
        notes = exercisePerformance.notes
        musclesTargeted = exercisePerformance.musclesTargeted
        repRange = RepRangePolicy(copying: exercisePerformance.repRange)
        restTimePolicy = RestTimePolicy(copying: exercisePerformance.restTimePolicy)
        self.planSnapshot = planSnapshot
        sets = exercisePerformance.sortedSets.map { SetPrescription(exercisePrescription: self, setPerformance: $0) }
    }
    
    // Deep copy for versioned editing
    init(copying source: ExercisePrescription, planSnapshot: PlanSnapshot) {
        index = source.index
        catalogID = source.catalogID
        name = source.name
        notes = source.notes
        musclesTargeted = source.musclesTargeted
        repRange = RepRangePolicy(copying: source.repRange)
        restTimePolicy = RestTimePolicy(copying: source.restTimePolicy)
        self.planSnapshot = planSnapshot
        sets = source.sortedSets.map { SetPrescription(copying: $0, exercisePrescription: self) }
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

import SwiftUI
import SwiftData

@Model
class PlanSnapshot {
    var id: UUID = UUID()
    var versionNumber: Int = 1
    var createdAt: Date = Date()
    var createdBy: PlanCreator = PlanCreator.user
    var notes: String = ""
    @Relationship(deleteRule: .nullify)
    var sourceVersion: PlanSnapshot?
    var workoutPlan: WorkoutPlan?
    @Relationship(deleteRule: .cascade, inverse: \ExercisePrescription.planSnapshot)
    var exercises: [ExercisePrescription] = []
    
    var sortedExercises: [ExercisePrescription] {
        exercises.sorted { $0.index < $1.index }
    }
    
    // New plan
    init(workoutPlan: WorkoutPlan) {
        self.workoutPlan = workoutPlan
    }
    
    // From completed workout session
    init(workoutPlan: WorkoutPlan, workoutSession: WorkoutSession) {
        notes = workoutSession.notes
        self.workoutPlan = workoutPlan
        self.exercises = workoutSession.sortedExercises.map { ExercisePrescription(planSnapshot: self, exercisePerformance: $0) }
    }
    
    // Deep copy for versioned editing
    init(copying source: PlanSnapshot, workoutPlan: WorkoutPlan) {
        versionNumber = source.versionNumber + 1
        createdBy = .user
        notes = source.notes
        sourceVersion = source
        self.workoutPlan = workoutPlan
        exercises = source.sortedExercises.map { ExercisePrescription(copying: $0, planSnapshot: self) }
    }

    func addExercise(_ exercise: Exercise) {
        exercises.append(ExercisePrescription(exercise: exercise, planSnapshot: self))
    }
    
    func moveExercise(from source: IndexSet, to destination: Int) {
        var sortedEx = sortedExercises
        sortedEx.move(fromOffsets: source, toOffset: destination)
        for (index, exercise) in sortedEx.enumerated() {
            exercise.index = index
        }
    }
    
    func deleteExercise(_ exercise: ExercisePrescription) {
        exercises.removeAll(where: { $0 == exercise })
        for (index, exercise) in sortedExercises.enumerated() {
            exercise.index = index
        }
    }
}

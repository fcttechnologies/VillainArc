import SwiftUI
import SwiftData

@Model
class Workout {
    var title: String = ""
    var notes: String = ""
    var completed: Bool = false
    var startTime: Date = Date.now
    var endTime: Date? = nil
    @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.workout)
    var exercises: [WorkoutExercise] = []
    
    var sortedExercises: [WorkoutExercise] {
        exercises.sorted { $0.index < $1.index }
    }
    
    init(title: String = "New Workout") {
        self.title = title
    }
    
    func addExercise(_ exercise: Exercise) {
        let workoutExercise = WorkoutExercise(from: exercise, workout: self)
        exercises.append(workoutExercise)
    }
    
    func removeExercise(_ exercise: WorkoutExercise) {
        exercises.removeAll { $0 == exercise }

        for (index, workoutExercise) in sortedExercises.enumerated() {
            workoutExercise.index = index
        }
    }
    
    func moveExercise(from source: IndexSet, to destination: Int) {
        var sortedEx = sortedExercises
        sortedEx.move(fromOffsets: source, toOffset: destination)
        
        for (index, workoutExercise) in sortedEx.enumerated() {
            workoutExercise.index = index
        }
    }
    
    // Testing
    init(title: String, notes: String = "", completed: Bool = false, endTime: Date? = nil) {
        self.title = title
        self.notes = notes
        self.completed = completed
        self.endTime = endTime
    }
}

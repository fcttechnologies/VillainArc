import Foundation
import SwiftData

@Model
class WorkoutExercise {
    var index: Int
    var name: String = ""
    var notes: String = ""
    var repRange: RepRange = RepRange.notSet
    var date: Date = Date.now
    var musclesTargeted: [Muscle] = []
    var workout: Workout?
    @Relationship(deleteRule: .cascade)
    var sets: [ExerciseSet] = []
    
    var displayMuscle: String {
        musclesTargeted.filter(\.isMajor).first?.rawValue ?? ""
    }
    
    var sortedSets: [ExerciseSet] {
        sets.sorted { $0.index < $1.index }
    }
    
    init(from exercise: Exercise, workout: Workout?) {
        index = workout?.exercises.count ?? 0
        name = exercise.name
        musclesTargeted = exercise.musclesTargeted
        self.workout = workout
    }
    
    func addSet() {
        if let previous = sortedSets.last {
            sets.append(ExerciseSet(index: sets.count, weight: previous.weight, reps: previous.reps))
        } else {
            sets.append(ExerciseSet(index: sets.count))
        }
    }
    
    func removeSet(_ set: ExerciseSet) {
        sets.removeAll { $0 == set }
        
        for (index, exerciseSet) in sortedSets.enumerated() {
            exerciseSet.index = index
        }
    }
    
    // Testing
    init(index: Int, name: String, notes: String = "", repRange: RepRange = .notSet, musclesTargeted: [Muscle], workout: Workout?, sets: [ExerciseSet]) {
        self.index = index
        self.name = name
        self.notes = notes
        self.repRange = repRange
        self.musclesTargeted = musclesTargeted
        self.workout = workout
        self.sets = sets
    }
}

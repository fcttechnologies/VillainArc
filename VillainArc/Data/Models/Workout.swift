import SwiftUI
import SwiftData

@Model
class Workout {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    var completed: Bool = false
    var startTime: Date = Date.now
    var endTime: Date? = nil
    @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.workout)
    var exercises: [WorkoutExercise] = []
    @Relationship(deleteRule: .nullify)
    var sourceTemplate: WorkoutTemplate?
    
    var sortedExercises: [WorkoutExercise] {
        exercises.sorted { $0.index < $1.index }
    }
    
    init(title: String = "New Workout") {
        self.title = title
    }

    init(previous workout: Workout) {
        title = workout.title
        notes = workout.notes
        exercises = workout.sortedExercises.map { WorkoutExercise(previous: $0, workout: self) }
    }

    init(from template: WorkoutTemplate) {
        title = template.name
        notes = template.notes
        sourceTemplate = template
        exercises = template.sortedExercises.map { WorkoutExercise(from: $0, workout: self) }
    }
    
    func addExercise(_ exercise: Exercise, markSetsComplete: Bool = false) {
        let workoutExercise = WorkoutExercise(from: exercise, workout: self, markSetsComplete: markSetsComplete)
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
    init(title: String, notes: String = "", completed: Bool = false, startTime: Date, endTime: Date) {
        self.title = title
        self.notes = notes
        self.completed = completed
        self.startTime = startTime
        self.endTime = endTime
    }
}

extension Workout {
    static var recencySortDescriptors: [SortDescriptor<Workout>] {
        [SortDescriptor(\Workout.startTime, order: .reverse)]
    }

    static func completedWorkouts(limit: Int? = nil) -> FetchDescriptor<Workout> {
        let predicate = #Predicate<Workout> { $0.completed }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: recencySortDescriptors)
        if let limit {
            descriptor.fetchLimit = limit
        }
        return descriptor
    }

    static var incomplete: FetchDescriptor<Workout> {
        let predicate = #Predicate<Workout> { !$0.completed }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: recencySortDescriptors)
        descriptor.fetchLimit = 1
        return descriptor
    }

    static var recentWorkout: FetchDescriptor<Workout> {
        completedWorkouts(limit: 1)
    }

    static var completedWorkouts: FetchDescriptor<Workout> {
        completedWorkouts()
    }
}

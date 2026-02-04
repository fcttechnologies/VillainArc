import SwiftUI
import SwiftData

@Model
class WorkoutPlan {
    var id: UUID = UUID()
    var title: String = "New Workout Plan"
    var notes: String = ""
    var favorite: Bool = false
    var completed: Bool = false
    var isEditing: Bool = false
    var lastUsed: Date?
    @Relationship(deleteRule: .cascade, inverse: \ExercisePrescription.workoutPlan)
    var exercises: [ExercisePrescription] = []
    @Relationship(deleteRule: .nullify, inverse: \WorkoutSplitDay.workoutPlan)
    var splitDays: [WorkoutSplitDay] = []
    
    // Reference to original plan when this is an editing copy (nil on originals)
    @Relationship(deleteRule: .nullify)
    var originalPlan: WorkoutPlan?
    
    var sortedExercises: [ExercisePrescription] {
        exercises.sorted { $0.index < $1.index }
    }
    
    init() {}
    
    init(from session: WorkoutSession, completed: Bool = false) {
        title = session.title
        notes = session.notes
        self.completed = completed
        exercises = session.sortedExercises.map { ExercisePrescription(workoutPlan: self, exercisePerformance: $0) }
    }
    
    func musclesTargeted() -> String {
        ListFormatter.localizedString(byJoining: majorMuscles.map(\.rawValue))
    }

    var musclesArray: [Muscle] {
        var seen = Set<Muscle>()
        var result: [Muscle] = []
        for exercise in sortedExercises {
            for muscle in exercise.musclesTargeted where !seen.contains(muscle) {
                seen.insert(muscle)
                result.append(muscle)
            }
        }
        return result
    }

    var majorMuscles: [Muscle] {
        var seen = Set<Muscle>()
        var result: [Muscle] = []
        for exercise in sortedExercises {
            if let major = exercise.musclesTargeted.first(where: \.isMajor), !seen.contains(major) {
                seen.insert(major)
                result.append(major)
            }
        }
        return result
    }
    
    func addExercise(_ exercise: Exercise) {
        exercises.append(ExercisePrescription(exercise: exercise, workoutPlan: self))
    }
    
    func deleteExercise(_ exercise: ExercisePrescription) {
        exercises.removeAll { $0 == exercise }
        reindexExercises()
    }
    
    func moveExercise(from source: IndexSet, to destination: Int) {
        var sorted = sortedExercises
        sorted.move(fromOffsets: source, toOffset: destination)
        for (i, ex) in sorted.enumerated() { ex.index = i }
    }
    
    private func reindexExercises() {
        for (i, ex) in sortedExercises.enumerated() { ex.index = i }
    }
}

extension WorkoutPlan {
    var spotlightSummary: String {
        let exerciseSummaries = sortedExercises.map { exercise in
            "\(exercise.sets.count)x \(exercise.name)"
        }
        return exerciseSummaries.joined(separator: ",")
    }
    
    static var incomplete: FetchDescriptor<WorkoutPlan> {
        let predicate = #Predicate<WorkoutPlan> { !$0.completed || $0.isEditing }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        return descriptor
    }

    static var completedPredicate: Predicate<WorkoutPlan> {
        #Predicate<WorkoutPlan> { $0.completed && !$0.isEditing }
    }

    static var recentsSort: [SortDescriptor<WorkoutPlan>] {
        [
            SortDescriptor(\WorkoutPlan.lastUsed, order: .reverse),
            SortDescriptor(\WorkoutPlan.title)
        ]
    }
    
    static var all: FetchDescriptor<WorkoutPlan> {
        return FetchDescriptor(predicate: completedPredicate, sortBy: recentsSort)
    }
    
    static var recent: FetchDescriptor<WorkoutPlan> {
        var descriptor = FetchDescriptor(predicate: completedPredicate, sortBy: recentsSort)
        descriptor.fetchLimit = 1
        return descriptor
    }
}

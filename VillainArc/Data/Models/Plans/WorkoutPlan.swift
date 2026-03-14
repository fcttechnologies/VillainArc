import SwiftUI
import SwiftData

@Model
final class WorkoutPlan {
    #Index<WorkoutPlan>([\.completed], [\.isEditing], [\.lastUsed])

    var id: UUID = UUID()
    var title: String = "New Workout Plan"
    var notes: String = ""
    var favorite: Bool = false
    var completed: Bool = false
    var isEditing: Bool = false
    var lastUsed: Date?
    @Relationship(deleteRule: .cascade, inverse: \ExercisePrescription.workoutPlan)
    var exercises: [ExercisePrescription]? = [ExercisePrescription]()
    @Relationship(deleteRule: .nullify, inverse: \WorkoutSplitDay.workoutPlan)
    var splitDays: [WorkoutSplitDay]? = [WorkoutSplitDay]()
    var workoutSessions: [WorkoutSession]? = [WorkoutSession]()

    var sortedExercises: [ExercisePrescription] {
        (exercises ?? []).sorted { $0.index < $1.index }
    }

    func convertTargetWeightsToKg(from unit: WeightUnit) {
        guard unit == .lbs else { return }
        for exercise in exercises ?? [] {
            for set in exercise.sets ?? [] {
                set.targetWeight = unit.toKg(set.targetWeight)
            }
        }
    }

    func convertTargetWeightsFromKg(to unit: WeightUnit) {
        guard unit == .lbs else { return }
        for exercise in exercises ?? [] {
            for set in exercise.sets ?? [] {
                set.targetWeight = (unit.fromKg(set.targetWeight) * 100).rounded() / 100
            }
        }
    }

    init() {}

    // Test/sample initializer to reduce setup boilerplate.
    convenience init(title: String = "New Workout Plan", notes: String = "", favorite: Bool = false, completed: Bool = false, lastUsed: Date? = nil) {
        self.init()
        self.title = title
        self.notes = notes
        self.favorite = favorite
        self.completed = completed
        self.lastUsed = lastUsed
    }
    
    init(from session: WorkoutSession, completed: Bool = false) {
        title = session.title
        notes = session.notes
        self.completed = completed
        if completed {
            lastUsed = Date()
        }
        exercises = session.sortedExercises.map { ExercisePrescription(workoutPlan: self, exercisePerformance: $0) }
    }

    func clearCompletedSessionPerformanceReferences() {
        for session in workoutSessions ?? [] where session.statusValue == .done {
            session.clearPrescriptionLinksForHistoricalUse()
        }
    }
    
    func musclesTargeted() -> String {
        ListFormatter.localizedString(byJoining: majorMuscles.map(\.displayName))
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
        exercises?.append(ExercisePrescription(exercise: exercise, workoutPlan: self))
    }
    
    func deleteExercise(_ exercise: ExercisePrescription) {
        exercises?.removeAll { $0 == exercise }
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
            let setCount = exercise.sets?.count ?? 0
            return "\(setCount)x \(exercise.name)"
        }
        return exerciseSummaries.joined(separator: ", ")
    }
    
    static var incomplete: FetchDescriptor<WorkoutPlan> {
        let predicate = #Predicate<WorkoutPlan> { !$0.completed || $0.isEditing }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        return descriptor
    }

    static var resumableIncomplete: FetchDescriptor<WorkoutPlan> {
        let predicate = #Predicate<WorkoutPlan> { !$0.completed && !$0.isEditing }
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
        var descriptor = FetchDescriptor(predicate: completedPredicate, sortBy: recentsSort)
        descriptor.relationshipKeyPathsForPrefetching = [\.exercises]
        return descriptor
    }

    static var editingCopies: FetchDescriptor<WorkoutPlan> {
        let predicate = #Predicate<WorkoutPlan> { $0.isEditing }
        return FetchDescriptor(predicate: predicate)
    }

    static var recent: FetchDescriptor<WorkoutPlan> {
        var descriptor = FetchDescriptor(predicate: completedPredicate, sortBy: recentsSort)
        descriptor.relationshipKeyPathsForPrefetching = [\.exercises]
        descriptor.fetchLimit = 1
        return descriptor
    }
}

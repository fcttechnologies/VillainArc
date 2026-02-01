import SwiftUI
import SwiftData

@Model
class WorkoutPlan {
    var id: UUID = UUID()
    var title: String = "New Workout Plan"
    var favorite: Bool = false
    var completed: Bool = false
    var isEditing: Bool = false
    var lastUsed: Date?
    @Relationship(deleteRule: .cascade)
    var currentVersion: PlanSnapshot?
    @Relationship(deleteRule: .cascade, inverse: \PlanSnapshot.workoutPlan)
    var versions: [PlanSnapshot] = []
    @Relationship(deleteRule: .nullify, inverse: \WorkoutSplitDay.workoutPlan)
    var splitDays: [WorkoutSplitDay] = []
    
    var notes: String {
        currentVersion?.notes ?? ""
    }
    
    var sortedExercises: [ExercisePrescription] {
        currentVersion?.sortedExercises ?? []
    }
    
    init() {
        let newSnapshot = PlanSnapshot(workoutPlan: self)
        currentVersion = newSnapshot
        versions.append(newSnapshot)
    }
    
    init(from session: WorkoutSession) {
        title = session.title
        let snapshot = PlanSnapshot(workoutPlan: self, workoutSession: session)
        currentVersion = snapshot
        versions.append(snapshot)
    }
    
    func musclesTargeted() -> String {
        var seen = Set<Muscle>()
        var result: [Muscle] = []
        let exercises = currentVersion?.sortedExercises ?? []
        for exercise in exercises {
            if let major = exercise.musclesTargeted.first(where: \.isMajor), !seen.contains(major) {
                seen.insert(major)
                result.append(major)
            }
        }
        return ListFormatter.localizedString(byJoining: result.map(\.rawValue))
    }
    
    func addExercise(_ exercise: Exercise) {
        guard let currentVersion else { return }
        currentVersion.addExercise(exercise)
    }
    
    func deleteExercise(_ exercise: ExercisePrescription) {
        guard let currentVersion else { return }
        currentVersion.deleteExercise(exercise)
    }
    
    func moveExercise(from source: IndexSet, to destination: Int) {
        guard let currentVersion else { return }
        currentVersion.moveExercise(from: source, to: destination)
    }

    func startEditing() {
        guard let currentVersion, !isEditing else { return }
        let editingSnapshot = PlanSnapshot(copying: currentVersion, workoutPlan: self)
        versions.append(editingSnapshot)
        self.currentVersion = editingSnapshot
        isEditing = true
    }

    func cancelEditing(context: ModelContext) {
        guard isEditing, let editingSnapshot = currentVersion,
              let previousVersion = editingSnapshot.sourceVersion else { return }
        self.currentVersion = previousVersion
        isEditing = false
        versions.removeAll { $0 === editingSnapshot }
        context.delete(editingSnapshot)
    }

    func finishEditing() {
        guard isEditing else { return }
        isEditing = false
    }
}

extension WorkoutPlan {
    var spotlightSummary: String {
        guard let currentVersion else { return "" }
        let exerciseSummaries = currentVersion.sortedExercises.map { exercise in
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

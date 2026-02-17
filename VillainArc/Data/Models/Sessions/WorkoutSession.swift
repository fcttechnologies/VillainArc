import SwiftUI
import SwiftData

@Model
class WorkoutSession {
    var id: UUID = UUID()
    var title: String = "New Workout"
    var notes: String = ""
    var status: String = SessionStatus.active.rawValue
    var startedAt: Date = Date()
    var endedAt: Date?
    var origin: SessionOrigin = SessionOrigin.freeform
    
    var statusValue: SessionStatus {
        get { SessionStatus(rawValue: status) ?? .active }
        set { status = newValue.rawValue }
    }
    @Relationship(deleteRule: .cascade, inverse: \PreWorkoutStatus.workoutSession)
    var preStatus: PreWorkoutStatus? = PreWorkoutStatus()
    var postEffort: Int = 0
    @Relationship(deleteRule: .nullify, inverse: \WorkoutPlan.workoutSessions)
    var workoutPlan: WorkoutPlan?
    @Relationship(deleteRule: .cascade, inverse: \ExercisePerformance.workoutSession)
    var exercises: [ExercisePerformance]? = [ExercisePerformance]()
    @Relationship(deleteRule: .nullify, inverse: \ExercisePerformance.activeInSession)
    var activeExercise: ExercisePerformance?
    var createdPrescriptionChanges: [PrescriptionChange]? = [PrescriptionChange]()
    var evaluatedPrescriptionChanges: [PrescriptionChange]? = [PrescriptionChange]()
    
    var sortedExercises: [ExercisePerformance] {
        (exercises ?? []).sorted { $0.index < $1.index }
    }
    
    // New session
    init() {}

    // Test/sample initializer to reduce setup boilerplate.
    convenience init(title: String = "New Workout", notes: String = "", status: SessionStatus = .active, startedAt: Date = Date(), endedAt: Date? = nil, origin: SessionOrigin = .freeform) {
        self.init()
        self.title = title
        self.notes = notes
        self.statusValue = status
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.origin = origin
    }

    // From workout plan
    init(from plan: WorkoutPlan) {
        title = plan.title
        notes = plan.notes
        origin = .plan
        workoutPlan = plan
        exercises = plan.sortedExercises.map { ExercisePerformance(workoutSession: self, exercisePrescription: $0) }
    }
    
    func addExercise(_ exercise: Exercise) {
        exercises?.append(ExercisePerformance(exercise: exercise, workoutSession: self))
    }
    
    func moveExercise(from source: IndexSet, to destination: Int) {
        var sortedEx = sortedExercises
        sortedEx.move(fromOffsets: source, toOffset: destination)
        for (index, exercise) in sortedEx.enumerated() {
            exercise.index = index
        }
    }

    func deleteExercise(_ exercise: ExercisePerformance) {
        exercises?.removeAll(where: { $0 == exercise })
        for (index, exercise) in sortedExercises.enumerated() {
            exercise.index = index
        }
    }
}

enum WorkoutFinishAction {
    case markLoggedComplete
    case deleteUnfinished
    case deleteEmpty
    case finish
}

enum WorkoutFinishResult {
    case finished
    case workoutDeleted
}

enum UnfinishedSetCase {
    case none
    case emptyOnly
    case loggedOnly
    case emptyAndLogged
}

struct UnfinishedSetSummary {
    let emptySets: [SetPerformance]
    let loggedSets: [SetPerformance]

    var emptyCount: Int { emptySets.count }
    var loggedCount: Int { loggedSets.count }
    var hasEmpty: Bool { !emptySets.isEmpty }
    var hasLogged: Bool { !loggedSets.isEmpty }

    var caseType: UnfinishedSetCase {
        if hasEmpty && hasLogged {
            return .emptyAndLogged
        }
        if hasEmpty {
            return .emptyOnly
        }
        if hasLogged {
            return .loggedOnly
        }
        return .none
    }
}

extension WorkoutSession {
    @MainActor var unfinishedSetSummary: UnfinishedSetSummary {
        var emptySets: [SetPerformance] = []
        var loggedSets: [SetPerformance] = []

        for exercise in exercises ?? [] {
            for set in exercise.sets ?? [] where !set.complete {
                if set.reps == 0 && set.weight == 0 {
                    emptySets.append(set)
                } else {
                    loggedSets.append(set)
                }
            }
        }

        return UnfinishedSetSummary(emptySets: emptySets, loggedSets: loggedSets)
    }

    var exerciseSummary: String {
        let exerciseSummaries = sortedExercises.map { exercise in
            let setCount = exercise.sets?.count ?? 0
            let setWord = setCount == 1 ? "set" : "sets"
            return "\(setCount) \(setWord) of \(exercise.name)"
        }
        return ListFormatter.localizedString(byJoining: exerciseSummaries)
    }
    
    var spotlightSummary: String {
        let exerciseSummaries = sortedExercises.map { exercise in
            "\(String(describing: exercise.sets?.count))x \(exercise.name)"
        }
        return exerciseSummaries.joined(separator: ", ")
    }
    
    static func completedSessions(limit: Int? = nil) -> FetchDescriptor<WorkoutSession> {
        let done = SessionStatus.done.rawValue
        let predicate = #Predicate<WorkoutSession> { $0.status == done }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        if let limit {
            descriptor.fetchLimit = limit
        }
        return descriptor
    }
    
    static var recent: FetchDescriptor<WorkoutSession> {
        completedSessions(limit: 1)
    }
    
    static var completedSession: FetchDescriptor<WorkoutSession> {
        completedSessions()
    }
    
    static var incomplete: FetchDescriptor<WorkoutSession> {
        let done = SessionStatus.done.rawValue
        let predicate = #Predicate<WorkoutSession> { $0.status != done }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        return descriptor
    }
    
    func activeExerciseAndSet() -> (exercise: ExercisePerformance, set: SetPerformance)? {
        for exercise in sortedExercises {
            if let set = exercise.sortedSets.first(where: { !$0.complete }) {
                return (exercise, set)
            }
        }
        return nil
    }
    
    @MainActor
    func finish(action: WorkoutFinishAction, context: ModelContext) -> WorkoutFinishResult {
        let summary = unfinishedSetSummary
        
        switch action {
        case .markLoggedComplete:
            for set in summary.loggedSets {
                set.complete = true
                set.completedAt = Date()
            }
            if summary.hasEmpty {
                for set in summary.emptySets {
                    set.exercise?.deleteSet(set)
                    context.delete(set)
                }
                if pruneEmptyExercises(context: context) {
                    return .workoutDeleted
                }
            }
        case .deleteUnfinished:
            let setsToDelete = summary.loggedSets + summary.emptySets
            for set in setsToDelete {
                set.exercise?.deleteSet(set)
                context.delete(set)
            }
            if pruneEmptyExercises(context: context) {
                return .workoutDeleted
            }
        case .deleteEmpty:
            for set in summary.emptySets {
                set.exercise?.deleteSet(set)
                context.delete(set)
            }
            if pruneEmptyExercises(context: context) {
                return .workoutDeleted
            }
        case .finish:
            break
        }
        
        status = SessionStatus.summary.rawValue
        endedAt = Date()
        activeExercise = nil
        return .finished
    }
    
    private func pruneEmptyExercises(context: ModelContext) -> Bool {
        let emptyExercises = exercises?.filter { $0.sets?.isEmpty ?? true } ?? []
        for exercise in emptyExercises {
            deleteExercise(exercise)
            context.delete(exercise)
        }
        if exercises?.isEmpty ?? true {
            context.delete(self)
            return true
        }
        return false
    }
}

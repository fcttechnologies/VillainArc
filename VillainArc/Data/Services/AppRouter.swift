import CoreSpotlight
import SwiftUI
import SwiftData

@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()
    var activeWorkoutSession: WorkoutSession?
    var activeWorkoutPlan: WorkoutPlan? {
        didSet {
            if activeWorkoutPlan == nil {
                activeWorkoutPlanOriginal = nil
            }
        }
    }
    var activeWorkoutPlanOriginal: WorkoutPlan?
    var showAddExerciseFromLiveActivity = false
    var showWorkoutSplitListFromIntent = false
    var showWorkoutSettingsFromIntent = false
    var showRestTimerFromIntent = false
    var showPreWorkoutContextFromIntent = false
    
    enum Destination: Hashable {
        case workoutSessionsList
        case workoutSessionDetail(WorkoutSession)
        case workoutPlansList
        case workoutPlanDetail(WorkoutPlan, Bool)
        case exercisesList
        case exerciseDetail(String)
        case exerciseHistory(String)
        case workoutSplit(autoPresentBuilder: Bool)
    }
    
    var path = NavigationPath()
    
    private init() {}
    
    private var context: ModelContext {
        SharedModelContainer.container.mainContext
    }

    private var hasPresentedFlow: Bool {
        activeWorkoutSession != nil || activeWorkoutPlan != nil
    }

    private func hasPersistedIncompleteWorkoutSession() -> Bool {
        (try? context.fetch(WorkoutSession.incomplete).first) != nil
    }

    private func hasPersistedActivePlanWork() -> Bool {
        (try? context.fetch(WorkoutPlan.incomplete).first) != nil
    }

    private func hasActiveFlow() -> Bool {
        hasPresentedFlow || hasPersistedIncompleteWorkoutSession() || hasPersistedActivePlanWork()
    }
    
    func navigate(to destination: Destination) {
        path.append(destination)
    }
    
    func popToRoot() {
        path = NavigationPath()
    }

    func startWorkoutSession() {
        guard !hasActiveFlow() else { return }
        Haptics.selection()
        let newWorkout = WorkoutSession()
        context.insert(newWorkout)
        saveContext(context: context)
        activeWorkoutSession = newWorkout
    }
    
    func createWorkoutPlan() {
        guard !hasActiveFlow() else { return }
        Haptics.selection()
        let newWorkoutPlan = WorkoutPlan()
        context.insert(newWorkoutPlan)
        saveContext(context: context)
        activeWorkoutPlanOriginal = nil
        activeWorkoutPlan = newWorkoutPlan
    }

    func editWorkoutPlan(_ plan: WorkoutPlan) {
        guard !hasActiveFlow(), plan.completed, !plan.isEditing else { return }
        Haptics.selection()
        let editingCopy = plan.createEditingCopy(context: context)
        saveContext(context: context)
        activeWorkoutPlanOriginal = plan
        activeWorkoutPlan = editingCopy
    }
    
    func startWorkoutSession(from plan: WorkoutPlan) {
        guard !hasActiveFlow() else { return }
        Haptics.selection()
        let workoutSession = WorkoutSession(from: plan)
        
        // Check for pending/deferred suggestions before starting
        let hasDeferredSuggestions = !pendingSuggestionEvents(for: plan, in: context).isEmpty
        if hasDeferredSuggestions {
            workoutSession.status = SessionStatus.pending.rawValue
        }
        
        context.insert(workoutSession)
        saveContext(context: context)
        activeWorkoutSession = workoutSession
    }

    func resumeWorkoutSession(_ workoutSession: WorkoutSession) {
        Haptics.selection()
        activeWorkoutSession = workoutSession
    }
    
    func resumeWorkoutPlanCreation(_ workoutPlan: WorkoutPlan) {
        Haptics.selection()
        activeWorkoutPlanOriginal = nil
        activeWorkoutPlan = workoutPlan
    }
    
    func checkForUnfinishedData() {
        guard !hasPresentedFlow else { return }
        if let unfinishedWorkoutSession = try? context.fetch(WorkoutSession.incomplete).first {
            resumeWorkoutSession(unfinishedWorkoutSession)
            return
        }
        if let unfinishedWorkoutPlan = try? context.fetch(WorkoutPlan.resumableIncomplete).first {
            resumeWorkoutPlanCreation(unfinishedWorkoutPlan)
        }
    }

    func handleSiriWorkout(_ userActivity: NSUserActivity) {
        guard !hasActiveFlow() else { return }
        startWorkoutSession()
    }

    func handleSiriCancelWorkout(_ userActivity: NSUserActivity) {
        guard let workoutSession = activeWorkoutSession else { return }
        RestTimerState.shared.stop()
        workoutSession.activeExercise = nil
        context.delete(workoutSession)
        activeWorkoutSession = nil
        WorkoutActivityManager.end()
    }

    func handleSpotlight(_ userActivity: NSUserActivity) {
        guard !hasActiveFlow() else {
            return
        }
        guard let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String else {
            return
        }

        if identifier.hasPrefix(SpotlightIndexer.workoutSessionIdentifierPrefix) {
            let idString = String(identifier.dropFirst(SpotlightIndexer.workoutSessionIdentifierPrefix.count))
            guard let id = UUID(uuidString: idString) else { return }
            let predicate = #Predicate<WorkoutSession> { $0.id == id }
            var descriptor = FetchDescriptor(predicate: predicate)
            descriptor.fetchLimit = 1
            if let workoutSession = try? context.fetch(descriptor).first {
                popToRoot()
                navigate(to: .workoutSessionDetail(workoutSession))
            }
            return
        }

        if identifier.hasPrefix(SpotlightIndexer.workoutPlanIdentifierPrefix) {
            let idString = String(identifier.dropFirst(SpotlightIndexer.workoutPlanIdentifierPrefix.count))
            guard let id = UUID(uuidString: idString) else { return }
            let predicate = #Predicate<WorkoutPlan> { $0.id == id }
            var descriptor = FetchDescriptor(predicate: predicate)
            descriptor.fetchLimit = 1
            if let workoutPlan = try? context.fetch(descriptor).first {
                popToRoot()
                navigate(to: .workoutPlanDetail(workoutPlan, false))
            }
            return
        }

        if identifier.hasPrefix(SpotlightIndexer.exerciseIdentifierPrefix) {
            let catalogID = String(identifier.dropFirst(SpotlightIndexer.exerciseIdentifierPrefix.count))
            guard (try? context.fetch(Exercise.withCatalogID(catalogID)).first) != nil else { return }
            popToRoot()
            navigate(to: .exerciseDetail(catalogID))
        }
    }
}

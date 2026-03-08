import CoreSpotlight
import SwiftUI
import SwiftData

@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()
    var activeWorkoutSession: WorkoutSession?
    var activeWorkoutPlan: WorkoutPlan?
    var showAddExerciseFromLiveActivity = false
    
    enum Destination: Hashable {
        case workoutSessionsList
        case workoutSessionDetail(WorkoutSession)
        case workoutPlansList
        case workoutPlanDetail(WorkoutPlan, Bool)
        case splitList(autoPresentBuilder: Bool)
        case splitDettail(WorkoutSplit)
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
        activeWorkoutPlan = newWorkoutPlan
    }
    
    func startWorkoutSession(from plan: WorkoutPlan) {
        guard !hasActiveFlow() else { return }
        Haptics.selection()
        let workoutSession = WorkoutSession(from: plan)
        
        // Check for pending/deferred suggestions before starting
        let hasDeferredSuggestions = !pendingSuggestions(for: plan).isEmpty
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
        }
    }
}

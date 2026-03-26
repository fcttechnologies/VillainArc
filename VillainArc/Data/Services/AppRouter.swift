import CoreSpotlight
import SwiftData
import SwiftUI

@MainActor @Observable final class AppRouter {
    static let shared = AppRouter()
    var activeWorkoutSession: WorkoutSession?
    var activeWorkoutPlan: WorkoutPlan? { didSet { if activeWorkoutPlan == nil { activeWorkoutPlanOriginal = nil } } }
    var activeWorkoutPlanOriginal: WorkoutPlan?
    var showAddExerciseFromLiveActivity = false
    var showSplitBuilderFromIntent = false
    var showWorkoutSplitListFromIntent = false
    var showWorkoutSettingsFromIntent = false
    var showRestTimerFromIntent = false
    var showPreWorkoutContextFromIntent = false
    var showCancelWorkoutFromIntent = false
    var showFinishWorkoutFromIntent = false
    var tabSelection: Tabs = .home
    enum Destination: Hashable {
        case workoutSessionsList
        case workoutSessionDetail(WorkoutSession)
        case healthWorkoutDetail(HealthWorkout)
        case weightHistory(WeightUnit)
        case allWeightEntriesList(WeightUnit)
        case weightGoalHistory(WeightUnit)
        case workoutPlansList
        case workoutPlanDetail(WorkoutPlan, Bool)
        case exercisesList
        case exerciseDetail(String)
        case exerciseHistory(String)
        case workoutSplit(autoPresentBuilder: Bool)
        case workoutSplitDetail(WorkoutSplit)
    }

    var homeTabPath = NavigationPath()
    var healthTabPath = NavigationPath()
    private init() {}
    private var context: ModelContext { SharedModelContainer.container.mainContext }

    private func weightUnit() -> WeightUnit { (try? context.fetch(AppSettings.single))?.first?.weightUnit ?? .lbs }

    private var hasPresentedFlow: Bool { activeWorkoutSession != nil || activeWorkoutPlan != nil }

    private func hasPersistedIncompleteWorkoutSession() -> Bool { (try? context.fetch(WorkoutSession.incomplete).first) != nil }

    private func hasPersistedActivePlanWork() -> Bool { (try? context.fetch(WorkoutPlan.incomplete).first) != nil }

    private func hasActiveFlow() -> Bool { hasPresentedFlow || hasPersistedIncompleteWorkoutSession() || hasPersistedActivePlanWork() }

    private func isReadyForIntentActions() -> Bool {
        do {
            try SetupGuard.requireReady(context: context)
            return true
        } catch { return false }
    }

    private func incompleteWorkoutSession() -> WorkoutSession? { try? context.fetch(WorkoutSession.incomplete).first }

    func cancelWorkoutSession(_ workoutSession: WorkoutSession) {
        RestTimerState.shared.stop()
        HealthLiveWorkoutSessionCoordinator.shared.discardIfRunning(for: workoutSession)
        context.delete(workoutSession)
        saveContext(context: context)
        if activeWorkoutSession?.id == workoutSession.id { activeWorkoutSession = nil }
        WorkoutActivityManager.end()
    }
    func navigate(to destination: Destination) {
        switch destination {
        case .weightHistory(_), .allWeightEntriesList(_), .weightGoalHistory(_):
            tabSelection = .health
            healthTabPath.append(destination)
        default:
            tabSelection = .home
            homeTabPath.append(destination)
        }
    }
    func popToRoot() {
        tabSelection = .home
        homeTabPath = NavigationPath()
        healthTabPath = NavigationPath()
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

    func createWorkoutPlan(from workout: WorkoutSession) {
        guard !hasActiveFlow() else { return }
        Haptics.selection()
        let newWorkoutPlan = WorkoutPlan(from: workout)
        newWorkoutPlan.convertTargetWeightsFromKg(to: weightUnit())
        context.insert(newWorkoutPlan)
        workout.workoutPlan = newWorkoutPlan
        saveContext(context: context)
        activeWorkoutPlanOriginal = nil
        activeWorkoutPlan = newWorkoutPlan
    }

    func editWorkoutPlan(_ plan: WorkoutPlan) {
        guard !hasActiveFlow(), plan.completed, !plan.isEditing else { return }
        Haptics.selection()
        let editingCopy = plan.createEditingCopy(context: context)
        editingCopy.convertTargetWeightsFromKg(to: weightUnit())
        saveContext(context: context)
        activeWorkoutPlanOriginal = plan
        activeWorkoutPlan = editingCopy
    }

    func startWorkoutSession(from plan: WorkoutPlan) {
        guard !hasActiveFlow() else { return }
        Haptics.selection()
        let workoutSession = WorkoutSession(from: plan)
        workoutSession.convertSetWeightsFromKg(to: weightUnit())

        // Check for pending/deferred suggestions before starting
        let hasDeferredSuggestions = !pendingSuggestionEvents(for: plan, in: context).isEmpty
        if hasDeferredSuggestions { workoutSession.status = SessionStatus.pending.rawValue }

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
        if let unfinishedWorkoutPlan = try? context.fetch(WorkoutPlan.resumableIncomplete).first { resumeWorkoutPlanCreation(unfinishedWorkoutPlan) }
    }

    func handleSiriWorkout(_ userActivity: NSUserActivity) {
        guard isReadyForIntentActions() else { return }
        guard !hasActiveFlow() else { return }
        startWorkoutSession()
    }

    func handleSiriCancelWorkout(_ userActivity: NSUserActivity) {
        guard isReadyForIntentActions() else { return }
        guard let workoutSession = incompleteWorkoutSession() else { return }

        switch workoutSession.statusValue {
        case .pending: cancelWorkoutSession(workoutSession)
        case .active:
            if workoutSession.exercises?.isEmpty ?? true {
                cancelWorkoutSession(workoutSession)
            } else {
                activeWorkoutSession = workoutSession
                showCancelWorkoutFromIntent = true
            }
        case .summary, .done: activeWorkoutSession = workoutSession
        }
    }

    func handleSiriEndWorkout(_ userActivity: NSUserActivity) {
        guard isReadyForIntentActions() else { return }
        guard let workoutSession = incompleteWorkoutSession() else { return }

        activeWorkoutSession = workoutSession

        guard workoutSession.statusValue == .active else { return }
        guard !(workoutSession.exercises?.isEmpty ?? true) else { return }

        showFinishWorkoutFromIntent = true
    }

    func handleSpotlight(_ userActivity: NSUserActivity) {
        guard !hasActiveFlow() else { return }
        guard let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String else { return }

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
            return
        }

        if identifier.hasPrefix(SpotlightIndexer.workoutSplitIdentifierPrefix) {
            let idString = String(identifier.dropFirst(SpotlightIndexer.workoutSplitIdentifierPrefix.count))
            guard let id = UUID(uuidString: idString) else { return }
            let predicate = #Predicate<WorkoutSplit> { $0.id == id }
            var descriptor = FetchDescriptor(predicate: predicate)
            descriptor.fetchLimit = 1
            if let workoutSplit = try? context.fetch(descriptor).first {
                popToRoot()
                navigate(to: .workoutSplitDetail(workoutSplit))
            }
        }
    }
}

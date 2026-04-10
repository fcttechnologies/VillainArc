import CoreSpotlight
import SwiftData
import SwiftUI
import UIKit

enum HomeQuickAction: String {
    case addWeightEntry = "com.villainarc.quickaction.addWeightEntry"
    case startTodaysWorkout = "com.villainarc.quickaction.startTodaysWorkout"

    init?(shortcutItem: UIApplicationShortcutItem) {
        self.init(rawValue: shortcutItem.type)
    }
}

@Observable final class AppRouter {
    private static let selectedTabDefaultsKey = "selected_tab"

    struct WeightGoalCompletionRoute: Identifiable, Hashable {
        enum Trigger: String, Hashable {
            case achievedByEntry
            case manualCompletion
        }

        let id = UUID()
        let goalID: UUID
        let triggeringEntryID: UUID?
        let trigger: Trigger
        let referenceDate: Date
    }

    enum HealthSheet: String, Identifiable {
        case addWeightEntry
        case trainingConditionEditor
        case newWeightGoal
        case newStepsGoal

        var id: String { rawValue }
    }

    enum SplitSheet: String, Identifiable {
        case builder
        case list

        var id: String { rawValue }
    }

    enum AdditionalQuickActionContext: Hashable {
        case workoutSplit
        case workoutPlanDetail(WorkoutPlan, showsUseOnly: Bool)
        case weightGoalHistory
        case stepsGoalHistory
    }

    enum WorkoutSheet: Hashable, Identifiable {
        case addExercise
        case restTimer
        case preWorkoutContext
        case settings
        case effortPrompt(WorkoutFinishAction)

        var id: String {
            switch self {
            case .addExercise:
                return "addExercise"
            case .restTimer:
                return "restTimer"
            case .preWorkoutContext:
                return "preWorkoutContext"
            case .settings:
                return "settings"
            case .effortPrompt(let action):
                switch action {
                case .markLoggedComplete:
                    return "effortPrompt-markLoggedComplete"
                case .deleteUnfinished:
                    return "effortPrompt-deleteUnfinished"
                case .deleteEmpty:
                    return "effortPrompt-deleteEmpty"
                case .finish:
                    return "effortPrompt-finish"
                }
            }
        }
    }

    enum WorkoutDialog: String, Identifiable {
        case cancel
        case finish

        var id: String { rawValue }
    }

    static let shared = AppRouter()
    var activeWorkoutSession: WorkoutSession? {
        didSet {
            if activeWorkoutSession == nil {
                activeWorkoutSheet = nil
                activeWorkoutDialog = nil
            }
        }
    }
    var activeWorkoutPlan: WorkoutPlan? { didSet { if activeWorkoutPlan == nil { activeWorkoutPlanOriginal = nil } } }
    var activeWeightGoalCompletion: WeightGoalCompletionRoute?
    @ObservationIgnored var activeWorkoutPlanOriginal: WorkoutPlan?
    @ObservationIgnored var pendingHomeQuickAction: HomeQuickAction?
    @ObservationIgnored var pendingWidgetDestination: Destination?
    var activeHealthSheet: HealthSheet?
    var activeSplitSheet: SplitSheet?
    var activeWorkoutSheet: WorkoutSheet?
    var activeWorkoutDialog: WorkoutDialog?
    var tabSelection: AppTab = .home {
        didSet { persistTabSelection(tabSelection) }
    }
    var navigationEventToken = 0
    var homeTabResetToken = UUID()
    var healthTabResetToken = UUID()
    enum Destination: Hashable {
        case workoutSessionsList
        case workoutSessionDetail(WorkoutSession)
        case healthWorkoutDetail(HealthWorkout)
        case trainingConditionHistory
        case weightHistory
        case sleepHistory
        case stepsDistanceHistory
        case stepsGoalHistory
        case energyHistory
        case allWeightEntriesList
        case weightGoalHistory
        case workoutPlansList
        case workoutPlanDetail(WorkoutPlan, Bool)
        case exercisesList
        case exerciseDetail(String)
        case exerciseHistory(String)
        case workoutSplit(autoPresentBuilder: Bool)
        case workoutSplitDetail(WorkoutSplit)
    }

    var homeTabPath: [Destination] = []
    var healthTabPath: [Destination] = []
    private init() { tabSelection = restoredTabSelection() }
    private var context: ModelContext { SharedModelContainer.container.mainContext }

    var additionalQuickActionContext: AdditionalQuickActionContext? {
        switch tabSelection {
        case .home:
            return additionalQuickActionContext(for: homeTabPath.last)
        case .health:
            return additionalQuickActionContext(for: healthTabPath.last)
        }
    }

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

    private func restoredTabSelection() -> AppTab {
        guard let storedRawValue = SharedModelContainer.sharedDefaults.string(forKey: Self.selectedTabDefaultsKey),
              let storedTab = AppTab(rawValue: storedRawValue)
        else {
            return .home
        }

        return storedTab
    }

    private func persistTabSelection(_ tab: AppTab) { SharedModelContainer.sharedDefaults.set(tab.rawValue, forKey: Self.selectedTabDefaultsKey) }

    func noteNavigationStateChanged() {
        navigationEventToken += 1
    }

    func selectTab(_ tab: AppTab) {
        if tabSelection == tab {
            popToRoot(tab: tab)
            return
        }

        tabSelection = tab
    }

    func handleIncomingURL(_ url: URL) {
        guard let destination = destination(for: url) else { return }
        pendingWidgetDestination = destination
        handlePendingWidgetDestinationIfPossible()
    }

    func handlePendingWidgetDestinationIfPossible() {
        guard let destination = pendingWidgetDestination else { return }
        guard isReadyForIntentActions() else { return }

        if hasActiveFlow() {
            pendingWidgetDestination = nil
            handleBlockedHomeQuickAction()
            return
        }

        pendingWidgetDestination = nil
        popToRoot()
        navigate(to: destination)
    }

    private func destination(for url: URL) -> Destination? {
        guard url.scheme?.localizedLowercase == "villainarc" else { return nil }
        guard url.host?.localizedLowercase == "health" else { return nil }

        switch url.path.localizedLowercase {
        case "/weight-history":
            return .weightHistory
        case "/sleep-history":
            return .sleepHistory
        case "/steps-history":
            return .stepsDistanceHistory
        case "/energy-history":
            return .energyHistory
        default:
            return nil
        }
    }

    func cancelWorkoutSession(_ workoutSession: WorkoutSession) {
        RestTimerState.shared.stop()
        if workoutSession.healthCollectionMode == .watchMirrored {
            WatchWorkoutCommandCoordinator.shared.requestDiscardIfMirrored(for: workoutSession)
        } else {
            HealthLiveWorkoutSessionCoordinator.shared.discardIfRunning(for: workoutSession)
        }
        context.delete(workoutSession)
        saveContext(context: context)
        if activeWorkoutSession?.id == workoutSession.id { activeWorkoutSession = nil }
        WorkoutActivityManager.end()
    }
    func navigate(to destination: Destination) {
        switch destination {
        case .trainingConditionHistory, .weightHistory, .sleepHistory, .stepsDistanceHistory, .stepsGoalHistory, .energyHistory, .allWeightEntriesList, .weightGoalHistory:
            tabSelection = .health
            healthTabPath.append(destination)
        default:
            tabSelection = .home
            homeTabPath.append(destination)
        }
        noteNavigationStateChanged()
    }
    func popToRoot() {
        tabSelection = .home
        homeTabPath = []
        healthTabPath = []
        homeTabResetToken = UUID()
        healthTabResetToken = UUID()
        noteNavigationStateChanged()
    }

    func popToRoot(tab: AppTab) {
        switch tab {
        case .home:
            if homeTabPath.isEmpty { return }
            homeTabPath = []
            homeTabResetToken = UUID()
        case .health:
            if healthTabPath.isEmpty { return }
            healthTabPath = []
            healthTabResetToken = UUID()
        }
        noteNavigationStateChanged()
    }

    private func additionalQuickActionContext(for destination: Destination?) -> AdditionalQuickActionContext? {
        switch destination {
        case .workoutSplit, .workoutSplitDetail:
            return .workoutSplit
        case .workoutPlanDetail(let plan, let showsUseOnly):
            return .workoutPlanDetail(plan, showsUseOnly: showsUseOnly)
        case .weightGoalHistory:
            return .weightGoalHistory
        case .stepsGoalHistory:
            return .stepsGoalHistory
        default:
            return nil
        }
    }

    func presentWeightGoalCompletion(for goal: WeightGoal, trigger: WeightGoalCompletionRoute.Trigger, triggeringEntry: WeightEntry? = nil, referenceDate: Date? = nil) {
        tabSelection = .health
        activeWeightGoalCompletion = WeightGoalCompletionRoute(goalID: goal.id, triggeringEntryID: triggeringEntry?.id, trigger: trigger, referenceDate: referenceDate ?? triggeringEntry?.date ?? .now)
    }

    func receiveHomeQuickAction(_ action: HomeQuickAction) {
        pendingHomeQuickAction = action
        handlePendingHomeQuickActionIfPossible()
    }

    func handlePendingHomeQuickActionIfPossible() {
        guard let action = pendingHomeQuickAction else { return }
        guard isReadyForIntentActions() else { return }

        if hasActiveFlow() {
            pendingHomeQuickAction = nil
            handleBlockedHomeQuickAction()
            return
        }

        pendingHomeQuickAction = nil

        switch action {
        case .addWeightEntry:
            homeTabPath = []
            healthTabPath = []
            tabSelection = .health
            activeHealthSheet = .addWeightEntry

        case .startTodaysWorkout:
            handleStartTodaysWorkoutQuickAction()
        }
    }

    private func handleBlockedHomeQuickAction() {
        if let activeWorkoutSession {
            self.activeWorkoutSession = activeWorkoutSession
            showQuickActionToast(title: "Workout In Progress", message: "Finish or cancel your current workout first.")
            return
        }

        if let unfinishedWorkoutSession = incompleteWorkoutSession() {
            resumeWorkoutSession(unfinishedWorkoutSession)
            showQuickActionToast(title: "Workout In Progress", message: "Finish or cancel your current workout first.")
            return
        }

        if let activeWorkoutPlan {
            self.activeWorkoutPlan = activeWorkoutPlan
            showQuickActionToast(title: "Plan In Progress", message: "Finish or discard your current plan first.")
            return
        }

        if let unfinishedWorkoutPlan = try? context.fetch(WorkoutPlan.resumableIncomplete).first {
            resumeWorkoutPlanCreation(unfinishedWorkoutPlan)
            showQuickActionToast(title: "Plan In Progress", message: "Finish or discard your current plan first.")
        }
    }

    private func handleStartTodaysWorkoutQuickAction() {
        guard let split = try? context.fetch(WorkoutSplit.active).first else {
            showQuickActionToast(title: "No Active Split", message: "Set an active workout split to start today's workout.")
            return
        }

        guard !(split.days?.isEmpty ?? true) else {
            showQuickActionToast(title: "No Split Days", message: "Add days to your split before starting today's workout.")
            return
        }

        let resolution = SplitScheduleResolver.resolve(split, context: context)

        guard let todaysDay = resolution.splitDay else {
            showQuickActionToast(title: "No Workout Today", message: "Villain Arc couldn't determine today's workout.")
            return
        }

        guard !resolution.isPaused else {
            showQuickActionToast(title: "Training Paused", message: resolution.conditionStatusText ?? "Training is currently paused.")
            return
        }

        guard !todaysDay.isRestDay else {
            showQuickActionToast(title: "Rest Day", message: "Today is a rest day. Enjoy your recovery.")
            return
        }

        guard let workoutPlan = resolution.workoutPlan else {
            showQuickActionToast(title: "No Workout Plan", message: "You don't have a workout plan assigned for today.")
            return
        }

        startWorkoutSession(from: workoutPlan)
    }

    private func showQuickActionToast(title: String, message: String) {
        ToastManager.shared.show(.init(title: title, message: message, systemImage: "exclamationmark.circle", tint: .orange, haptic: .warning))
    }

    func startWorkoutSession() {
        guard !hasActiveFlow() else { return }
        Haptics.selection()
        let newWorkout = WorkoutSession()
        context.insert(newWorkout)
        saveContext(context: context)
        activeWorkoutSession = newWorkout
        Task { @MainActor in
            await WatchWorkoutCommandCoordinator.shared.requestWatchStartIfAvailable(for: newWorkout)
        }
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
        guard workoutSession.statusValue == .active else { return }
        Task { @MainActor in
            await WatchWorkoutCommandCoordinator.shared.requestWatchStartIfAvailable(for: workoutSession)
        }
    }

    func isTodaysActiveSplitPlan(_ plan: WorkoutPlan) -> Bool {
        guard let activeSplit = try? context.fetch(WorkoutSplit.active).first else { return false }
        let resolution = SplitScheduleResolver.resolve(activeSplit, context: context, syncProgress: false)
        guard !resolution.isPaused, let todaysPlan = resolution.workoutPlan else { return false }
        return todaysPlan.id == plan.id
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
                activeWorkoutDialog = .cancel
            }
        case .summary, .done: activeWorkoutSession = workoutSession
        }
    }

    func handleSiriEndWorkout(_ userActivity: NSUserActivity) {
        guard isReadyForIntentActions() else { return }
        guard let workoutSession = incompleteWorkoutSession() else { return }
        guard workoutSession.statusValue == .active else { return }
        guard !(workoutSession.exercises?.isEmpty ?? true) else { return }
        presentFinishWorkoutFlow(for: workoutSession)
    }

    func handleWatchOpenAppHandoff(_ userActivity: NSUserActivity) {
        _ = userActivity
        popToRoot()
        if let workoutSession = incompleteWorkoutSession() {
            resumeWorkoutSession(workoutSession)
        }
    }

    func handleWatchOpenActiveWorkoutHandoff(_ userActivity: NSUserActivity) {
        _ = userActivity
        guard let workoutSession = incompleteWorkoutSession() else {
            popToRoot()
            showQuickActionToast(title: "No Active Workout", message: "There isn't an active workout to continue right now.")
            return
        }

        resumeWorkoutSession(workoutSession)
    }

    func presentFinishWorkoutFlow(for workoutSession: WorkoutSession) {
        activeWorkoutSession = workoutSession
        let shouldPromptForPostWorkoutEffort = (try? context.fetch(AppSettings.single).first)?.promptForPostWorkoutEffort ?? true

        if shouldPromptForPostWorkoutEffort, workoutSession.unfinishedSetSummary.caseType == .none {
            activeWorkoutSheet = .effortPrompt(.finish)
        } else {
            activeWorkoutDialog = .finish
        }
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

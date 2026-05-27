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

enum AppSettingsDestination: String, Hashable, Identifiable {
    case workouts
    case appleHealth
    case notifications
    case units
    case debug

    var id: String { rawValue }
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
        case addHydrationEntry
        case trainingConditionEditor
        case newWeightGoal
        case newStepsGoal
        case newSleepGoal
        case newHydrationGoal

        var id: String { rawValue }
    }

    enum SplitSheet: String, Identifiable {
        case builder
        case list

        var id: String { rawValue }
    }

    enum AppSheet: Identifiable {
        case profile
        case settings
        case profileSettings(AppSettingsDestination?)

        var id: String {
            switch self {
            case .profile:
                return "profile"
            case .settings:
                return "settings"
            case let .profileSettings(destination):
                return "profileSettings.\(destination?.rawValue ?? "root")"
            }
        }
    }

    enum AdditionalQuickActionContext: Hashable {
        case healthRoot
        case workoutDetail(WorkoutSession)
        case workoutSplit
        case workoutPlanDetail(WorkoutPlan, showsUseOnly: Bool)
        case weightGoalHistory
        case stepsGoalHistory
        case sleepGoalHistory
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
                isWorkoutSessionCoverPresented = false
            } else {
                isWorkoutSessionCoverPresented = true
            }
        }
    }
    var activeWorkoutPlan: WorkoutPlan? {
        didSet {
            if activeWorkoutPlan == nil {
                activeWorkoutPlanOriginal = nil
                isWorkoutPlanCoverPresented = false
            } else {
                isWorkoutPlanCoverPresented = true
            }
        }
    }
    var activeCardioSession: CardioSession? {
        didSet {
            if activeCardioSession == nil {
                isCardioSessionCoverPresented = false
            } else {
                isCardioSessionCoverPresented = true
            }
        }
    }
    var activeWeightGoalCompletion: WeightGoalCompletionRoute?
    @ObservationIgnored var activeWorkoutPlanOriginal: WorkoutPlan?
    @ObservationIgnored var pendingWorkoutPlanDismissCleanup: (() -> Void)?
    @ObservationIgnored var pendingHomeQuickAction: HomeQuickAction?
    @ObservationIgnored var pendingWidgetDestination: Destination?
    @ObservationIgnored var pendingNotificationDestination: Destination?
    var pendingOutdoorCardioKind: CardioSessionKind?
    var pendingManualCardioKind: CardioSessionKind?
    var activeAppSheet: AppSheet?
    var activeHealthSheet: HealthSheet?
    var activeSplitSheet: SplitSheet?
    var activeWorkoutSheet: WorkoutSheet?
    var activeWorkoutDialog: WorkoutDialog?
    var isQuickActionsBarHidden = false
    var isWorkoutSessionCoverPresented = false
    var isWorkoutPlanCoverPresented = false
    var isCardioSessionCoverPresented = false
    var tabSelection: AppTab = .home {
        didSet { SharedModelContainer.sharedDefaults.set(tabSelection.rawValue, forKey: Self.selectedTabDefaultsKey) }
    }
    var navigationEventToken = 0
    var homeTabResetToken = UUID()
    var healthTabResetToken = UUID()
    var cardioTabResetToken = UUID()

    enum Destination: Hashable {
        case workoutSessionsList
        case workoutSessionDetail(WorkoutSession)
        case cardioSessionDetail(CardioSession)
        case healthWorkoutDetail(HealthWorkout)
        case trainingConditionHistory
        case weightHistory
        case sleepHistory
        case sleepGoalHistory
        case stepsDistanceHistory
        case stepsGoalHistory
        case energyHistory
        case hydrationHistory
        case hydrationGoalHistory
        case heartRateHistory
        case restingHeartRateHistory
        case walkingHeartRateHistory
        case heartRateVariabilityHistory
        case respiratoryRateHistory
        case wristTemperatureHistory
        case healthTrends
        case sleepTimingInsights
        case allWeightEntriesList
        case weightGoalHistory
        case workoutPlansList
        case workoutPlanDetail(WorkoutPlan, Bool)
        case exercisesList
        case exerciseDetail(String)
        case exerciseHistory(String)
        case workoutSplit(autoPresentBuilder: Bool)
        case workoutSplitDetail(WorkoutSplit)

        static func == (lhs: Destination, rhs: Destination) -> Bool {
            switch (lhs, rhs) {
            case (.workoutSessionsList, .workoutSessionsList),
                (.trainingConditionHistory, .trainingConditionHistory),
                (.weightHistory, .weightHistory),
                (.sleepHistory, .sleepHistory),
                (.sleepGoalHistory, .sleepGoalHistory),
                (.stepsDistanceHistory, .stepsDistanceHistory),
                (.stepsGoalHistory, .stepsGoalHistory),
                (.energyHistory, .energyHistory),
                (.hydrationHistory, .hydrationHistory),
                (.hydrationGoalHistory, .hydrationGoalHistory),
                (.heartRateHistory, .heartRateHistory),
                (.restingHeartRateHistory, .restingHeartRateHistory),
                (.walkingHeartRateHistory, .walkingHeartRateHistory),
                (.heartRateVariabilityHistory, .heartRateVariabilityHistory),
                (.respiratoryRateHistory, .respiratoryRateHistory),
                (.wristTemperatureHistory, .wristTemperatureHistory),
                (.healthTrends, .healthTrends),
                (.sleepTimingInsights, .sleepTimingInsights),
                (.allWeightEntriesList, .allWeightEntriesList),
                (.weightGoalHistory, .weightGoalHistory),
                (.workoutPlansList, .workoutPlansList),
                (.exercisesList, .exercisesList):
                return true
            case let (.workoutSessionDetail(lhsSession), .workoutSessionDetail(rhsSession)):
                return lhsSession.id == rhsSession.id
            case let (.cardioSessionDetail(lhsSession), .cardioSessionDetail(rhsSession)):
                return lhsSession.id == rhsSession.id
            case let (.healthWorkoutDetail(lhsWorkout), .healthWorkoutDetail(rhsWorkout)):
                return lhsWorkout.healthWorkoutUUID == rhsWorkout.healthWorkoutUUID
            case let (.workoutPlanDetail(lhsPlan, lhsShowEditor), .workoutPlanDetail(rhsPlan, rhsShowEditor)):
                return lhsPlan.id == rhsPlan.id && lhsShowEditor == rhsShowEditor
            case let (.exerciseDetail(lhsCatalogID), .exerciseDetail(rhsCatalogID)),
                let (.exerciseHistory(lhsCatalogID), .exerciseHistory(rhsCatalogID)):
                return lhsCatalogID == rhsCatalogID
            case let (.workoutSplit(lhsAutoPresentBuilder), .workoutSplit(rhsAutoPresentBuilder)):
                return lhsAutoPresentBuilder == rhsAutoPresentBuilder
            case let (.workoutSplitDetail(lhsSplit), .workoutSplitDetail(rhsSplit)):
                return lhsSplit.id == rhsSplit.id
            default:
                return false
            }
        }

        func hash(into hasher: inout Hasher) {
            switch self {
            case .workoutSessionsList:
                hasher.combine("workoutSessionsList")
            case let .workoutSessionDetail(session):
                hasher.combine("workoutSessionDetail")
                hasher.combine(session.id)
            case let .cardioSessionDetail(session):
                hasher.combine("cardioSessionDetail")
                hasher.combine(session.id)
            case let .healthWorkoutDetail(workout):
                hasher.combine("healthWorkoutDetail")
                hasher.combine(workout.healthWorkoutUUID)
            case .trainingConditionHistory:
                hasher.combine("trainingConditionHistory")
            case .weightHistory:
                hasher.combine("weightHistory")
            case .sleepHistory:
                hasher.combine("sleepHistory")
            case .sleepGoalHistory:
                hasher.combine("sleepGoalHistory")
            case .stepsDistanceHistory:
                hasher.combine("stepsDistanceHistory")
            case .stepsGoalHistory:
                hasher.combine("stepsGoalHistory")
            case .energyHistory:
                hasher.combine("energyHistory")
            case .hydrationHistory:
                hasher.combine("hydrationHistory")
            case .hydrationGoalHistory:
                hasher.combine("hydrationGoalHistory")
            case .heartRateHistory:
                hasher.combine("heartRateHistory")
            case .restingHeartRateHistory:
                hasher.combine("restingHeartRateHistory")
            case .walkingHeartRateHistory:
                hasher.combine("walkingHeartRateHistory")
            case .heartRateVariabilityHistory:
                hasher.combine("heartRateVariabilityHistory")
            case .respiratoryRateHistory:
                hasher.combine("respiratoryRateHistory")
            case .wristTemperatureHistory:
                hasher.combine("wristTemperatureHistory")
            case .healthTrends:
                hasher.combine("healthTrends")
            case .sleepTimingInsights:
                hasher.combine("sleepTimingInsights")
            case .allWeightEntriesList:
                hasher.combine("allWeightEntriesList")
            case .weightGoalHistory:
                hasher.combine("weightGoalHistory")
            case .workoutPlansList:
                hasher.combine("workoutPlansList")
            case let .workoutPlanDetail(plan, showEditor):
                hasher.combine("workoutPlanDetail")
                hasher.combine(plan.id)
                hasher.combine(showEditor)
            case .exercisesList:
                hasher.combine("exercisesList")
            case let .exerciseDetail(catalogID):
                hasher.combine("exerciseDetail")
                hasher.combine(catalogID)
            case let .exerciseHistory(catalogID):
                hasher.combine("exerciseHistory")
                hasher.combine(catalogID)
            case let .workoutSplit(autoPresentBuilder):
                hasher.combine("workoutSplit")
                hasher.combine(autoPresentBuilder)
            case let .workoutSplitDetail(split):
                hasher.combine("workoutSplitDetail")
                hasher.combine(split.id)
            }
        }
    }

    var homeTabPath: [Destination] = []
    var cardioTabPath: [Destination] = []
    var healthTabPath: [Destination] = []
    private init() {
        if let storedRawValue = SharedModelContainer.sharedDefaults.string(forKey: Self.selectedTabDefaultsKey),
           let storedTab = AppTab(rawValue: storedRawValue) {
            tabSelection = storedTab
        }
    }
    private var context: ModelContext { SharedModelContainer.container.mainContext }

    var additionalQuickActionContext: AdditionalQuickActionContext? {
        switch tabSelection {
        case .home:
            return additionalQuickActionContext(for: homeTabPath.last)
        case .cardio:
            return nil
        case .health:
            return additionalQuickActionContext(for: healthTabPath.last)
        case .profile:
            return nil
        }
    }

    private func appSettings() -> AppSettings? { (try? context.fetch(AppSettings.single))?.first }
    private func weightUnit() -> WeightUnit { appSettings()?.weightUnit ?? .lbs }

    private var hasPresentedFlow: Bool { activeWorkoutSession != nil || activeWorkoutPlan != nil || activeCardioSession != nil }

    private func hasPersistedIncompleteWorkoutSession() -> Bool { (try? context.fetch(WorkoutSession.incomplete).first) != nil }

    private func hasPersistedIncompleteCardioSession() -> Bool { (try? context.fetch(CardioSession.incomplete).first) != nil }

    private func hasPersistedActivePlanWork() -> Bool { (try? context.fetch(WorkoutPlan.incomplete).first) != nil }

    private func hasActiveFlow() -> Bool { hasPresentedFlow || hasPersistedIncompleteWorkoutSession() || hasPersistedIncompleteCardioSession() || hasPersistedActivePlanWork() }

    var hasActiveAuthoringFlow: Bool { hasActiveFlow() }

    private enum ActiveFlowBlockKind {
        case workout
        case plan
        case cardio
    }

    private func activeFlowBlockKind() -> ActiveFlowBlockKind? {
        if activeWorkoutSession != nil || incompleteWorkoutSession() != nil {
            return .workout
        }
        if activeWorkoutPlan != nil || hasPersistedActivePlanWork() {
            return .plan
        }
        if activeCardioSession != nil || hasPersistedIncompleteCardioSession() {
            return .cardio
        }
        return nil
    }

    private func showActiveFlowBlockedToast() {
        switch activeFlowBlockKind() {
        case .workout:
            showQuickActionToast(title: "Workout In Progress", message: "Finish, cancel, or resume your current workout first.")
        case .plan:
            showQuickActionToast(title: "Plan In Progress", message: "Finish, discard, or resume your current plan first.")
        case .cardio:
            showQuickActionToast(title: "Cardio In Progress", message: "Finish, cancel, or resume your current cardio session first.")
        case nil:
            showQuickActionToast(title: "Flow In Progress", message: "Finish your current workout, cardio session, or plan first.")
        }
    }

    var hasHiddenActiveFlowPresentation: Bool {
        (activeWorkoutSession != nil && !isWorkoutSessionCoverPresented) ||
        (activeWorkoutPlan != nil && !isWorkoutPlanCoverPresented) ||
        (activeCardioSession != nil && !isCardioSessionCoverPresented)
    }

    private func isReadyForIntentActions() -> Bool {
        do {
            try SetupGuard.requireReady(context: context)
            return true
        } catch { return false }
    }

    func canShowStartTodaysWorkoutExpandedAction() -> Bool {
        guard isReadyForIntentActions() else { return false }
        guard !hasActiveFlow() else { return false }
        guard let split = try? context.fetch(WorkoutSplit.active).first else { return false }
        guard !(split.days?.isEmpty ?? true) else { return false }

        let resolution = SplitScheduleResolver.resolve(split, context: context, syncProgress: false)
        guard !resolution.isPaused else { return false }
        guard let splitDay = resolution.splitDay, !splitDay.isRestDay else { return false }
        guard let todaysPlan = resolution.workoutPlan else { return false }

        return !hasWorkoutSessionForToday(forPlanID: todaysPlan.id)
    }

    private func incompleteWorkoutSession() -> WorkoutSession? { try? context.fetch(WorkoutSession.incomplete).first }

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
        AppLog.info("Widget URL routed to \(destination).")
        pendingWidgetDestination = destination
        handlePendingWidgetDestinationIfPossible()
    }

    func handlePendingWidgetDestinationIfPossible() {
        guard let destination = pendingWidgetDestination else { return }
        guard isReadyForIntentActions() else { return }

        pendingWidgetDestination = nil
        collapseActiveFlowPresentations()
        navigate(to: destination)
    }

    func handleNotificationDestination(_ destination: Destination) {
        AppLog.info("Notification routed to \(destination).")
        pendingNotificationDestination = destination
        handlePendingNotificationDestinationIfPossible()
    }

    func handleRestTimerNotificationTap() {
        AppLog.info("Rest timer notification routed to active workout.")
        guard activeWorkoutSession != nil else { return }
        isWorkoutSessionCoverPresented = true
        noteNavigationStateChanged()
    }

    func handleWeeklyHealthCoachingNotificationTap() {
        AppLog.info("Weekly health coaching notification routed to health tab.")
        collapseActiveFlowPresentations()
        popToRoot(tab: .health)
        tabSelection = .health
    }

    func handlePendingNotificationDestinationIfPossible() {
        guard let destination = pendingNotificationDestination else { return }
        guard isReadyForIntentActions() else { return }

        pendingNotificationDestination = nil
        collapseActiveFlowPresentations()
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
        case "/hydration-history":
            return .hydrationHistory
        case "/heart-rate-history":
            return .heartRateHistory
        case "/resting-heart-rate-history":
            return .restingHeartRateHistory
        case "/walking-heart-rate-history":
            return .walkingHeartRateHistory
        case "/heart-rate-variability-history":
            return .heartRateVariabilityHistory
        case "/respiratory-rate-history":
            return .respiratoryRateHistory
        case "/wrist-temperature-history":
            return .wristTemperatureHistory
        default:
            return nil
        }
    }

    func cancelWorkoutSession(_ workoutSession: WorkoutSession) {
        RestTimerState.shared.stop()
        HealthLiveWorkoutSessionCoordinator.shared.discardIfRunning(for: workoutSession)
        workoutSession.clearPrescriptionLinksForHistoricalUse()
        context.delete(workoutSession)
        saveContext(context: context)
        if activeWorkoutSession?.id == workoutSession.id { activeWorkoutSession = nil }
        WorkoutActivityManager.end()
        AppLog.info("Workout session canceled: \(workoutSession.id).")
    }

    func cancelCardioSession(_ cardioSession: CardioSession) {
        CardioRouteRecorder.shared.stopRecording(sessionID: cardioSession.id)
        CardioHealthWorkoutCoordinator.shared.discardIfRunning(for: cardioSession)
        context.delete(cardioSession)
        saveContext(context: context)
        if activeCardioSession?.id == cardioSession.id { activeCardioSession = nil }
        CardioActivityManager.end()
        AppLog.info("Cardio session canceled: \(cardioSession.id).")
    }
    func navigate(to destination: Destination) {
        popToRoot(tab: tab(for: destination))
        push(to: destination)
    }

    func push(to destination: Destination) {
        Haptics.selection()
        switch tab(for: destination) {
        case .health:
            tabSelection = .health
            healthTabPath.append(destination)
        case .cardio:
            tabSelection = .cardio
            cardioTabPath.append(destination)
        case .home:
            tabSelection = .home
            homeTabPath.append(destination)
        case .profile:
            tabSelection = .profile
        }
        noteNavigationStateChanged()
    }

    func presentHealthSheet(_ sheet: HealthSheet) {
        Haptics.selection()
        activeHealthSheet = sheet
    }

    func presentAppSheet(_ sheet: AppSheet) {
        Haptics.selection()
        activeAppSheet = sheet
    }

    func presentNotificationSettingsFromSystem() {
        AppLog.info("System notification settings request routed to in-app settings.")
        collapseActiveFlowPresentations()
        activeAppSheet = .profileSettings(.notifications)
    }

    func presentSettingsFromSystem(_ destination: AppSettingsDestination? = nil) {
        AppLog.info("Settings intent routed to \(destination?.rawValue ?? "root").")
        collapseActiveFlowPresentations()
        activeAppSheet = .profileSettings(destination)
    }

    func presentSplitSheet(_ sheet: SplitSheet) {
        Haptics.selection()
        activeSplitSheet = sheet
    }

    func presentWorkoutSheet(_ sheet: WorkoutSheet) {
        Haptics.selection()
        if activeWorkoutSession != nil {
            isWorkoutSessionCoverPresented = true
        }
        activeWorkoutSheet = sheet
    }

    func presentWorkoutDialog(_ dialog: WorkoutDialog) {
        Haptics.selection()
        if activeWorkoutSession != nil {
            isWorkoutSessionCoverPresented = true
        }
        activeWorkoutDialog = dialog
    }

    func collapseActiveFlowPresentations() {
        if activeWorkoutSession != nil {
            isWorkoutSessionCoverPresented = false
            activeWorkoutSheet = nil
            activeWorkoutDialog = nil
        }
        if activeWorkoutPlan != nil {
            isWorkoutPlanCoverPresented = false
        }
        if activeCardioSession != nil {
            isCardioSessionCoverPresented = false
        }
    }

    func presentActiveWorkoutSessionIfPossible() {
        guard activeWorkoutSession != nil else { return }
        Haptics.selection()
        isWorkoutSessionCoverPresented = true
    }

    func dismissActiveWorkoutSessionPresentation() {
        isWorkoutSessionCoverPresented = false
        activeWorkoutSheet = nil
        activeWorkoutDialog = nil
    }

    func presentActiveWorkoutPlanIfPossible() {
        guard activeWorkoutPlan != nil else { return }
        Haptics.selection()
        isWorkoutPlanCoverPresented = true
    }

    func dismissActiveWorkoutPlanPresentation() {
        isWorkoutPlanCoverPresented = false
    }

    func presentActiveCardioSessionIfPossible() {
        guard activeCardioSession != nil else { return }
        Haptics.selection()
        isCardioSessionCoverPresented = true
    }

    func dismissActiveCardioSessionPresentation() {
        isCardioSessionCoverPresented = false
    }

    func popToRoot(tab: AppTab) {
        switch tab {
        case .home:
            if homeTabPath.isEmpty { return }
            homeTabPath = []
            homeTabResetToken = UUID()
        case .cardio:
            if cardioTabPath.isEmpty { return }
            cardioTabPath = []
            cardioTabResetToken = UUID()
        case .health:
            if healthTabPath.isEmpty { return }
            healthTabPath = []
            healthTabResetToken = UUID()
        case .profile:
            return
        }
        noteNavigationStateChanged()
    }

    private func additionalQuickActionContext(for destination: Destination?) -> AdditionalQuickActionContext? {
        switch destination {
        case nil:
            return tabSelection == .health ? .healthRoot : nil
        case .trainingConditionHistory:
            return .healthRoot
        case .workoutSessionDetail(let workout):
            return .workoutDetail(workout)
        case .cardioSessionDetail:
            return nil
        case .workoutSplit, .workoutSplitDetail:
            return .workoutSplit
        case .workoutPlanDetail(let plan, let showsUseOnly):
            return .workoutPlanDetail(plan, showsUseOnly: showsUseOnly)
        case .weightHistory, .weightGoalHistory:
            return .weightGoalHistory
        case .sleepHistory, .sleepGoalHistory:
            return .sleepGoalHistory
        case .stepsDistanceHistory, .stepsGoalHistory:
            return .stepsGoalHistory
        case .hydrationHistory, .hydrationGoalHistory, .heartRateHistory, .restingHeartRateHistory, .walkingHeartRateHistory, .heartRateVariabilityHistory, .respiratoryRateHistory, .wristTemperatureHistory:
            return .healthRoot
        case .healthTrends, .sleepTimingInsights:
            return .healthRoot
        default:
            return nil
        }
    }

    func presentWeightGoalCompletion(for goal: WeightGoal, trigger: WeightGoalCompletionRoute.Trigger, triggeringEntry: WeightEntry? = nil, referenceDate: Date? = nil) {
        Haptics.selection()
        tabSelection = .health
        activeWeightGoalCompletion = WeightGoalCompletionRoute(goalID: goal.id, triggeringEntryID: triggeringEntry?.id, trigger: trigger, referenceDate: referenceDate ?? triggeringEntry?.date ?? .now)
    }

    func receiveHomeQuickAction(_ action: HomeQuickAction) {
        AppLog.info("Home screen quick action received: \(action.rawValue).")
        pendingHomeQuickAction = action
        handlePendingHomeQuickActionIfPossible()
    }

    func handlePendingHomeQuickActionIfPossible() {
        guard let action = pendingHomeQuickAction else { return }
        guard isReadyForIntentActions() else { return }

        switch action {
        case .addWeightEntry:
            pendingHomeQuickAction = nil
            AppLog.info("Home screen quick action handled: add weight entry.")
            collapseActiveFlowPresentations()
            presentHealthSheet(.addWeightEntry)

        case .startTodaysWorkout:
            if hasActiveFlow() {
                pendingHomeQuickAction = nil
                AppLog.info("Home screen quick action blocked: active flow already visible.")
                handleBlockedHomeQuickAction()
                return
            }
            pendingHomeQuickAction = nil
            AppLog.info("Home screen quick action handled: start today's workout.")
            _ = handleStartTodaysWorkoutQuickAction()
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

        if let activeCardioSession {
            self.activeCardioSession = activeCardioSession
            showQuickActionToast(title: "Cardio In Progress", message: "Finish or cancel your current cardio session first.")
            return
        }

        if let unfinishedCardioSession = try? context.fetch(CardioSession.incomplete).first {
            resumeCardioSession(unfinishedCardioSession)
            showQuickActionToast(title: "Cardio In Progress", message: "Finish or cancel your current cardio session first.")
            return
        }

        if let unfinishedWorkoutPlan = try? context.fetch(WorkoutPlan.resumableIncomplete).first {
            resumeWorkoutPlanCreation(unfinishedWorkoutPlan)
            showQuickActionToast(title: "Plan In Progress", message: "Finish or discard your current plan first.")
        }
    }

    @discardableResult
    func startTodaysWorkoutFromExpandedAction() -> Bool {
        if hasActiveFlow() {
            handleBlockedHomeQuickAction()
            return false
        }
        return handleStartTodaysWorkoutQuickAction()
    }

    @discardableResult
    private func handleStartTodaysWorkoutQuickAction() -> Bool {
        guard let split = try? context.fetch(WorkoutSplit.active).first else {
            showQuickActionToast(title: "No Active Split", message: "Set an active workout split to start today's workout.")
            return false
        }

        guard !(split.days?.isEmpty ?? true) else {
            showQuickActionToast(title: "No Split Days", message: "Add days to your split before starting today's workout.")
            return false
        }

        let resolution = SplitScheduleResolver.resolve(split, context: context)

        guard let todaysDay = resolution.splitDay else {
            showQuickActionToast(title: "No Workout Today", message: "Villain Arc couldn't determine today's workout.")
            return false
        }

        guard !resolution.isPaused else {
            showQuickActionToast(title: "Training Paused", message: resolution.conditionStatusText ?? "Training is currently paused.")
            return false
        }

        guard !todaysDay.isRestDay else {
            showQuickActionToast(title: "Rest Day", message: "Today is a rest day. Enjoy your recovery.")
            return false
        }

        guard let workoutPlan = resolution.workoutPlan else {
            showQuickActionToast(title: "No Workout Plan", message: "You don't have a workout plan assigned for today.")
            return false
        }

        guard !hasWorkoutSessionForToday(forPlanID: workoutPlan.id) else {
            showQuickActionToast(title: "Workout Already Logged", message: "Today's split workout has already been started.")
            return false
        }

        startWorkoutSession(from: workoutPlan)
        return true
    }

    private func hasWorkoutSessionForToday(forPlanID planID: UUID, on day: Date = .now) -> Bool {
        let calendar = Calendar.autoupdatingCurrent
        let startOfDay = calendar.startOfDay(for: day)
        let startOfNextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        let predicate = #Predicate<WorkoutSession> {
            $0.workoutPlan?.id == planID &&
            $0.isHidden == false &&
            $0.startedAt >= startOfDay &&
            $0.startedAt < startOfNextDay
        }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor).first) != nil
    }

    private func showQuickActionToast(title: String, message: String) {
        ToastManager.shared.show(.init(title: title, message: message, systemImage: "exclamationmark.circle", tint: .orange, haptic: .warning))
    }

    private func startWorkoutRuntime(for workoutSession: WorkoutSession) {
        guard workoutSession.statusValue == .active else { return }
        WorkoutActivityManager.start(workout: workoutSession)
        Task {
            await HealthLiveWorkoutSessionCoordinator.shared.ensureRunning(for: workoutSession)
        }
    }

    private func restoreWorkoutRuntime(for workoutSession: WorkoutSession) {
        guard workoutSession.statusValue == .active else { return }
        WorkoutActivityManager.restoreIfNeeded(workout: workoutSession)
        Task {
            await HealthLiveWorkoutSessionCoordinator.shared.ensureRunning(for: workoutSession)
        }
    }

    private func startCardioRuntime(for cardioSession: CardioSession) {
        guard cardioSession.statusValue == .active else { return }
        guard cardioSession.startedAt != nil else {
            Task {
                await CardioHealthWorkoutCoordinator.shared.prepareForSession(cardioSession)
            }
            return
        }
        CardioActivityManager.start(session: cardioSession)
        Task {
            await CardioHealthWorkoutCoordinator.shared.ensureRunning(for: cardioSession)
        }
    }

    private func restoreCardioRuntime(for cardioSession: CardioSession) {
        guard cardioSession.statusValue == .active else { return }
        guard cardioSession.startedAt != nil else {
            Task {
                await CardioHealthWorkoutCoordinator.shared.prepareForSession(cardioSession)
            }
            return
        }
        CardioActivityManager.restoreIfNeeded(session: cardioSession)
        Task {
            await CardioHealthWorkoutCoordinator.shared.ensureRunning(for: cardioSession)
        }
    }

    func activatePendingWorkoutSession(_ workoutSession: WorkoutSession) {
        startWorkoutRuntime(for: workoutSession)
    }

    func startWorkoutSession() {
        guard !hasActiveFlow() else {
            showActiveFlowBlockedToast()
            return
        }
        Haptics.selection()
        let newWorkout = WorkoutSession()
        context.insert(newWorkout)
        saveContext(context: context)
        activeWorkoutSession = newWorkout
        startWorkoutRuntime(for: newWorkout)
        AppLog.info("Workout session started: \(newWorkout.id).")
    }

    func requestManualCardioSession(kind: CardioSessionKind) {
        let healthNeedsPrompt = HealthAuthorizationManager.isHealthDataAvailable && !HealthAuthorizationManager.hasRequestedWorkoutAuthorization
        if healthNeedsPrompt {
            pendingManualCardioKind = kind
        } else {
            startCardioSession(kind: kind)
        }
    }

    func requestOutdoorCardioSession(kind: CardioSessionKind) {
        let locationGranted = CardioRouteRecorder.shared.canRecord
        let healthNeedsPrompt = HealthAuthorizationManager.isHealthDataAvailable && !HealthAuthorizationManager.hasRequestedWorkoutAuthorization
        if locationGranted && !healthNeedsPrompt {
            startCardioSession(kind: kind)
        } else {
            pendingOutdoorCardioKind = kind
        }
    }

    func startCardioSession(kind: CardioSessionKind) {
        guard !hasActiveFlow() else {
            showActiveFlowBlockedToast()
            return
        }
        Haptics.selection()
        let newSession = CardioSession(kind: kind)
        context.insert(newSession)
        saveContext(context: context)
        activeCardioSession = newSession
        startCardioRuntime(for: newSession)
        AppLog.info("Cardio session started: \(newSession.id), kind=\(kind.rawValue).")
    }

    func createWorkoutPlan() {
        guard !hasActiveFlow() else {
            showActiveFlowBlockedToast()
            return
        }
        Haptics.selection()
        let newWorkoutPlan = WorkoutPlan()
        context.insert(newWorkoutPlan)
        saveContext(context: context)
        activeWorkoutPlanOriginal = nil
        activeWorkoutPlan = newWorkoutPlan
        AppLog.info("Workout plan creation started: \(newWorkoutPlan.id).")
    }

    func createWorkoutPlan(from workout: WorkoutSession) {
        guard !hasActiveFlow() else {
            showActiveFlowBlockedToast()
            return
        }
        Haptics.selection()
        let newWorkoutPlan = WorkoutPlan(from: workout)
        newWorkoutPlan.convertTargetWeightsFromKg(to: weightUnit())
        context.insert(newWorkoutPlan)
        workout.workoutPlan = newWorkoutPlan
        saveContext(context: context)
        activeWorkoutPlanOriginal = nil
        activeWorkoutPlan = newWorkoutPlan
        AppLog.info("Workout plan creation started from workout: \(workout.id).")
    }

    @discardableResult
    func addExerciseToActiveFlow(_ exercise: Exercise) -> Bool {
        if let workout = activeWorkoutSession, workout.statusValue == .active {
            Haptics.selection()
            workout.addExercise(exercise)
            exercise.updateLastAddedAt()
            saveContext(context: context)
            WorkoutActivityManager.update(for: workout)
            return true
        }

        if let plan = activeWorkoutPlan {
            Haptics.selection()
            plan.addExercise(exercise)
            exercise.updateLastAddedAt()
            saveContext(context: context)
            return true
        }

        return false
    }

    func editWorkoutPlan(_ plan: WorkoutPlan) {
        guard plan.completed, !plan.isEditing else { return }
        guard !hasActiveFlow() else {
            showActiveFlowBlockedToast()
            return
        }
        Haptics.selection()
        let editingCopy = plan.createEditingCopy(context: context)
        editingCopy.convertTargetWeightsFromKg(to: weightUnit())
        saveContext(context: context)
        activeWorkoutPlanOriginal = plan
        activeWorkoutPlan = editingCopy
        AppLog.info("Workout plan edit started: \(plan.id).")
    }

    func startWorkoutSession(from plan: WorkoutPlan) {
        guard !hasActiveFlow() else {
            showActiveFlowBlockedToast()
            return
        }
        Haptics.selection()
        let settings = appSettings()
        let workoutSession = WorkoutSession(from: plan, autoFillPlanTargets: settings?.autoFillPlanTargets ?? true)
        workoutSession.convertSetWeightsFromKg(to: settings?.weightUnit ?? .lbs)

        // Check for pending/deferred suggestions before starting
        let hasDeferredSuggestions = !pendingSuggestionEvents(for: plan, in: context).isEmpty
        if hasDeferredSuggestions { workoutSession.status = SessionStatus.pending.rawValue }

        context.insert(workoutSession)
        saveContext(context: context)
        activeWorkoutSession = workoutSession
        if workoutSession.statusValue == .active {
            startWorkoutRuntime(for: workoutSession)
        }
        AppLog.info("Workout session started from plan: \(plan.id), session: \(workoutSession.id), pendingSuggestions=\(hasDeferredSuggestions).")
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
        restoreWorkoutRuntime(for: workoutSession)
        AppLog.info("Workout session resumed: \(workoutSession.id).")
    }
    func resumeCardioSession(_ cardioSession: CardioSession) {
        Haptics.selection()
        activeCardioSession = cardioSession
        restoreCardioRuntime(for: cardioSession)
        AppLog.info("Cardio session resumed: \(cardioSession.id).")
    }
    func resumeWorkoutPlanCreation(_ workoutPlan: WorkoutPlan) {
        Haptics.selection()
        activeWorkoutPlanOriginal = nil
        activeWorkoutPlan = workoutPlan
        AppLog.info("Workout plan creation resumed: \(workoutPlan.id).")
    }
    func checkForUnfinishedData() {
        guard !hasPresentedFlow else { return }
        if let unfinishedWorkoutSession = try? context.fetch(WorkoutSession.incomplete).first {
            resumeWorkoutSession(unfinishedWorkoutSession)
            return
        }
        if let unfinishedCardioSession = try? context.fetch(CardioSession.incomplete).first {
            resumeCardioSession(unfinishedCardioSession)
            return
        }
        if let unfinishedWorkoutPlan = try? context.fetch(WorkoutPlan.resumableIncomplete).first { resumeWorkoutPlanCreation(unfinishedWorkoutPlan) }
    }

    func handleSiriWorkout(_ userActivity: NSUserActivity) {
        guard isReadyForIntentActions() else { return }
        guard !hasActiveFlow() else { return }
        AppLog.info("Siri activity routed: start workout.")
        startWorkoutSession()
    }

    func handleSiriCancelWorkout(_ userActivity: NSUserActivity) {
        guard isReadyForIntentActions() else { return }
        guard let workoutSession = incompleteWorkoutSession() else { return }
        AppLog.info("Siri activity routed: cancel workout.")

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
        AppLog.info("Siri activity routed: end workout.")
        presentFinishWorkoutFlow(for: workoutSession)
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
        guard let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String else { return }
        collapseActiveFlowPresentations()

        if identifier.hasPrefix(SpotlightIndexer.workoutSessionIdentifierPrefix) {
            let idString = String(identifier.dropFirst(SpotlightIndexer.workoutSessionIdentifierPrefix.count))
            guard let id = UUID(uuidString: idString) else { return }
            let predicate = #Predicate<WorkoutSession> { $0.id == id }
            var descriptor = FetchDescriptor(predicate: predicate)
            descriptor.fetchLimit = 1
            if let workoutSession = try? context.fetch(descriptor).first {
                AppLog.info("Spotlight routed to workout session detail.")
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
                AppLog.info("Spotlight routed to workout plan detail.")
                navigate(to: .workoutPlanDetail(workoutPlan, false))
            }
            return
        }

        if identifier.hasPrefix(SpotlightIndexer.exerciseIdentifierPrefix) {
            let catalogID = String(identifier.dropFirst(SpotlightIndexer.exerciseIdentifierPrefix.count))
            guard (try? context.fetch(Exercise.withCatalogID(catalogID)).first) != nil else { return }
            AppLog.info("Spotlight routed to exercise detail.")
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
                AppLog.info("Spotlight routed to workout split detail.")
                navigate(to: .workoutSplitDetail(workoutSplit))
            }
        }
    }

    private func tab(for destination: Destination) -> AppTab {
        switch destination {
        case .cardioSessionDetail:
            return .cardio
        case .trainingConditionHistory,
             .weightHistory,
             .sleepHistory,
             .sleepGoalHistory,
             .stepsDistanceHistory,
             .stepsGoalHistory,
             .energyHistory,
             .hydrationHistory,
             .hydrationGoalHistory,
             .heartRateHistory,
             .restingHeartRateHistory,
             .walkingHeartRateHistory,
             .heartRateVariabilityHistory,
             .respiratoryRateHistory,
             .wristTemperatureHistory,
             .healthTrends,
             .sleepTimingInsights,
             .allWeightEntriesList,
             .weightGoalHistory:
            return .health
        default:
            return .home
        }
    }

}

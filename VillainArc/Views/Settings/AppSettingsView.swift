import FCTAccount
import FCTAccountProfile
import FCTBlobSync
import FCTComponentsUI
import FCTFeedback
import FCTMetrics
import FCTOnboarding
import FCTStoreKit
import FCTSupport
import SwiftUI
#if DEBUG
import FCTScreenshotStudio
#endif
import SwiftData
import UIKit
import UserNotifications
import WebKit

private enum SettingsLegalDestination: String, Identifiable {
    case privacyPolicy
    case termsOfService

    var id: String { rawValue }

    var title: String {
        switch self {
        case .privacyPolicy:
            return String(localized: "Privacy Policy")
        case .termsOfService:
            return String(localized: "Terms of Service")
        }
    }

    var url: URL {
        switch self {
        case .privacyPolicy:
            return URL(string: "https://fct-technologies.com/projects/villainarc/privacy/")!
        case .termsOfService:
            return URL(string: "https://fct-technologies.com/projects/villainarc/terms/")!
        }
    }
}

struct AppSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(AppSettings.single) private var appSettings: [AppSettings]
    @State private var path: [AppSettingsDestination]
    @State private var presentedLegalDestination: SettingsLegalDestination?
    private let showsCloseButton: Bool

    init(initialDestination: AppSettingsDestination? = nil, showsCloseButton: Bool = true) {
        _path = State(initialValue: initialDestination.map { [$0] } ?? [])
        self.showsCloseButton = showsCloseButton
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let settings = appSettings.first {
                    AppSettingsFormView(settings: settings, includeQuickActionInset: !showsCloseButton, presentedLegalDestination: $presentedLegalDestination)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .listSectionSpacing(20)
            .navigationTitle("Settings")
            .toolbarTitleDisplayMode(.inlineLarge)
            .navigationDestination(for: AppSettingsDestination.self) { destination in
                if let settings = appSettings.first {
                    settingsDestinationView(destination, settings: settings)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if showsCloseButton {
                        Button("Close", systemImage: "xmark", role: .close) {
                            Haptics.selection()
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        .accessibilityIdentifier(AccessibilityIdentifiers.settingsCloseButton)
                    }
                }
            }
        }
        // This sheet and its pushed setting Forms are their own presentation context, which
        // ContentView's root modifier does not reach.
        .softScrollEdges()
        .sheet(item: $presentedLegalDestination) { destination in
            SettingsLegalWebSheet(destination: destination)
                .presentationBackground(Color.sheetBg)
        }
        .diagScreen(VACrumb.settings)
    }

    @ViewBuilder
    private func settingsDestinationView(_ destination: AppSettingsDestination, settings: AppSettings) -> some View {
        switch destination {
        case .workouts:
            WorkoutPreferencesView()
        case .appleHealth:
            AppleHealthSettingsView(settings: settings)
        case .notifications:
            NotificationSettingsView(settings: settings)
        case .units:
            UnitSettingsView(settings: settings)
        case .debug:
            #if DEBUG
            DebugSettingsView()
            #else
            EmptyView()
            #endif
        }
    }
}

#Preview(traits: .sampleData) {
    AppSettingsView()
}

private struct AppSettingsFormView: View {
    @Environment(\.modelContext) private var context
    @Bindable var settings: AppSettings
    let includeQuickActionInset: Bool
    @Binding var presentedLegalDestination: SettingsLegalDestination?
    @State private var latestDiagnostic: DiagnosticDescriptor?
    @State private var isShowingFeedbackBoard = false
    /// The account's avatar store lives on the sync bootstrap — the app's only blob store.
    @State private var sync = VASync.shared

    var body: some View {
        Form {
            // Above the account block, which is where the fleet puts it. The session can end from
            // that block while this screen is still up, so the profile is built from the
            // credentials that exist rather than the ones that did.
            if let credentials = VAAccount.controller.credentials, let avatars = sync.avatars {
                AccountProfileSection(
                    tint: .accentColor,
                    trusted: AccountTrusted(account: credentials),
                    avatars: avatars
                )
                // Silent while the blob layer is healthy, which is nearly always: it appears only
                // when an upload is stuck on something the person can act on.
                BlobStatusRow(store: avatars.blobs)
            }

            VAAccountSection()

            Section {
                NavigationLink(value: AppSettingsDestination.workouts) {
                    Label("Workouts", systemImage: "figure.strengthtraining.traditional")
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutSettingsButton)
                .accessibilityHint(AccessibilityText.workoutSettingsHint)
                .appGroupedListRow(position: .single)
            } footer: {
                Text("Customize workout logging, prompts, Live Activity behavior, and retention.")
            }

            Section {
                NavigationLink(value: AppSettingsDestination.appleHealth) {
                    Label("Apple Health", systemImage: "heart.text.square")
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.settingsAppleHealthLink)
                .accessibilityHint(AccessibilityText.settingsAppleHealthHint)
                .appGroupedListRow(position: .single)
            } footer: {
                Text("Manage Apple Health permissions and choose whether removed Health data stays in this app.")
            }

            Section {
                NavigationLink(value: AppSettingsDestination.notifications) {
                    Label("Notifications", systemImage: "bell.badge")
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.settingsNotificationsLink)
                .appGroupedListRow(position: .single)
            } footer: {
                Text("Manage notification preferences for your health goals.")
            }

            Section {
                NavigationLink(value: AppSettingsDestination.units) {
                    Label("Units", systemImage: "ruler")
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.settingsUnitsLink)
                .appGroupedListRow(position: .single)
            } footer: {
                Text("Choose how weight, height, distance, energy, and temperature are displayed throughout the app.")
            }

            #if DEBUG
            Section {
                NavigationLink(value: AppSettingsDestination.debug) {
                    Label("Debug", systemImage: "ladybug")
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.settingsDebugLink)
                .appGroupedListRow(position: .single)
            } footer: {
                Text("Testing tools for local debug builds.")
            }
            #endif

            EngineDonationSettingsSection()

            Section {
                Picker("Theme", systemImage: "circle.lefthalf.filled", selection: $settings.appearanceMode) {
                    ForEach(AppAppearanceMode.allCases, id: \.self) { mode in
                        Text(mode.displayName)
                            .tag(mode)
                    }
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.settingsThemePicker)
                .appGroupedListRow(position: .single)
            } footer: {
                Text("Choose whether the app follows your device appearance or always uses light or dark mode.")
            }

            // The fleet's one subscription section. It reads the merged entitlement, so a
            // subscription bought on another device shows here as the subscription it is, and it
            // decides on its own what a lifetime unlock or a shared entitlement can manage.
            SubscriptionSettingsSection(store: VAPro.store, productName: "Villain Arc Pro") {
                Haptics.selection()
                VAPro.presenter.present(for: .aiPlanGeneration)
            }

            SupportSettingsSection(appName: "Villain Arc")

            supportSection

            Section {
                Button {
                    Haptics.selection()
                    openWriteReviewPage()
                } label: {
                    Label("Rate Villain Arc on the App Store", systemImage: "star.bubble")
                }
                .foregroundStyle(.primary)
                .accessibilityIdentifier(AccessibilityIdentifiers.profileSheetReviewRow)
                .accessibilityHint(AccessibilityText.profileSheetReviewHint)
                .appGroupedListRow(position: .top)

                Button {
                    Haptics.selection()
                    presentedLegalDestination = .privacyPolicy
                } label: {
                    Label("Privacy Policy", systemImage: "hand.raised")
                }
                .foregroundStyle(.primary)
                .accessibilityIdentifier(AccessibilityIdentifiers.profileSheetPrivacyPolicyRow)
                .accessibilityHint(AccessibilityText.profileSheetPrivacyPolicyHint)
                .appGroupedListRow(position: .middle)

                Button {
                    Haptics.selection()
                    presentedLegalDestination = .termsOfService
                } label: {
                    Label("Terms of Service", systemImage: "doc.text")
                }
                .foregroundStyle(.primary)
                .accessibilityIdentifier(AccessibilityIdentifiers.profileSheetTermsOfServiceRow)
                .accessibilityHint(AccessibilityText.profileSheetTermsOfServiceHint)
                .appGroupedListRow(position: .bottom)
            }
        }
        .scrollContentBackground(.hidden)
        .modifier(SettingsQuickActionInsetModifier(isEnabled: includeQuickActionInset))
        .sheetBackground()
        // On the Form rather than on the row: `appGroupedListRow` chrome cannot present a sheet.
        .sheet(isPresented: $isShowingFeedbackBoard) {
            FeedbackBoardSheet(
                board: FeedbackBoard(slug: "villainarc"),
                credentials: VAAccount.controller.credentials
            )
        }
        .task {
            refreshLatestDiagnostic()
        }
        .onChange(of: settings.appearanceMode) {
            settingChanged(context)
            dismissAllPresentedSheets()
        }
    }

    /// The support rows only this app can offer, below `SupportSettingsSection` — which carries
    /// Contact Support, the reply commitment, and the app's whole telemetry statement.
    @ViewBuilder
    private var supportSection: some View {
        Section {
            if let descriptor = latestDiagnostic {
                Button {
                    Haptics.selection()
                    sendDiagnostic(descriptor)
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Send Last Diagnostic")
                            Text("Crash report from \(descriptor.relativeReceivedAt)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "arrow.up.heart.fill")
                    }
                }
                .foregroundStyle(.primary)
                .accessibilityIdentifier(AccessibilityIdentifiers.settingsSendDiagnosticButton)
                .appGroupedListRow(position: .top)
            }

            // The board is the package's (`FeedbackBoardSheet`); the ROW is deliberately this app's
            // own rather than `FeedbackSettingsSection`. That section is a whole `Section` with its
            // own header and footer, and this is one of three rows inside a single Support block
            // whose grouped-row chrome and positions (`.top`/`.middle`/`.bottom`) are computed
            // together — adopting it would split the block in two and leave the remaining rows'
            // corners wrong. The sheet, its credentials and its slug are all the package's, so
            // there is no logic here to drift.
            Button {
                Haptics.selection()
                isShowingFeedbackBoard = true
            } label: {
                Label("Request a Feature", systemImage: "lightbulb.max.fill")
            }
            .foregroundStyle(.primary)
            .accessibilityIdentifier(AccessibilityIdentifiers.settingsRequestFeatureButton)
            .appGroupedListRow(position: latestDiagnostic == nil ? .top : .middle)

            Button {
                Haptics.selection()
                UIApplication.shared.open(SupportContact.supportPageURL)
            } label: {
                Label("Visit Support Page", systemImage: "safari")
            }
            .foregroundStyle(.primary)
            .accessibilityIdentifier(AccessibilityIdentifiers.settingsSupportPageButton)
            .appGroupedListRow(position: .bottom)
        }
    }

    private func openWriteReviewPage() {
        guard let url = URL(string: "https://apps.apple.com/app/id6759259627?action=write-review") else { return }
        UIApplication.shared.open(url)
    }

    private func sendDiagnostic(_ descriptor: DiagnosticDescriptor) {
        guard let url = SupportContact.mailtoForDiagnostic(json: descriptor.json, receivedAt: descriptor.receivedAt) else { return }
        UIApplication.shared.open(url)
    }

    private func refreshLatestDiagnostic() {
        if let payload = VAMetrics.service.latestDiagnostic() {
            latestDiagnostic = DiagnosticDescriptor(json: payload.json, receivedAt: payload.receivedAt)
        } else {
            latestDiagnostic = nil
        }
    }
}

private struct DiagnosticDescriptor: Equatable {
    let json: String
    let receivedAt: Date

    var relativeReceivedAt: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: receivedAt, relativeTo: Date())
    }
}

private struct SettingsQuickActionInsetModifier: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content.quickActionContentBottomInset()
        } else {
            content
        }
    }
}

private struct WorkoutPreferencesView: View {
    @Environment(\.modelContext) private var context
    @Query(AppSettings.single) private var appSettings: [AppSettings]
    @Query(WorkoutSession.incomplete) private var incompleteWorkouts: [WorkoutSession]
    @Query(CardioSession.incomplete) private var incompleteCardioSessions: [CardioSession]

    private var systemLiveActivitiesAvailable: Bool {
        WorkoutActivityManager.areActivitiesAvailable
    }

    private var activeWorkout: WorkoutSession? {
        incompleteWorkouts.first
    }

    private var activeCardio: CardioSession? {
        incompleteCardioSessions.first
    }

    // The Live Activity toggle is global (workout + cardio share it), so the restart
    // affordance applies whenever either kind of session is in progress.
    private var hasActiveLiveActivitySession: Bool {
        activeWorkout != nil || activeCardio != nil
    }

    private var cardioLiveActivityMetricsSummary: String {
        CardioLiveActivityMetricStore.load().metrics.map(\.displayName).joined(separator: ", ")
    }

    private func restartActiveLiveActivity() {
        if let activeWorkout {
            WorkoutActivityManager.restart(workout: activeWorkout)
        } else if let activeCardio {
            CardioActivityManager.restart(session: activeCardio)
        }
    }

    var body: some View {
        Group {
            if let settings = appSettings.first {
                settingsForm(settings)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Workouts")
        .toolbarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .sheetBackground()
        .diagScreen(VACrumb.settingsWorkoutPreferences)
    }

    private func settingsForm(_ settings: AppSettings) -> some View {
        @Bindable var settings = settings

        return Form {
            Section {
                Toggle("Retain for Improved Accuracy", isOn: $settings.retainPerformancesForLearning)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutSettingsRetainPerformanceSnapshotsToggle)
                    .accessibilityHint(AccessibilityText.workoutSettingsRetainPerformanceSnapshotsHint)
                    .appGroupedListRow(position: .single)
            } header: {
                Text("Workout History")
            } footer: {
                Text("When this is on, deleting a workout keeps its performances so suggestions have more data to work with. When it is off, it permanently removes the session and the suggestion data tied to it.")
            }

            Section {
                Toggle("Auto Fill Plan Targets", isOn: $settings.autoFillPlanTargets)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutSettingsAutoFillPlanTargetsToggle)
                    .accessibilityHint(AccessibilityText.workoutSettingsAutoFillPlanTargetsHint)
                    .appGroupedListRow(position: .top)
                Toggle("Show Previous by Default", isOn: Binding(
                    get: { !settings.prefersTargetReferenceWhenPlanned },
                    set: { settings.prefersTargetReferenceWhenPlanned = !$0 }
                ))
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutSettingsPrefersTargetReferenceToggle)
                .accessibilityHint(AccessibilityText.workoutSettingsPrefersTargetReferenceHint)
                .appGroupedListRow(position: .middle)
                Picker("Previous Source", selection: $settings.previousSetReferenceSource) {
                    ForEach(PreviousSetReferenceSource.allCases) { source in
                        Text(source.displayName).tag(source)
                    }
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutSettingsPreviousReferenceSourcePicker)
                .accessibilityHint(AccessibilityText.workoutSettingsPreviousReferenceSourceHint)
                .appGroupedListRow(position: .bottom)
            } header: {
                Text("Plan Workouts")
            } footer: {
                Text("When Auto Fill Plan Targets is on, workouts started from a plan prefill each set with its prescribed weight, reps, and rest. Show Previous by Default controls whether the reference column starts on previous performance instead of the plan target; Previous Source chooses either your last matching workout or the last completed session from the same plan.")
            }

            Section {
                Toggle("Auto Start Rest Timer", isOn: $settings.autoStartRestTimer)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutSettingsAutoStartTimerToggle)
                    .accessibilityHint(AccessibilityText.workoutSettingsAutoStartTimerHint)
                    .appGroupedListRow(position: .top)
                Toggle("Auto Complete After RPE", isOn: $settings.autoCompleteSetAfterRPE)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutSettingsAutoCompleteAfterRPEToggle)
                    .accessibilityHint(AccessibilityText.workoutSettingsAutoCompleteAfterRPEHint)
                    .appGroupedListRow(position: .middle)
                Toggle("Assume Target RPE When Done", isOn: $settings.assumeTargetRPEOnComplete)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutSettingsAssumeTargetRPEToggle)
                    .accessibilityHint(AccessibilityText.workoutSettingsAssumeTargetRPEHint)
                    .appGroupedListRow(position: .bottom)
            } header: {
                Text("Set Logging")
            } footer: {
                Text("After you pick an RPE, the app can mark the set complete for you. If Auto Start Rest Timer is on, it also starts the timer. Assume Target RPE When Done fills in the target RPE automatically when you mark a set complete without rating it.")
            }

            Section {
                Toggle("Prompt For Pre Workout Context", isOn: $settings.promptForPreWorkoutContext)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutSettingsPreWorkoutPromptToggle)
                    .accessibilityHint(AccessibilityText.workoutSettingsPreWorkoutPromptHint)
                    .appGroupedListRow(position: .top)
                Toggle("Prompt For Post Workout Effort", isOn: $settings.promptForPostWorkoutEffort)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutSettingsPostWorkoutEffortToggle)
                    .accessibilityHint(AccessibilityText.workoutSettingsPostWorkoutEffortHint)
                    .appGroupedListRow(position: .bottom)
            } header: {
                Text("Workout Context")
            } footer: {
                Text("Prompt For Pre Workout Context asks for how you feel before logging starts. Prompt For Post Workout Effort asks for your overall effort rating when you finish a workout. Turn either off to enter those details manually only when needed.")
            }

            Section {
                Toggle("Show Live Activity", isOn: $settings.liveActivitiesEnabled)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutSettingsLiveActivitiesToggle)
                    .accessibilityHint(AccessibilityText.workoutSettingsLiveActivitiesHint)
                    .appGroupedListRow(position: settings.liveActivitiesEnabled ? .top : .single)

                if settings.liveActivitiesEnabled {
                    NavigationLink {
                        CardioLiveActivityMetricPickerView()
                    } label: {
                        LabeledContent("Cardio Metrics", value: cardioLiveActivityMetricsSummary)
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.cardioLiveActivityMetricsRow)
                    .appGroupedListRow(position: (systemLiveActivitiesAvailable && hasActiveLiveActivitySession) ? .middle : .bottom)
                }

                if settings.liveActivitiesEnabled && systemLiveActivitiesAvailable, hasActiveLiveActivitySession {
                    Button("Restart Live Activity", systemImage: "arrow.clockwise") {
                        Haptics.selection()
                        restartActiveLiveActivity()
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutSettingsRestartLiveActivityButton)
                    .accessibilityHint(AccessibilityText.workoutSettingsRestartLiveActivityHint)
                    .appGroupedListRow(position: .bottom)
                }
            } header: {
                Text("Live Activity")
            } footer: {
                if !systemLiveActivitiesAvailable {
                    Text("Live Activities are not available on this device or are disabled in system settings. The app will fall back to in app toasts and local notifications when possible.")
                }
            }
        }
        .onChange(of: settings.retainPerformancesForLearning) {
            settingChanged(context)
            guard !settings.retainPerformancesForLearning else { return }
            WorkoutDeletionCoordinator.applyRetentionSetting(context: context, settings: settings)
        }
        .onChange(of: settings.autoStartRestTimer) {
            settingChanged(context)
        }
        .onChange(of: settings.autoCompleteSetAfterRPE) {
            settingChanged(context)
        }
        .onChange(of: settings.assumeTargetRPEOnComplete) {
            settingChanged(context)
        }
        .onChange(of: settings.autoFillPlanTargets) {
            settingChanged(context)
        }
        .onChange(of: settings.prefersTargetReferenceWhenPlanned) {
            settingChanged(context)
        }
        .onChange(of: settings.previousSetReferenceSource) {
            settingChanged(context)
        }
        .onChange(of: settings.promptForPreWorkoutContext) {
            settingChanged(context)
        }
        .onChange(of: settings.promptForPostWorkoutEffort) {
            settingChanged(context)
        }
        .onChange(of: settings.liveActivitiesEnabled) {
            settingChanged(context)

            if settings.liveActivitiesEnabled {
                restartActiveLiveActivity()
            } else {
                WorkoutActivityManager.end()
                CardioActivityManager.end()
            }

            let restTimer = RestTimerState.shared
            if let endDate = restTimer.endDate, restTimer.isRunning {
                Task { await NotificationCoordinator.scheduleRestTimer(endDate: endDate) }
            } else {
                Task { NotificationCoordinator.cancelRestTimer() }
            }
        }
    }
}

private func dismissAllPresentedSheets() {
    let rootViewControllers = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap(\.windows)
        .filter(\.isKeyWindow)
        .compactMap(\.rootViewController)

    for rootViewController in rootViewControllers {
        rootViewController.dismiss(animated: true)
    }
}

private struct AppleHealthSettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var settings: AppSettings

    @State private var healthAuthorizationState: HealthAuthorizationState = .notDetermined
    @State private var healthAuthorizationAction: HealthAuthorizationAction = .requestAccess
    @State private var isRefreshingHealthStatus = false
    @State private var isHandlingHealthAction = false
    @State private var showHealthAccessInstructions = false

    var body: some View {
        Form {
            Section {
                LabeledContent("Status", value: healthAuthorizationState.statusText)
                    .appGroupedListRow(position: healthAuthorizationAction != .unavailable ? .top : .single)

                if healthAuthorizationAction != .unavailable {
                    Button(healthAuthorizationAction.buttonTitle, systemImage: healthAuthorizationAction.systemImage) {
                        Task {
                            await handleHealthAuthorizationAction()
                        }
                    }
                    .disabled(isRefreshingHealthStatus || isHandlingHealthAction)
                    .accessibilityIdentifier(AccessibilityIdentifiers.settingsAppleHealthActionButton)
                    .accessibilityHint(AccessibilityText.settingsAppleHealthActionHint(action: healthAuthorizationAction))
                    .appGroupedListRow(position: .bottom)
                }
            }

            Section {
                Toggle("Keep Removed Data", isOn: $settings.keepRemovedHealthData)
                    .accessibilityIdentifier(AccessibilityIdentifiers.settingsAppleHealthKeepRemovedDataToggle)
                    .appGroupedListRow(position: .single)
            } footer: {
                Text("When this is off, data removed from Apple Health is also removed from this app.")
            }

        }
        .navigationTitle("Apple Health")
        .toolbarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .sheetBackground()
        .task {
            await refreshHealthAuthorizationState()
        }
        .onChange(of: scenePhase, initial: false) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await refreshHealthAuthorizationState()
                HealthStoreUpdateCoordinator.shared.installObserversIfNeeded()
                await HealthStoreUpdateCoordinator.shared.refreshBackgroundDeliveryRegistration()
                await HealthStoreUpdateCoordinator.shared.syncNow()
            }
        }
        .onChange(of: settings.keepRemovedHealthData) {
            settingChanged(context)
            guard !settings.keepRemovedHealthData else { return }
            Task {
                await HealthSyncCoordinator.shared.applyRemovedHealthDataRetentionSetting()
            }
        }
        .alert("Manage Apple Health Access", isPresented: $showHealthAccessInstructions) {
            Button("Open Settings Apps") {
                guard let url = URL(string: "App-prefs:root=HEALTH") else { return }
                UIApplication.shared.open(url)
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.settingsAppleHealthOpenSystemSettingsButton)
            Button("OK", role: .cancel) {}
                .accessibilityIdentifier(AccessibilityIdentifiers.settingsAppleHealthInstructionsDismissButton)
        } message: {
            Text("Apple does not let this app open the exact Health permission screen directly. Go to Settings, Apps, Health, Health Access and Devices, tap this app, then update the workout permissions.")
        }
        .diagScreen(VACrumb.settingsAppleHealth)
    }
    private func refreshHealthAuthorizationState() async {
        isRefreshingHealthStatus = true
        healthAuthorizationState = HealthAuthorizationManager.currentAuthorizationState
        healthAuthorizationAction = await HealthAuthorizationManager.authorizationAction()
        isRefreshingHealthStatus = false
    }

    private func handleHealthAuthorizationAction() async {
        guard !isHandlingHealthAction else { return }
        isHandlingHealthAction = true
        defer { isHandlingHealthAction = false }

        switch healthAuthorizationAction {
        case .requestAccess:
            _ = await HealthAuthorizationManager.requestAuthorization()
            HealthStoreUpdateCoordinator.shared.installObserversIfNeeded()
            await HealthStoreUpdateCoordinator.shared.refreshBackgroundDeliveryRegistration()
            await HealthStoreUpdateCoordinator.shared.syncNow()
        case .openSettings, .manageInSettings:
            showHealthAccessInstructions = true
        case .unavailable:
            break
        }

        await refreshHealthAuthorizationState()
    }
}

private struct NotificationSettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var settings: AppSettings

    @State private var notificationAuthorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var isHandlingNotificationAction = false
    @State private var backgroundRefreshStatus: UIBackgroundRefreshStatus = .available

    var body: some View {
        Form {
            Section {
                LabeledContent("Status", value: notificationStatusText)
                    .appGroupedListRow(position: .top)

                Button(notificationActionTitle, systemImage: notificationActionSystemImage) {
                    Task {
                        await handleNotificationAuthorizationAction()
                    }
                }
                .disabled(isHandlingNotificationAction)
                .accessibilityIdentifier(AccessibilityIdentifiers.settingsNotificationsActionButton)
                .appGroupedListRow(position: .bottom)
            }

            Section {
                Picker("Mode", selection: $settings.stepsNotificationMode) {
                    ForEach(StepsEventNotificationMode.allCases, id: \.self) { mode in
                        Text(mode.title)
                            .tag(mode)
                    }
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.settingsStepsNotificationModePicker)
                .disabled(!notificationsAreAllowedBySystem)
                .appGroupedListRow(position: .single)
            } header: {
                Text("Steps")
            } footer: {
                if !notificationsAreAllowedBySystem {
                    Text("Enable notifications in system settings to change this. You can still see in app toasts while using the app.")
                } else if backgroundRefreshStatus != .available {
                    Text("Background App Refresh is off, so steps notifications may be delayed while the app is closed.")
                } else {
                    Text("Choose whether you receive notifications when you complete your steps goal only, or also receive coaching notifications for double goal, triple goal, and new best milestones.")
                }
            }

            Section {
                Picker("Mode", selection: $settings.sleepNotificationMode) {
                    ForEach(SleepNotificationMode.allCases, id: \.self) { mode in
                        Text(mode.title)
                            .tag(mode)
                    }
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.settingsSleepNotificationModePicker)
                .disabled(!notificationsAreAllowedBySystem)
                .appGroupedListRow(position: .single)
            } header: {
                Text("Sleep")
            } footer: {
                if !notificationsAreAllowedBySystem {
                    Text("Enable notifications in system settings to change this. You can still see in app toasts while using the app.")
                } else if backgroundRefreshStatus != .available {
                    Text("Background App Refresh is off, so sleep notifications may be delayed while the app is closed.")
                } else {
                    Text("Choose whether you receive notifications when you complete your sleep goal only, or also receive weekly coaching recaps for your sleep averages.")
                }
            }

            Section {
                Picker("Mode", selection: $settings.hydrationNotificationMode) {
                    ForEach(HydrationEventNotificationMode.allCases, id: \.self) { mode in
                        Text(mode.title)
                            .tag(mode)
                    }
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.settingsHydrationNotificationModePicker)
                .disabled(!notificationsAreAllowedBySystem)
                .appGroupedListRow(position: .single)
            } header: {
                Text("Hydration")
            } footer: {
                if !notificationsAreAllowedBySystem {
                    Text("Enable notifications in system settings to change this. You can still see in app toasts while using the app.")
                } else if backgroundRefreshStatus != .available {
                    Text("Background App Refresh is off, so hydration notifications may be delayed while the app is closed.")
                } else {
                    Text("Choose whether you receive a notification when you reach your hydration goal, or also receive coaching notifications for surpassing your goal.")
                }
            }

        }
        .navigationTitle("Notifications")
        .toolbarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .sheetBackground()
        .task {
            await refreshNotificationAuthorizationState()
        }
        .onChange(of: scenePhase, initial: false) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await refreshNotificationAuthorizationState()
                await WeeklyHealthCoachingCoordinator.shared.refreshSchedule()
            }
        }
        .onChange(of: settings.stepsNotificationMode) {
            settingChanged(context)
            Task { await WeeklyHealthCoachingCoordinator.shared.refreshSchedule() }
        }
        .onChange(of: settings.sleepNotificationMode) {
            settingChanged(context)
            Task { await WeeklyHealthCoachingCoordinator.shared.refreshSchedule() }
        }
        .onChange(of: settings.hydrationNotificationMode) {
            settingChanged(context)
        }
        .diagScreen(VACrumb.settingsNotifications)
    }

    private var notificationStatusText: String {
        switch notificationAuthorizationStatus {
        case .notDetermined:
            return String(localized: "Not Requested")
        case .denied:
            return String(localized: "Denied")
        case .authorized:
            return String(localized: "Allowed")
        case .provisional:
            return String(localized: "Allowed Quietly")
        case .ephemeral:
            return String(localized: "Temporary")
        @unknown default:
            return String(localized: "Unknown")
        }
    }

    private var notificationsAreAllowedBySystem: Bool {
        notificationAuthorizationStatus.allowsLocalDelivery
    }

    private var notificationActionTitle: String {
        switch notificationAuthorizationStatus {
        case .notDetermined:
            return String(localized: "Enable Notifications")
        case .denied, .authorized, .provisional, .ephemeral:
            return String(localized: "Open Settings")
        @unknown default:
            return String(localized: "Open Settings")
        }
    }

    private var notificationActionSystemImage: String {
        switch notificationAuthorizationStatus {
        case .notDetermined:
            return "bell.badge"
        case .denied, .authorized, .provisional, .ephemeral:
            return "gearshape"
        @unknown default:
            return "gearshape"
        }
    }

    private func refreshNotificationAuthorizationState() async {
        notificationAuthorizationStatus = await NotificationCoordinator.authorizationStatus()
        backgroundRefreshStatus = UIApplication.shared.backgroundRefreshStatus
    }

    private func handleNotificationAuthorizationAction() async {
        guard !isHandlingNotificationAction else { return }
        isHandlingNotificationAction = true
        defer { isHandlingNotificationAction = false }

        switch notificationAuthorizationStatus {
        case .notDetermined:
            await NotificationCoordinator.requestAuthorizationIfNeededAfterOnboarding()
        case .denied, .authorized, .provisional, .ephemeral:
            openAppSettings()
        @unknown default:
            openAppSettings()
        }

        await refreshNotificationAuthorizationState()
        await WeeklyHealthCoachingCoordinator.shared.refreshSchedule()
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

#if DEBUG
/// The debug menu, and the one rule that shapes it: **every operation here writes into the
/// detached debug store**, never the app's own. Each of these seeds runs through the same `@Model`
/// types the app syncs, so a seed pointed at the app's store sends every row it inserts to the
/// account and a clear-first seed sends a tombstone per row it removes.
///
/// The exceptions are the three that write nothing synced: the exercise-catalog resync (local
/// `Exercise` rows, whose synced half is `ExercisePreference`), the Health resync (the
/// device-sourced Health mirror, which never syncs up), and the Spotlight reindex (a read).
private struct DebugSettingsView: View {
    @Environment(\.debugDemoStore) private var debugStore
    @State private var isWorking = false
    @State private var statusMessage = "Ready"
    @State private var showsResetConfirmation = false
    @State private var resetRefusal: DebugResetRefusal?
    @State private var introPreview: WhatsNewPresentation?
    @State private var showsCarouselPreview = false

    private var healthStatusText: String {
        #if targetEnvironment(simulator)
        return "Unavailable on Simulator"
        #else
        return HealthAuthorizationManager.isHealthDataAvailable ? "Available" : "Unavailable"
        #endif
    }

    var body: some View {
        Form {
            Section {
                // `storeKit:` because the catalog carries a paywall scene: the studio reports
                // whether the products loaded, which is whether that shot is the real one.
                ScreenshotStudioLink(
                    scenes: ScreenshotStudioCatalog.scenes,
                    storeKit: DebugStoreKitProducts(productIDs: VAPro.catalog.productIDs)
                ) { context in
                    try ScreenshotStudioSeeder.seedAll(in: context)
                }
                .appGroupedListRow(position: .single)
            } footer: {
                Text("Every seed below writes into the detached debug store, and each Screenshot Studio scene renders from it. The app's own screens keep showing the app's own store.")
            }

            Section {
                Button("Show Onboarding Carousel", systemImage: "hand.wave") {
                    Haptics.selection()
                    showsCarouselPreview = true
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.debugShowOnboardingCarouselButton)
                .appGroupedListRow(position: .top)

                Button("Show What's New", systemImage: "sparkles") {
                    Haptics.selection()
                    let current = WhatsNewPreferences.currentVersion
                    let features = WhatsNewCatalog.featuresIntroduced(after: "0", throughIncluding: current)
                    introPreview = WhatsNewPresentation(version: current, features: features)
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.debugShowWhatsNewButton)
                .appGroupedListRow(position: .bottom)
            } header: {
                Text("Intro Flows")
            }

            Section {
                LabeledContent("HealthKit", value: healthStatusText)
                    .accessibilityIdentifier(AccessibilityIdentifiers.debugHealthKitStatusValue)
                    .appGroupedListRow(position: .single)
            } footer: {
                Text("Simulator builds skip HealthKit observers, background delivery, and manual Health resync.")
            }

            Section {
                Button("Reset Debug Data", systemImage: "trash", role: .destructive) {
                    Haptics.selection()
                    showsResetConfirmation = true
                }
                .disabled(isWorking)
                .accessibilityIdentifier(AccessibilityIdentifiers.debugResetAppDataButton)
                .appGroupedListRow(position: .top)

                Button("Resync Exercise Catalog", systemImage: "arrow.triangle.2.circlepath") {
                    runOperation("Exercise catalog resynced.") {
                        try await DebugOperations.resyncExerciseCatalog()
                    }
                }
                .disabled(isWorking)
                .accessibilityIdentifier(AccessibilityIdentifiers.debugResyncExerciseCatalogButton)
                .appGroupedListRow(position: .middle)

                Button("Resync Health Data", systemImage: "heart.text.square") {
                    runOperation("Health resync finished.") {
                        await DebugOperations.resyncHealthData()
                    }
                }
                .disabled(isWorking || !HealthAuthorizationManager.isHealthDataAvailable)
                .accessibilityIdentifier(AccessibilityIdentifiers.debugResyncHealthDataButton)
                .appGroupedListRow(position: .middle)

                Button("Reindex Spotlight", systemImage: "magnifyingglass") {
                    runOperation("Spotlight reindex queued.") {
                        DebugOperations.reindexSpotlight()
                    }
                }
                .disabled(isWorking)
                .accessibilityIdentifier(AccessibilityIdentifiers.debugReindexSpotlightButton)
                .appGroupedListRow(position: .middle)

                Button("Touch All Models", systemImage: "square.stack.3d.up") {
                    runSeed("All model tables touched.") { context in
                        try DebugOperations.touchAllModels(in: context)
                    }
                }
                .disabled(isWorking)
                .accessibilityIdentifier(AccessibilityIdentifiers.debugTouchAllModelsButton)
                .appGroupedListRow(position: .middle)

                Button("Seed Workout Data", systemImage: "dumbbell") {
                    runSeed("Workout data seeded.") { context in
                        try DebugOperations.seedWorkoutData(in: context)
                    }
                }
                .disabled(isWorking)
                .accessibilityIdentifier(AccessibilityIdentifiers.debugSeedWorkoutDataButton)
                .appGroupedListRow(position: .bottom)
            } footer: {
                Text(statusMessage)
            }

            Section {
                Button("Seed Demo Data", systemImage: "wand.and.sparkles") {
                    runSeed("Demo data seeded.") { context in
                        try DebugOperations.seedDemoData(in: context)
                    }
                }
                .disabled(isWorking)
                .accessibilityIdentifier(AccessibilityIdentifiers.debugSeedDemoDataButton)
                .appGroupedListRow(position: .single)
            } header: {
                Text("Demo Capture")
            } footer: {
                Text("One action: the profile and goal a ready app needs, workout history, and 35 days of Health data — the state store screenshots and demo footage are captured from.")
            }

            Section {
                ForEach(DebugOperations.HealthSampleScenario.allCases) { scenario in
                    Button(scenario.title, systemImage: "chart.line.uptrend.xyaxis") {
                        runSeed("\(scenario.title) samples seeded.") { context in
                            try DebugOperations.seedHealthSamples(scenario: scenario, in: context)
                        }
                    }
                    .disabled(isWorking)
                    .accessibilityIdentifier(AccessibilityIdentifiers.debugSeedHealthSamplesButton(scenario.title))
                    .appGroupedListRow(position: rowPosition(for: scenario))
                }
            } header: {
                Text("Health Sample Data")
            } footer: {
                Text("Replaces local Health-style sample rows with 35 days of weight, steps, energy, sleep, heart, respiratory, wrist temperature, and hydration data.")
            }
        }
        .navigationTitle("Debug")
        .toolbarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .sheetBackground()
        .alert("Reset Debug Data?", isPresented: $showsResetConfirmation) {
            Button("Reset Debug Data", role: .destructive) {
                performReset()
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.debugResetAppDataConfirmButton)
            Button("Cancel", role: .cancel) {}
                .accessibilityIdentifier(AccessibilityIdentifiers.debugResetAppDataCancelButton)
        } message: {
            Text("This erases the detached debug store and this device's sync caches. Your account's own data is not touched.")
        }
        .alert(resetRefusal?.title ?? "", isPresented: refusalBinding, presenting: resetRefusal) { _ in
            Button("OK", role: .cancel) {}
        } message: { refusal in
            Text(refusal.message)
        }
        .sheet(item: $introPreview) { presentation in
            WhatsNewSheet(presentation: presentation) {
                introPreview = nil
            }
            .presentationBackground(Color.sheetBg)
            .presentationDetents([.large])
        }
        // The carousel alone, without the sign-in step it ends in on a real first launch — the
        // artwork and copy are what a preview here is for.
        .fullScreenCover(isPresented: $showsCarouselPreview) {
            OnboardingFlow(
                items: VAOnboardingCarousel.items,
                continueTitle: VAOnboardingCarousel.continueTitle,
                completeTitle: VAOnboardingCarousel.continueTitle
            ) {
                showsCarouselPreview = false
            }
        }
    }

    private var refusalBinding: Binding<Bool> {
        Binding(get: { resetRefusal != nil }, set: { if !$0 { resetRefusal = nil } })
    }

    /// Runs a seed against the **detached** store's context — the only context a debug write is
    /// ever handed here, so there is no path from this screen to the account's own data.
    private func runSeed(_ successMessage: String, operation: @escaping (ModelContext) throws -> Void) {
        guard let debugStore else {
            statusMessage = DebugDemoStore.missingStoreMessage
            return
        }
        do {
            let context = try debugStore.detachedContainer().mainContext
            runOperation(successMessage) { try operation(context) }
        } catch {
            statusMessage = "Debug store unavailable: \(error.localizedDescription)"
        }
    }

    private func performReset() {
        guard let debugStore else {
            statusMessage = DebugDemoStore.missingStoreMessage
            return
        }
        let configuration = VASyncConfiguration.live
        let caches = [
            try? configuration.stateFileURL(),
            try? configuration.accountBlobStateFileURL(),
            try? configuration.accountBlobCacheDirectory(),
        ].compactMap { $0 }
        do {
            try DebugReset.perform(debugStore, isSignedIn: VAAccount.controller.state.isSignedIn, localCaches: caches)
            statusMessage = "Debug store erased."
        } catch let refusal as DebugResetRefusal {
            resetRefusal = refusal
            statusMessage = refusal.message
        } catch {
            statusMessage = "Failed: \(error.localizedDescription)"
            AppLog.error("Debug reset failed", error: error)
        }
    }

    private func runOperation(_ successMessage: String, operation: @escaping () async throws -> Void) {
        guard !isWorking else { return }
        isWorking = true
        statusMessage = "Working..."

        Task {
            do {
                try await operation()
                statusMessage = successMessage
            } catch {
                statusMessage = "Failed: \(error.localizedDescription)"
                AppLog.error("Debug operation failed", error: error)
            }
            isWorking = false
        }
    }

    private func rowPosition(for scenario: DebugOperations.HealthSampleScenario) -> AppGroupedListRowPosition {
        let cases = DebugOperations.HealthSampleScenario.allCases
        if cases.count == 1 { return .single }
        if scenario == cases.first { return .top }
        if scenario == cases.last { return .bottom }
        return .middle
    }
}
#endif

private struct UnitSettingsView: View {
    @Environment(\.modelContext) private var context
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Picker("Weight", selection: $settings.weightUnit) {
                    ForEach(WeightUnit.allCases, id: \.self) { unit in
                        Text(unit.rawValue)
                            .tag(unit)
                    }
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.settingsWeightUnitPicker)
                .appGroupedListRow(position: .top)

                Picker("Height", selection: $settings.heightUnit) {
                    ForEach(HeightUnit.allCases, id: \.self) { unit in
                        Text(unit == .imperial ? "ft/in" : unit.rawValue)
                            .tag(unit)
                    }
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.settingsHeightUnitPicker)
                .appGroupedListRow(position: .middle)

                Picker("Distance", selection: $settings.distanceUnit) {
                    ForEach(DistanceUnit.allCases, id: \.self) { unit in
                        Text(unit.rawValue)
                            .tag(unit)
                    }
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.settingsDistanceUnitPicker)
                .appGroupedListRow(position: .middle)

                Picker("Energy", selection: $settings.energyUnit) {
                    ForEach(EnergyUnit.allCases, id: \.self) { unit in
                        Text(unit.unitLabel)
                            .tag(unit)
                    }
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.settingsEnergyUnitPicker)
                .appGroupedListRow(position: .middle)

                Picker("Temperature", selection: $settings.temperatureUnit) {
                    ForEach(TemperatureUnit.allCases, id: \.self) { unit in
                        Text(unit.unitLabel)
                            .tag(unit)
                    }
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.settingsTemperatureUnitPicker)
                .appGroupedListRow(position: .middle)

                Picker("Speed", selection: $settings.speedUnit) {
                    ForEach(SpeedUnit.allCases, id: \.self) { unit in
                        Text(unit.unitLabel)
                            .tag(unit)
                    }
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.settingsSpeedUnitPicker)
                .appGroupedListRow(position: .bottom)
            } footer: {
                Text("These units control how weight, height, distance, energy, temperature, and speed are displayed throughout the app.")
            }
        }
        .navigationTitle("Units")
        .toolbarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .sheetBackground()
        .onChange(of: settings.weightUnit, initial: false) { oldUnit, newUnit in
            guard oldUnit != newUnit else { return }
            migrateInProgressWeightValues(from: oldUnit, to: newUnit)
            settingChanged(context)
            HealthMetricWidgetReloader.reloadWeight()
        }
        .onChange(of: settings.heightUnit) {
            settingChanged(context)
        }
        .onChange(of: settings.distanceUnit) {
            settingChanged(context)
        }
        .onChange(of: settings.energyUnit) {
            settingChanged(context)
            HealthMetricWidgetReloader.reloadEnergy()
        }
        .onChange(of: settings.temperatureUnit) {
            settingChanged(context)
        }
        .onChange(of: settings.speedUnit) {
            settingChanged(context)
        }
        .diagScreen(VACrumb.settingsUnits)
    }

    private func migrateInProgressWeightValues(from oldUnit: WeightUnit, to newUnit: WeightUnit) {
        if let workout = try? context.fetch(WorkoutSession.incomplete).first,
           workout.statusValue == .active || workout.statusValue == .pending {
            workout.convertSetWeightsToKg(from: oldUnit)
            workout.convertSetWeightsFromKg(to: newUnit)
            WorkoutActivityManager.update(for: workout)
        }

        if let plan = try? context.fetch(WorkoutPlan.incomplete).first {
            plan.convertTargetWeightsToKg(from: oldUnit)
            plan.convertTargetWeightsFromKg(to: newUnit)
        }
    }
}

private struct SettingsLegalWebSheet: View {
    @Environment(\.dismiss) private var dismiss

    let destination: SettingsLegalDestination

    var body: some View {
        NavigationStack {
            WebView(url: destination.url)
                .webViewBackForwardNavigationGestures(.disabled)
                .navigationTitle(destination.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(role: .close) {
                            Haptics.selection()
                            dismiss()
                        }
                        .accessibilityHint(AccessibilityText.closeButtonHint)
                        .accessibilityIdentifier(AccessibilityIdentifiers.settingsLegalWebCloseButton)
                    }
                }
        }
        .diagScreen(VACrumb.settingsLegal)
    }
}

/// A preference moved. Every `onChange` in this file goes through here rather than straight to
/// `saveContext`, so a trail that ends in a crash after someone changed a setting says so — while
/// staying one name, never the setting's own value.
@MainActor private func settingChanged(_ context: ModelContext) {
    Diag.breadcrumb(VACrumb.settingChanged)
    saveContext(context: context)
}

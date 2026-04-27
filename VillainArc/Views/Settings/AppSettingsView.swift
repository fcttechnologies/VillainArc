import SwiftUI
import SwiftData
import UIKit
import UserNotifications

struct AppSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(AppSettings.single) private var appSettings: [AppSettings]

    var body: some View {
        NavigationStack {
            Group {
                if let settings = appSettings.first {
                    AppSettingsFormView(settings: settings)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .listSectionSpacing(20)
            .navigationTitle("Settings")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark", role: .close) {
                        Haptics.selection()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview(traits: .sampleData) {
    AppSettingsView()
}

private struct AppSettingsFormView: View {
    @Environment(\.modelContext) private var context
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    WorkoutPreferencesView()
                } label: {
                    Label("Workouts", systemImage: "figure.strengthtraining.traditional")
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutSettingsButton)
                .accessibilityHint(AccessibilityText.workoutSettingsHint)
                .appGroupedListRow(position: .single)
            } footer: {
                Text("Customize workout logging, prompts, Live Activity behavior, and retention.")
            }

            Section {
                NavigationLink {
                    AppleHealthSettingsView(settings: settings)
                } label: {
                    Label("Apple Health", systemImage: "heart.text.square")
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.settingsAppleHealthLink)
                .accessibilityHint(AccessibilityText.settingsAppleHealthHint)
                .appGroupedListRow(position: .single)
            } footer: {
                Text("Manage Apple Health permissions and choose whether removed Health data stays in this app.")
            }

            Section {
                NavigationLink {
                    NotificationSettingsView(settings: settings)
                } label: {
                    Label("Notifications", systemImage: "bell.badge")
                }
                .appGroupedListRow(position: .single)
            } footer: {
                Text("Manage notification preferences for your health goals.")
            }

            Section {
                NavigationLink {
                    UnitSettingsView(settings: settings)
                } label: {
                    Label("Units", systemImage: "ruler")
                }
                .appGroupedListRow(position: .single)
            } footer: {
                Text("Choose how weight, height, distance, and energy are displayed throughout the app.")
            }

            Section {
                Picker("Theme", systemImage: "circle.lefthalf.filled", selection: $settings.appearanceMode) {
                    ForEach(AppAppearanceMode.allCases, id: \.self) { mode in
                        Text(mode.displayName)
                            .tag(mode)
                    }
                }
                .appGroupedListRow(position: .single)
            } footer: {
                Text("Choose whether the app follows your device appearance or always uses light or dark mode.")
            }
        }
        .scrollContentBackground(.hidden)
        .sheetBackground()
        .onChange(of: settings.appearanceMode) {
            saveContext(context: context)
            dismissAllPresentedSheets()
        }
    }
}

private struct WorkoutPreferencesView: View {
    @Environment(\.modelContext) private var context
    @Query(AppSettings.single) private var appSettings: [AppSettings]
    @Query(WorkoutSession.incomplete) private var incompleteWorkouts: [WorkoutSession]

    private var systemLiveActivitiesAvailable: Bool {
        WorkoutActivityManager.areActivitiesAvailable
    }

    private var activeWorkout: WorkoutSession? {
        incompleteWorkouts.first
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
                    .appGroupedListRow(position: .single)
            } header: {
                Text("Plan Workouts")
            } footer: {
                Text("When this is on, workouts started from a plan prefill each set with its prescribed weight, reps, and rest. Turn it off to keep plan targets available as references without filling the logging fields.")
            }

            Section {
                Toggle("Auto Start Rest Timer", isOn: $settings.autoStartRestTimer)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutSettingsAutoStartTimerToggle)
                    .accessibilityHint(AccessibilityText.workoutSettingsAutoStartTimerHint)
                    .appGroupedListRow(position: .top)
                Toggle("Auto Complete After RPE", isOn: $settings.autoCompleteSetAfterRPE)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutSettingsAutoCompleteAfterRPEToggle)
                    .accessibilityHint(AccessibilityText.workoutSettingsAutoCompleteAfterRPEHint)
                    .appGroupedListRow(position: .bottom)
            } header: {
                Text("Set Logging")
            } footer: {
                Text("After you pick an RPE, the app can mark the set complete for you. If Auto Start Rest Timer is on, it also starts the timer.")
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
                    .appGroupedListRow(position: settings.liveActivitiesEnabled && systemLiveActivitiesAvailable && activeWorkout != nil ? .top : .single)

                if settings.liveActivitiesEnabled && systemLiveActivitiesAvailable, let activeWorkout {
                    Button("Restart Live Activity", systemImage: "arrow.clockwise") {
                        Haptics.selection()
                        WorkoutActivityManager.restart(workout: activeWorkout)
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
            saveContext(context: context)
            guard !settings.retainPerformancesForLearning else { return }
            WorkoutDeletionCoordinator.applyRetentionSetting(context: context, settings: settings)
        }
        .onChange(of: settings.autoStartRestTimer) {
            saveContext(context: context)
        }
        .onChange(of: settings.autoCompleteSetAfterRPE) {
            saveContext(context: context)
        }
        .onChange(of: settings.autoFillPlanTargets) {
            saveContext(context: context)
        }
        .onChange(of: settings.promptForPreWorkoutContext) {
            saveContext(context: context)
        }
        .onChange(of: settings.promptForPostWorkoutEffort) {
            saveContext(context: context)
        }
        .onChange(of: settings.liveActivitiesEnabled) {
            saveContext(context: context)

            if settings.liveActivitiesEnabled {
                if let activeWorkout {
                    WorkoutActivityManager.restart(workout: activeWorkout)
                }
            } else {
                WorkoutActivityManager.end()
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
            saveContext(context: context)
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
            Button("OK", role: .cancel) {}
        } message: {
            Text("Apple does not let this app open the exact Health permission screen directly. Go to Settings, Apps, Health, Health Access and Devices, tap this app, then update the workout permissions.")
        }
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
                .appGroupedListRow(position: .bottom)
            }

            Section {
                Picker("Mode", selection: $settings.stepsNotificationMode) {
                    ForEach(StepsEventNotificationMode.allCases, id: \.self) { mode in
                        Text(mode.title)
                            .tag(mode)
                    }
                }
                .disabled(!notificationsAreAllowedBySystem || backgroundRefreshStatus != .available)
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
                .disabled(!notificationsAreAllowedBySystem || backgroundRefreshStatus != .available)
                .appGroupedListRow(position: .single)
            } header: {
                Text("Sleep")
            } footer: {
                if !notificationsAreAllowedBySystem {
                    Text("Enable notifications in system settings to change this. You can still see in app toasts while using the app.")
                } else if backgroundRefreshStatus != .available {
                    Text("Background App Refresh is off, so sleep notifications may be delayed while the app is closed.")
                } else {
                    Text("Choose whether you receive notifications when you complete your sleep goal only, or also receive coaching notifications such as suggested bedtime reminders.")
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
            }
        }
        .onChange(of: settings.stepsNotificationMode) {
            saveContext(context: context)
        }
        .onChange(of: settings.sleepNotificationMode) {
            saveContext(context: context)
        }
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
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

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
                .appGroupedListRow(position: .top)

                Picker("Height", selection: $settings.heightUnit) {
                    ForEach(HeightUnit.allCases, id: \.self) { unit in
                        Text(unit == .imperial ? "ft/in" : unit.rawValue)
                            .tag(unit)
                    }
                }
                .appGroupedListRow(position: .middle)

                Picker("Distance", selection: $settings.distanceUnit) {
                    ForEach(DistanceUnit.allCases, id: \.self) { unit in
                        Text(unit.rawValue)
                            .tag(unit)
                    }
                }
                .appGroupedListRow(position: .middle)

                Picker("Energy", selection: $settings.energyUnit) {
                    ForEach(EnergyUnit.allCases, id: \.self) { unit in
                        Text(unit.unitLabel)
                            .tag(unit)
                    }
                }
                .appGroupedListRow(position: .bottom)
            } footer: {
                Text("These units control how weight, height, distance, and energy are displayed throughout the app.")
            }
        }
        .navigationTitle("Units")
        .toolbarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .sheetBackground()
        .onChange(of: settings.weightUnit, initial: false) { oldUnit, newUnit in
            guard oldUnit != newUnit else { return }
            migrateInProgressWeightValues(from: oldUnit, to: newUnit)
            saveContext(context: context)
            HealthMetricWidgetReloader.reloadWeight()
        }
        .onChange(of: settings.heightUnit) {
            saveContext(context: context)
        }
        .onChange(of: settings.distanceUnit) {
            saveContext(context: context)
        }
        .onChange(of: settings.energyUnit) {
            saveContext(context: context)
            HealthMetricWidgetReloader.reloadEnergy()
        }
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

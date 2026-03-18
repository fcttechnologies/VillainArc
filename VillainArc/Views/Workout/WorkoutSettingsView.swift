import SwiftUI
import SwiftData

struct WorkoutSettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(AppSettings.single) private var appSettings: [AppSettings]
    @Bindable var workout: WorkoutSession
    private let restTimer = RestTimerState.shared
    @State private var healthAuthorizationState: HealthAuthorizationState = .notDetermined
    @State private var healthAuthorizationAction: HealthAuthorizationAction = .requestAccess
    @State private var isRefreshingHealthStatus = false
    @State private var isHandlingHealthAction = false
    @State private var showHealthAccessInstructions = false

    var body: some View {
        Group {
            if let settings = appSettings.first {
                settingsForm(settings)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task {
                        _ = try? SystemState.ensureAppSettings(context: context)
                }
            }
        }
        .listSectionSpacing(20)
        .navBar(title: "Workout Settings") {
            CloseButton()
        }
        .task {
            await refreshHealthAuthorizationState()
        }
        .onChange(of: scenePhase, initial: false) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await refreshHealthAuthorizationState()
            }
        }
        .alert("Manage Apple Health Access", isPresented: $showHealthAccessInstructions) {
            Button("Open Settings Apps") {
                openHealthSettingsList()
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("Apple doesn’t let Villain Arc open the exact Health permission screen directly. Go to Settings, Apps, Health, Health Access & Devices, tap Villain Arc, then update the workout permissions.")
        }
    }

    private func settingsForm(_ settings: AppSettings) -> some View {
        @Bindable var settings = settings

        return Form {
            Section {
                Toggle("Auto Start Rest Timer", isOn: $settings.autoStartRestTimer)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutSettingsAutoStartTimerToggle)
                    .accessibilityHint(AccessibilityText.workoutSettingsAutoStartTimerHint)
                Toggle("Auto Complete After RPE", isOn: $settings.autoCompleteSetAfterRPE)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutSettingsAutoCompleteAfterRPEToggle)
                    .accessibilityHint(AccessibilityText.workoutSettingsAutoCompleteAfterRPEHint)
            } header: {
                Text("Set Logging")
            } footer: {
                Text("After you pick an RPE, the app can mark the set complete for you. If Auto Start Rest Timer is on, it will also start the timer.")
            }

            Section {
                Toggle("Prompt For Pre Workout Context", isOn: $settings.promptForPreWorkoutContext)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutSettingsPreWorkoutPromptToggle)
                    .accessibilityHint(AccessibilityText.workoutSettingsPreWorkoutPromptHint)
                Toggle("Prompt For Post Workout Effort", isOn: $settings.promptForPostWorkoutEffort)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutSettingsPostWorkoutEffortToggle)
                    .accessibilityHint(AccessibilityText.workoutSettingsPostWorkoutEffortHint)
            } header: {
                Text("Workout Context")
            } footer: {
                Text("When turned off, those prompts stay manual. You can still open pre workout context from the workout title menu.")
            }

            Section {
                Toggle("Retain Performance Snapshots for Suggestion Learning", isOn: $settings.retainPerformancesForLearning)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutSettingsRetainPerformanceSnapshotsToggle)
                    .accessibilityHint(AccessibilityText.workoutSettingsRetainPerformanceSnapshotsHint)
            } header: {
                Text("Workout History")
            } footer: {
                Text("When this is on, deleting a completed workout hides it while keeping its performance snapshots for exercise history and suggestion learning. When it is off, deleting a completed workout permanently removes the session and the suggestion data tied to it.")
            }

            Section {
                Toggle("Send Notifications", isOn: $settings.restTimerNotificationsEnabled)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutSettingsNotificationsToggle)
                    .accessibilityHint(AccessibilityText.workoutSettingsNotificationsHint)
            } header: {
                Text("Rest Timer")
            } footer: {
                Text("Controls local rest timer completion notifications.")
            }

            Section {
                Toggle("Show Live Activity", isOn: $settings.liveActivitiesEnabled)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutSettingsLiveActivitiesToggle)
                    .accessibilityHint(AccessibilityText.workoutSettingsLiveActivitiesHint)
                Button("Restart Live Activity", systemImage: "arrow.clockwise") {
                    Haptics.selection()
                    WorkoutActivityManager.restart(workout: workout)
                }
                .disabled(!settings.liveActivitiesEnabled)
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutSettingsRestartLiveActivityButton)
                .accessibilityHint(AccessibilityText.workoutSettingsRestartLiveActivityHint)
            } header: {
                Text("Live Activity")
            } footer: {
                Text("Turn off live activities completely or restart the current one if it was dismissed accidentally.")
            }

            Section {
                LabeledContent("Status", value: healthAuthorizationState.statusText)

                if healthAuthorizationAction != .unavailable {
                    Button(healthAuthorizationAction.buttonTitle, systemImage: healthAuthorizationAction.systemImage) {
                        Task {
                            await handleHealthAuthorizationAction()
                        }
                    }
                    .disabled(isRefreshingHealthStatus || isHandlingHealthAction)
                    .accessibilityHint(healthAccessHint)
                }

                Toggle("Keep Removed Apple Health Workouts", isOn: $settings.keepRemovedHealthWorkouts)
            } header: {
                Text("Apple Health")
            } footer: {
                Text("VillainArc exports completed workouts to Apple Health whenever Health access is allowed. When this is off, workouts removed from Apple Health are also removed from VillainArc's Health history.")
            }
        }
        .onChange(of: settings.autoStartRestTimer) {
            saveContext(context: context)
        }
        .onChange(of: settings.autoCompleteSetAfterRPE) {
            saveContext(context: context)
        }
        .onChange(of: settings.promptForPreWorkoutContext) {
            saveContext(context: context)
        }
        .onChange(of: settings.promptForPostWorkoutEffort) {
            saveContext(context: context)
        }
        .onChange(of: settings.retainPerformancesForLearning) {
            saveContext(context: context)
            guard !settings.retainPerformancesForLearning else { return }
            WorkoutDeletionCoordinator.applyRetentionSetting(context: context, settings: settings)
        }
        .onChange(of: settings.keepRemovedHealthWorkouts) {
            saveContext(context: context)
            guard !settings.keepRemovedHealthWorkouts else { return }
            Task {
                await HealthWorkoutSyncCoordinator.shared.applyRemovedWorkoutRetentionSetting()
            }
        }
        .onChange(of: settings.liveActivitiesEnabled) {
            saveContext(context: context)
            if settings.liveActivitiesEnabled {
                WorkoutActivityManager.restart(workout: workout)
            } else {
                WorkoutActivityManager.end()
            }
        }
        .onChange(of: settings.restTimerNotificationsEnabled) {
            saveContext(context: context)
            if settings.restTimerNotificationsEnabled, let endDate = restTimer.endDate, restTimer.isRunning {
                Task {
                    await RestTimerNotifications.schedule(endDate: endDate, durationSeconds: restTimer.startedSeconds)
                }
            } else {
                Task {
                    await RestTimerNotifications.cancel()
                }
            }
        }
    }

    private var healthAccessHint: String {
        switch healthAuthorizationAction {
        case .requestAccess:
            return "Requests Apple Health read and write access."
        case .openSettings:
            return "Opens Settings so you can change Apple Health permissions."
        case .manageInSettings:
            return "Opens Settings so you can review Apple Health access."
        case .unavailable:
            return ""
        }
    }

    @MainActor
    private func refreshHealthAuthorizationState() async {
        isRefreshingHealthStatus = true
        let manager = HealthAuthorizationManager.shared
        healthAuthorizationState = manager.currentAuthorizationState
        healthAuthorizationAction = await manager.authorizationAction()
        isRefreshingHealthStatus = false
    }

    @MainActor
    private func handleHealthAuthorizationAction() async {
        guard !isHandlingHealthAction else { return }
        isHandlingHealthAction = true
        defer { isHandlingHealthAction = false }

        switch healthAuthorizationAction {
        case .requestAccess:
            _ = await HealthAuthorizationManager.shared.requestAuthorization()
            await HealthWorkoutSyncCoordinator.shared.syncWorkouts()
            await HealthExportCoordinator.shared.reconcileCompletedSessions()
            await HealthLiveWorkoutSessionCoordinator.shared.ensureRunning(for: workout)
        case .openSettings, .manageInSettings:
            showHealthAccessInstructions = true
        case .unavailable:
            break
        }

        await refreshHealthAuthorizationState()
    }

    private func openHealthSettingsList() {
        guard let url = URL(string: "App-prefs:root=HEALTH") else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    WorkoutSettingsView(workout: sampleIncompleteSession())
        .sampleDataContainerIncomplete()
}

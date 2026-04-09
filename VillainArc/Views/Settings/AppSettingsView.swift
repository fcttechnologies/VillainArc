import SwiftUI
import SwiftData
import UIKit
import UserNotifications

struct AppSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(AppSettings.single) private var appSettings: [AppSettings]

    @State private var healthAuthorizationState: HealthAuthorizationState = .notDetermined
    @State private var healthAuthorizationAction: HealthAuthorizationAction = .requestAccess
    @State private var isRefreshingHealthStatus = false
    @State private var isHandlingHealthAction = false
    @State private var showHealthAccessInstructions = false

    var body: some View {
        NavigationStack {
            Group {
                if let settings = appSettings.first {
                    AppSettingsFormView(
                        settings: settings,
                        healthAuthorizationState: healthAuthorizationState,
                        healthAuthorizationAction: healthAuthorizationAction,
                        isRefreshingHealthStatus: isRefreshingHealthStatus,
                        isHandlingHealthAction: isHandlingHealthAction,
                        healthAccessHint: healthAccessHint,
                        onHealthAuthorizationAction: {
                            await handleHealthAuthorizationAction()
                        }
                    )
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
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
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
        .alert("Manage Apple Health Access", isPresented: $showHealthAccessInstructions) {
            Button("Open Settings Apps") {
                openHealthSettingsList()
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("Apple doesn’t let Villain Arc open the exact Health permission screen directly. Go to Settings, Apps, Health, Health Access & Devices, tap Villain Arc, then update the workout permissions.")
        }
    }

    private var healthAccessHint: String {
        switch healthAuthorizationAction {
        case .requestAccess:
            return String(localized: "Requests Apple Health read and write access.")
        case .openSettings:
            return String(localized: "Opens Settings so you can change Apple Health permissions.")
        case .manageInSettings:
            return String(localized: "Opens Settings so you can review Apple Health access.")
        case .unavailable:
            return ""
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

    private func openHealthSettingsList() {
        guard let url = URL(string: "App-prefs:root=HEALTH") else { return }
        UIApplication.shared.open(url)
    }
}

#Preview(traits: .sampleData) {
    AppSettingsView()
}

private struct AppSettingsFormView: View {
    @Environment(\.modelContext) private var context
    @Bindable var settings: AppSettings

    let healthAuthorizationState: HealthAuthorizationState
    let healthAuthorizationAction: HealthAuthorizationAction
    let isRefreshingHealthStatus: Bool
    let isHandlingHealthAction: Bool
    let healthAccessHint: String
    let onHealthAuthorizationAction: () async -> Void

    var body: some View {
        Form {
            Section {
                Toggle("Retain for Improved Accuracy", isOn: $settings.retainPerformancesForLearning)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutSettingsRetainPerformanceSnapshotsToggle)
                    .accessibilityHint(AccessibilityText.workoutSettingsRetainPerformanceSnapshotsHint)
            } header: {
                Text("Workout History")
            } footer: {
                Text("When this is on, deleting a workout keeps its performances so suggestions have more data to work with. When it is off, it permanently removes the session and the suggestion data tied to it.")
            }

            Section {
                LabeledContent("Status", value: healthAuthorizationState.statusText)

                if healthAuthorizationAction != .unavailable {
                    Button(healthAuthorizationAction.buttonTitle, systemImage: healthAuthorizationAction.systemImage) {
                        Task {
                            await onHealthAuthorizationAction()
                        }
                    }
                    .disabled(isRefreshingHealthStatus || isHandlingHealthAction)
                    .accessibilityHint(healthAccessHint)
                }

                Toggle("Keep Removed Data", isOn: $settings.keepRemovedHealthData)
            } header: {
                Text("Apple Health")
            } footer: {
                Text("When this is off, data removed from Apple Health is also removed from Villain Arc.")
            }

            Section {
                NavigationLink {
                    NotificationSettingsView(settings: settings)
                } label: {
                    Label("Notifications", systemImage: "bell.badge")
                }
            } footer: {
                Text("Choose how Villain Arc handles steps goal notifications.")
            }

            Section {
                NavigationLink {
                    UnitSettingsView(settings: settings)
                } label: {
                    Label("Units", systemImage: "ruler")
                }
            } footer: {
                Text("Choose how weight, height, distance, and energy are displayed throughout the app.")
            }
        }
        .scrollDisabled(true)
        .onChange(of: settings.retainPerformancesForLearning) {
            saveContext(context: context)
            guard !settings.retainPerformancesForLearning else { return }
            WorkoutDeletionCoordinator.applyRetentionSetting(context: context, settings: settings)
        }
        .onChange(of: settings.keepRemovedHealthData) {
            saveContext(context: context)
            guard !settings.keepRemovedHealthData else { return }
            Task {
                await HealthSyncCoordinator.shared.applyRemovedHealthDataRetentionSetting()
            }
        }
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

                Button(notificationActionTitle, systemImage: notificationActionSystemImage) {
                    Task {
                        await handleNotificationAuthorizationAction()
                    }
                }
                .disabled(isHandlingNotificationAction)
            }

            Section {
                Picker("Mode", selection: $settings.stepsNotificationMode) {
                    ForEach(StepsEventNotificationMode.allCases, id: \.self) { mode in
                        Text(mode.title)
                            .tag(mode)
                    }
                }
                .disabled(!notificationsAreAllowedBySystem || backgroundRefreshStatus != .available)
            } header: {
                Text("Goal Completions")
            } footer: {
                if !notificationsAreAllowedBySystem {
                    Text("Enable notifications in system settings to change this. Villain Arc can still show in-app toasts while you’re using the app.")
                } else if backgroundRefreshStatus != .available {
                    Text("Background App Refresh is off, so Villain Arc can’t reliably deliver steps goal notifications while the app is closed.")
                } else {
                    Text("Choose whether Villain Arc schedules local notifications only for goal completions or also for coaching milestones like double goal, triple goal, and new step records. In-app toasts can still appear while you’re using the app.")
                }
            }

        }
        .navigationTitle("Notifications")
        .toolbarTitleDisplayMode(.inline)
        .scrollDisabled(true)
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

                Picker("Height", selection: $settings.heightUnit) {
                    ForEach(HeightUnit.allCases, id: \.self) { unit in
                        Text(unit == .imperial ? "ft/in" : unit.rawValue)
                            .tag(unit)
                    }
                }

                Picker("Distance", selection: $settings.distanceUnit) {
                    ForEach(DistanceUnit.allCases, id: \.self) { unit in
                        Text(unit.rawValue)
                            .tag(unit)
                    }
                }

                Picker("Energy", selection: $settings.energyUnit) {
                    ForEach(EnergyUnit.allCases, id: \.self) { unit in
                        Text(unit.unitLabel)
                            .tag(unit)
                    }
                }
            } footer: {
                Text("These units control how weight, height, distance, and energy are displayed throughout the app.")
            }
        }
        .navigationTitle("Units")
        .toolbarTitleDisplayMode(.inline)
        .scrollDisabled(true)
        .onChange(of: settings.weightUnit) {
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
}

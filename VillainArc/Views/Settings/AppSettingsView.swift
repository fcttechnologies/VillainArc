import SwiftUI
import SwiftData

struct AppSettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(AppSettings.single) private var appSettings: [AppSettings]

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
        .navBar(title: "Settings") {
            CloseButton()
        }
        .task {
            await refreshHealthAuthorizationState()
        }
        .onChange(of: scenePhase, initial: false) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await refreshHealthAuthorizationState()
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

    private func settingsForm(_ settings: AppSettings) -> some View {
        @Bindable var settings = settings

        return Form {
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
                            await handleHealthAuthorizationAction()
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
            } header: {
                Text("Units")
            } footer: {
                Text("These units control how weight, height, distance, and energy are displayed throughout the app.")
            }
        }
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
        .onChange(of: settings.weightUnit) {
            saveContext(context: context)
        }
        .onChange(of: settings.heightUnit) {
            saveContext(context: context)
        }
        .onChange(of: settings.distanceUnit) {
            saveContext(context: context)
        }
        .onChange(of: settings.energyUnit) {
            saveContext(context: context)
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

#Preview {
    AppSettingsView()
        .sampleDataContainer()
}

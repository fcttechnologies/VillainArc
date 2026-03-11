import SwiftUI
import SwiftData

struct WorkoutSettingsView: View {
    @Environment(\.modelContext) private var context
    @Query(AppSettings.single) private var appSettings: [AppSettings]
    @Bindable var workout: WorkoutSession
    private let restTimer = RestTimerState.shared

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
    }

    private func settingsForm(_ settings: AppSettings) -> some View {
        @Bindable var settings = settings

        return Form {
            Section {
                Toggle("Auto Start Rest Timer", isOn: $settings.autoStartRestTimer)
                    .accessibilityIdentifier("workoutSettingsAutoStartTimerToggle")
                Toggle("Auto Complete After RPE", isOn: $settings.autoCompleteSetAfterRPE)
                    .accessibilityIdentifier("workoutSettingsAutoCompleteAfterRPEToggle")
            } header: {
                Text("Set Logging")
            } footer: {
                Text("After you pick an RPE, the app can mark the set complete for you. If Auto Start Rest Timer is on, it will also start the timer.")
            }

            Section {
                Toggle("Send Notifications", isOn: $settings.restTimerNotificationsEnabled)
                    .accessibilityIdentifier("workoutSettingsNotificationsToggle")
            } header: {
                Text("Rest Timer")
            } footer: {
                Text("Controls local rest timer completion notifications.")
            }

            Section {
                Toggle("Show Live Activity", isOn: $settings.liveActivitiesEnabled)
                    .accessibilityIdentifier("workoutSettingsLiveActivitiesToggle")
                Button("Restart Live Activity", systemImage: "arrow.clockwise") {
                    Haptics.selection()
                    WorkoutActivityManager.restart(workout: workout)
                }
                .disabled(!settings.liveActivitiesEnabled)
                .accessibilityIdentifier("workoutSettingsRestartLiveActivityButton")
                .accessibilityHint("Restarts the workout live activity if you dismissed it.")
            } header: {
                Text("Live Activity")
            } footer: {
                Text("Turn off live activities completely or restart the current one if it was dismissed accidentally.")
            }
        }
        .onChange(of: settings.autoStartRestTimer) {
            saveContext(context: context)
        }
        .onChange(of: settings.autoCompleteSetAfterRPE) {
            saveContext(context: context)
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
}

#Preview {
    WorkoutSettingsView(workout: sampleIncompleteSession())
        .sampleDataContainerIncomplete()
}

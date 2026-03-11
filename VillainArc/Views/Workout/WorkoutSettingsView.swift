import SwiftUI

struct WorkoutSettingsView: View {
    @AppStorage(WorkoutPreferences.autoStartRestTimerKey, store: SharedModelContainer.sharedDefaults) private var autoStartRestTimer = true
    @AppStorage(WorkoutPreferences.autoCompleteSetAfterRPEKey, store: SharedModelContainer.sharedDefaults) private var autoCompleteSetAfterRPE = false
    @AppStorage(WorkoutPreferences.liveActivitiesEnabledKey, store: SharedModelContainer.sharedDefaults) private var liveActivitiesEnabled = true
    @AppStorage(WorkoutPreferences.restTimerNotificationsEnabledKey, store: SharedModelContainer.sharedDefaults) private var restTimerNotificationsEnabled = true

    @Bindable var workout: WorkoutSession
    private let restTimer = RestTimerState.shared

    var body: some View {
        Form {
            Section {
                Toggle("Auto Start Rest Timer", isOn: $autoStartRestTimer)
                    .accessibilityIdentifier("workoutSettingsAutoStartTimerToggle")
                Toggle("Auto Complete After RPE", isOn: $autoCompleteSetAfterRPE)
                    .accessibilityIdentifier("workoutSettingsAutoCompleteAfterRPEToggle")
            } header: {
                Text("Set Logging")
            } footer: {
                Text("After you pick an RPE, the app can mark the set complete for you. If Auto Start Rest Timer is on, it will also start the timer.")
            }

            Section {
                Toggle("Send Notifications", isOn: $restTimerNotificationsEnabled)
                    .accessibilityIdentifier("workoutSettingsNotificationsToggle")
            } header: {
                Text("Rest Timer")
            } footer: {
                Text("Controls local rest timer completion notifications.")
            }

            Section {
                Toggle("Show Live Activity", isOn: $liveActivitiesEnabled)
                    .accessibilityIdentifier("workoutSettingsLiveActivitiesToggle")
                Button("Restart Live Activity", systemImage: "arrow.clockwise") {
                    Haptics.selection()
                    WorkoutActivityManager.restart(workout: workout)
                }
                .disabled(!liveActivitiesEnabled)
                .accessibilityIdentifier("workoutSettingsRestartLiveActivityButton")
                .accessibilityHint("Restarts the workout live activity if you dismissed it.")
            } header: {
                Text("Live Activity")
            } footer: {
                Text("Turn off live activities completely or restart the current one if it was dismissed accidentally.")
            }
        }
        .listSectionSpacing(20)
        .navBar(title: "Workout Settings") {
            CloseButton()
        }
        .onChange(of: liveActivitiesEnabled) {
            if liveActivitiesEnabled {
                WorkoutActivityManager.restart(workout: workout)
            } else {
                WorkoutActivityManager.end()
            }
        }
        .onChange(of: restTimerNotificationsEnabled) {
            if restTimerNotificationsEnabled, let endDate = restTimer.endDate, restTimer.isRunning {
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

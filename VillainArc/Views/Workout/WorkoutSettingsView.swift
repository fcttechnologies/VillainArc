import SwiftUI
import SwiftData

struct WorkoutSettingsView: View {
    @Environment(\.modelContext) private var context
    @Query(AppSettings.single) private var appSettings: [AppSettings]
    @Bindable var workout: WorkoutSession

    private var systemLiveActivitiesAvailable: Bool {
        WorkoutActivityManager.areActivitiesAvailable
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
                Toggle("Show Live Activity", isOn: $settings.liveActivitiesEnabled)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutSettingsLiveActivitiesToggle)
                    .accessibilityHint(AccessibilityText.workoutSettingsLiveActivitiesHint)

                if settings.liveActivitiesEnabled && systemLiveActivitiesAvailable {
                    Button("Restart Live Activity", systemImage: "arrow.clockwise") {
                        Haptics.selection()
                        WorkoutActivityManager.restart(workout: workout)
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutSettingsRestartLiveActivityButton)
                    .accessibilityHint(AccessibilityText.workoutSettingsRestartLiveActivityHint)
                }
            } header: {
                Text("Live Activity")
            } footer: {
                Group {
                    Text("Turn off live activities completely or restart the current one if it was dismissed accidentally.")

                    if !systemLiveActivitiesAvailable {
                        Text("Live Activities aren’t available on this device or are turned off in system settings. Villain Arc will fall back to in-app toasts and local notifications when possible.")
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
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
        .onChange(of: settings.liveActivitiesEnabled) {
            saveContext(context: context)
            if settings.liveActivitiesEnabled {
                WorkoutActivityManager.restart(workout: workout)
            } else {
                WorkoutActivityManager.end()
            }

            let restTimer = RestTimerState.shared
            if let endDate = restTimer.endDate, restTimer.isRunning {
                Task {
                    await NotificationCoordinator.scheduleRestTimer(endDate: endDate)
                }
            } else {
                Task {
                    NotificationCoordinator.cancelRestTimer()
                }
            }
        }
    }
}

#Preview(traits: .sampleDataIncomplete) {
    WorkoutSettingsView(workout: sampleIncompleteSession())
}

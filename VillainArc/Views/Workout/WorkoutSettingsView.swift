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
                .appGroupedListRow(position: .bottom)
            } header: {
                Text("Plan Workouts")
            } footer: {
                Text("When Auto Fill Plan Targets is on, workouts started from a plan prefill each set with its prescribed weight, reps, and rest. Show Previous by Default controls whether the reference column shows your last performance instead of the plan target; tap the column header to switch at any time.")
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
                Text("After you pick an RPE, the app can mark the set complete for you. If Auto Start Rest Timer is on, it will also start the timer. Assume Target RPE When Done fills in the target RPE automatically when you mark a set complete without rating it.")
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
                    .appGroupedListRow(position: settings.liveActivitiesEnabled && systemLiveActivitiesAvailable ? .top : .single)

                if settings.liveActivitiesEnabled && systemLiveActivitiesAvailable {
                    Button("Restart Live Activity", systemImage: "arrow.clockwise") {
                        Haptics.selection()
                        WorkoutActivityManager.restart(workout: workout)
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutSettingsRestartLiveActivityButton)
                    .accessibilityHint(AccessibilityText.workoutSettingsRestartLiveActivityHint)
                    .appGroupedListRow(position: .bottom)
                }
            } header: {
                Text("Live Activity")
            } footer: {
                Group {
                    Text("Turn off live activities completely or restart the current one if it was dismissed accidentally.")

                    if !systemLiveActivitiesAvailable {
                        Text("Live Activities are not available on this device or are turned off in system settings. The app will fall back to in app toasts and local notifications when possible.")
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
        .onChange(of: settings.assumeTargetRPEOnComplete) {
            saveContext(context: context)
        }
        .onChange(of: settings.autoFillPlanTargets) {
            saveContext(context: context)
        }
        .onChange(of: settings.prefersTargetReferenceWhenPlanned) {
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

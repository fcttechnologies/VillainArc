import SwiftUI
import SwiftData

struct WorkoutsListView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(WorkoutSession.completedSession) private var workouts: [WorkoutSession]
    @Query(HealthWorkout.history) private var healthWorkouts: [HealthWorkout]
    @Query(AppSettings.single) private var appSettings: [AppSettings]
    @State private var showDeleteAllConfirmation = false
    @State private var isEditing = false
    
    private var editModeBinding: Binding<EditMode> {
        Binding(get: { isEditing ? .active : .inactive }, set: { newValue in isEditing = newValue == .active })
    }

    private var items: [WorkoutHistoryItem] {
        let sessionItems = workouts.map { WorkoutHistoryItem(source: .session($0)) }
        let healthItems = healthWorkouts.compactMap { workout -> WorkoutHistoryItem? in
            if let linkedSession = workout.workoutSession, !linkedSession.isHidden {
                return nil
            }
            return WorkoutHistoryItem(source: .health(workout))
        }

        return (sessionItems + healthItems).sorted { $0.sortDate > $1.sortDate }
    }

    private var deletableWorkouts: [WorkoutSession] {
        workouts
    }

    private var appSettingsSnapshot: AppSettingsSnapshot {
        AppSettingsSnapshot(settings: appSettings.first)
    }
    
    var body: some View {
        List {
            ForEach(items) { item in
                WorkoutHistoryRowView(item: item, appSettingsSnapshot: appSettingsSnapshot, deletionSettings: appSettings.first)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .deleteDisabled(item.session == nil)
                    .accessibilityIdentifier(item.session.map { AccessibilityIdentifiers.workoutRow($0) } ?? AccessibilityIdentifiers.healthWorkoutRow)
                    .accessibilityHint(AccessibilityText.workoutRowHint)
            }
            .onDelete(perform: deleteWorkouts)
        }
        .contentMargins(.bottom, quickActionContentBottomMargin, for: .scrollContent)
        .accessibilityIdentifier(AccessibilityIdentifiers.workoutsList)
        .environment(\.editMode, editModeBinding)
        .animation(reduceMotion ? nil : .smooth, value: isEditing)
        .navigationTitle("Workouts")
        .toolbarTitleDisplayMode(.inline)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationBarBackButtonHidden(isEditing)
        .alert("Delete All Workouts?", isPresented: $showDeleteAllConfirmation) {
            Button("Delete All", role: .destructive) {
                deleteAllWorkouts()
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.workoutsDeleteAllConfirmButton)
        } message: {
            Text("Are you sure you want to delete all previous workouts?")
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if isEditing {
                    Button("Delete All", systemImage: "trash", role: .destructive) {
                        showDeleteAllConfirmation = true
                    }
                    .tint(.red)
                    .labelStyle(.titleOnly)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutsDeleteAllButton)
                    .accessibilityHint(AccessibilityText.workoutsDeleteAllHint)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if !deletableWorkouts.isEmpty {
                    if isEditing {
                        Button("Done Editing", systemImage: "checkmark") {
                            isEditing = false
                        }
                        .labelStyle(.iconOnly)
                        .accessibilityIdentifier(AccessibilityIdentifiers.workoutsDoneEditingButton)
                        .accessibilityHint(AccessibilityText.workoutsDoneEditingHint)
                    } else {
                        Button("Edit", systemImage: "pencil") {
                            isEditing = true
                        }
                        .labelStyle(.titleOnly)
                        .accessibilityIdentifier(AccessibilityIdentifiers.workoutsEditButton)
                        .accessibilityHint(AccessibilityText.workoutsEditHint)
                    }
                }
            }
        }
        .overlay(alignment: .center) {
            if items.isEmpty {
                ContentUnavailableView("No Previous Workouts", systemImage: "clock.arrow.circlepath", description: Text("Your workout history will appear here."))
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutsEmptyState)
            }
        }
    }

    private func deleteWorkouts(offsets: IndexSet) {
        guard !offsets.isEmpty else { return }
        Haptics.selection()
        let workoutsToDelete = offsets.compactMap { items[$0].session }
        guard !workoutsToDelete.isEmpty else { return }

        WorkoutDeletionCoordinator.deleteCompletedWorkouts(workoutsToDelete, context: context, settings: appSettings.first)

        if workoutsToDelete.count == 1, let workout = workoutsToDelete.first {
            Task { await IntentDonations.donateDeleteWorkout(workout: workout) }
        }

        if deletableWorkouts.isEmpty {
            isEditing = false
        }
    }

    private func deleteAllWorkouts() {
        Haptics.selection()
        guard !deletableWorkouts.isEmpty else { return }

        WorkoutDeletionCoordinator.deleteCompletedWorkouts(deletableWorkouts, context: context, settings: appSettings.first)

        Task { await IntentDonations.donateDeleteAllWorkouts() }

        isEditing = false
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        WorkoutsListView()
    }
}

import SwiftUI
import SwiftData

struct WorkoutsListView: View {
    @Environment(\.modelContext) private var context
    @Query(WorkoutSession.completedSession) private var workouts: [WorkoutSession]
    @State private var showDeleteAllConfirmation = false
    @State private var isEditing = false
    
    private var editModeBinding: Binding<EditMode> {
        Binding(get: { isEditing ? .active : .inactive }, set: { newValue in isEditing = newValue == .active })
    }

    var body: some View {
        List {
            ForEach(workouts) { workout in
                WorkoutRowView(workout: workout)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutRow(workout))
                    .accessibilityHint("Shows workout details.")
            }
            .onDelete(perform: deleteWorkouts)
        }
        .accessibilityIdentifier("workoutsList")
        .environment(\.editMode, editModeBinding)
        .animation(.smooth, value: isEditing)
        .navigationTitle("Workouts")
        .toolbarTitleDisplayMode(.inline)
        .listStyle(.plain)
        .navigationBarBackButtonHidden(isEditing)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if isEditing {
                    Button("Delete All", systemImage: "trash", role: .destructive) {
                        showDeleteAllConfirmation = true
                    }
                    .tint(.red)
                    .labelStyle(.titleOnly)
                    .accessibilityIdentifier("workoutsDeleteAllButton")
                    .accessibilityHint("Deletes all completed workouts.")
                    .confirmationDialog("Delete All Workouts?", isPresented: $showDeleteAllConfirmation) {
                        Button("Delete All", role: .destructive) {
                            deleteAllWorkouts()
                        }
                    } message: {
                        Text("Are you sure you want to delete all previous workouts?")
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if !workouts.isEmpty {
                    if isEditing {
                        Button("Done Editing", systemImage: "checkmark") {
                            isEditing = false
                        }
                        .labelStyle(.iconOnly)
                        .accessibilityIdentifier("workoutsDoneEditingButton")
                        .accessibilityHint("Exits edit mode.")
                    } else {
                        Button("Edit", systemImage: "pencil") {
                            isEditing = true
                        }
                        .labelStyle(.titleOnly)
                        .accessibilityIdentifier("workoutsEditButton")
                        .accessibilityHint("Enters edit mode.")
                    }
                }
            }
        }
        .overlay(alignment: .center) {
            if workouts.isEmpty {
                ContentUnavailableView("No Previous Workouts", systemImage: "clock.arrow.circlepath", description: Text("Your workout history will appear here."))
                    .accessibilityIdentifier("workoutsEmptyState")
            }
        }
    }

    private func deleteWorkouts(offsets: IndexSet) {
        guard !offsets.isEmpty else { return }
        Haptics.selection()
        let workoutsToDelete = offsets.map { workouts[$0] }
        
        // Collect affected catalogIDs before deleting
        var affectedCatalogIDs = Set<String>()
        for workout in workoutsToDelete {
            affectedCatalogIDs.formUnion(workout.exercises.map { $0.catalogID })
        }
        
        SpotlightIndexer.deleteWorkoutSessions(ids: workoutsToDelete.map(\.id))
        for workout in workoutsToDelete {
            context.delete(workout)
        }
        saveContext(context: context)
        
        // Update exercise histories for affected exercises
        for catalogID in affectedCatalogIDs {
            ExerciseHistoryUpdater.updateHistory(for: catalogID, context: context)
        }
        
        if workouts.isEmpty {
            isEditing = false
        }
    }

    private func deleteAllWorkouts() {
        Haptics.selection()
        
        // Collect all affected catalogIDs before deleting
        var affectedCatalogIDs = Set<String>()
        for workout in workouts {
            affectedCatalogIDs.formUnion(workout.exercises.map { $0.catalogID })
        }
        
        SpotlightIndexer.deleteWorkoutSessions(ids: workouts.map(\.id))
        for workout in workouts {
            context.delete(workout)
        }
        saveContext(context: context)
        
        // Update exercise histories for affected exercises
        // This will delete histories where no performances remain
        for catalogID in affectedCatalogIDs {
            ExerciseHistoryUpdater.updateHistory(for: catalogID, context: context)
        }
        
        isEditing = false
    }
}

#Preview {
    NavigationStack {
        WorkoutsListView()
    }
    .sampleDataContainer()
}

import SwiftUI
import SwiftData

struct PreviousWorkoutsListView: View {
    @Environment(\.modelContext) private var context
    @Query(Workout.completedWorkouts) private var workouts: [Workout]
    @State private var showDeleteAllConfirmation = false
    @State private var isEditing = false

    var body: some View {
        List {
            ForEach(workouts) { workout in
                WorkoutRowView(workout: workout)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            .onDelete(perform: deleteWorkouts)
        }
        .environment(\.editMode, editModeBinding)
        .animation(.smooth, value: isEditing)
        .navigationTitle("Workouts")
        .toolbarTitleDisplayMode(.inline)
        .listStyle(.plain)
        .navigationBarBackButtonHidden(isEditing)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if isEditing {
                    Button("Delete All", role: .destructive) {
                        showDeleteAllConfirmation = true
                    }
                    .tint(.red)
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
                        Button("Done", systemImage: "checkmark") {
                            isEditing = false
                        }
                        .labelStyle(.iconOnly)
                    } else {
                        Button("Edit") {
                            isEditing = true
                        }
                    }
                }
            }
        }
        .overlay(alignment: .center) {
            if workouts.isEmpty {
                ContentUnavailableView("No Previous Workouts", systemImage: "clock.arrow.circlepath", description: Text("Your workout history will appear here."))
            }
        }
    }

    private var editModeBinding: Binding<EditMode> {
        Binding(
            get: { isEditing ? .active : .inactive },
            set: { newValue in
                isEditing = newValue == .active
            }
        )
    }

    private func deleteWorkouts(offsets: IndexSet) {
        guard !offsets.isEmpty else { return }
        Haptics.warning()
        let workoutsToDelete = offsets.map { workouts[$0] }
        for workout in workoutsToDelete {
            context.delete(workout)
        }
        saveContext(context: context)
        isEditing = !workouts.isEmpty
    }

    private func deleteAllWorkouts() {
        Haptics.warning()
        for workout in workouts {
            context.delete(workout)
        }
        saveContext(context: context)
        isEditing = false
    }
}

#Preview {
    NavigationStack {
        PreviousWorkoutsListView()
    }
    .sampleDataConainer()
    .environment(WorkoutRouter())
}

#Preview("No Previous Workouts") {
    NavigationStack {
        PreviousWorkoutsListView()
    }
}

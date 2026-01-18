import SwiftUI
import SwiftData

struct AddExerciseView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var exercises: [Exercise]
    
    @Bindable var workout: Workout
    @State private var searchText = ""
    @State private var selectedExercises: [Exercise] = []
    @State private var selectedMuscles: [Muscle] = Muscle.allMajor
    @State private var showCancelConfirmation = false

    var body: some View {
        NavigationStack {
            FilteredExerciseListView(selectedExercises: $selectedExercises, searchText: searchText, muscleFilters: selectedMuscles)
                .navigationTitle("Exercises")
                .navigationSubtitle(Text("\(selectedExercises.count) Selected"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .close) {
                            if selectedExercises.isEmpty {
                                dismiss()
                            } else {
                                showCancelConfirmation = true
                            }
                        }
                        .confirmationDialog("Discard selected exercises?", isPresented: $showCancelConfirmation) {
                            Button("Discard Selections", role: .destructive) {
                                Haptics.warning()
                                dismiss()
                            }
                        } message: {
                            Text("If you leave now, the selected exercises will not be added to your workout.")
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(role: .confirm) {
                            Haptics.success()
                            addSelectedExercises()
                        }
                    }
                    ToolbarItem(placement: .bottomBar) {
                        Menu("Muscle Groups", systemImage: "line.3.horizontal.decrease.circle") {
                            ForEach(Muscle.allMajor, id: \.rawValue) { muscle in
                                Toggle(muscle.rawValue, isOn: Binding(get: { selectedMuscles.contains(muscle) }, set: { _ in toggleMuscle(muscle) }))
                                    .menuActionDismissBehavior(.disabled)
                            }
                            Divider()
                            Button("Select All") {
                                selectedMuscles = Muscle.allMajor
                                Haptics.selection()
                            }
                        }
                        .labelStyle(.iconOnly)
                        .menuOrder(.fixed)
                    }
                    ToolbarSpacer(.fixed, placement: .bottomBar)
                    DefaultToolbarItem(kind: .search, placement: .bottomBar)
                }
                .searchable(text: $searchText)
                .searchPresentationToolbarBehavior(.avoidHidingContent)
        }
    }
    
    private func addSelectedExercises() {
        for exercise in selectedExercises {
            workout.addExercise(exercise)
            exercise.updateLastUsed()
        }
        saveContext(context: context)
        dismiss()
    }

    private func toggleMuscle(_ muscle: Muscle) {
        if selectedMuscles.contains(muscle) {
            selectedMuscles.removeAll { $0 == muscle }
        } else {
            selectedMuscles.append(muscle)
        }
        Haptics.selection()
    }
}

#Preview {
    AddExerciseView(workout: Workout())
        .sampleDataConainer()
}

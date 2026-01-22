import SwiftUI
import SwiftData

struct AddExerciseView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var workout: Workout
    let isEditing: Bool
    
    @State private var searchText = ""
    @State private var selectedExercises: [Exercise] = []
    @State private var selectedMuscles: Set<Muscle> = []
    @State private var showAllMuscleGroups = true
    @State private var favoritesOnly = false
    @State private var selectedOnly = false
    @State private var showCancelConfirmation = false

    var body: some View {
        NavigationStack {
            FilteredExerciseListView(selectedExercises: $selectedExercises, searchText: searchText, muscleFilters: selectedMuscles, showAllMuscleGroups: showAllMuscleGroups, favoritesOnly: favoritesOnly, selectedOnly: selectedOnly)
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
                        Menu("Filters", systemImage: "line.3.horizontal.decrease") {
                            Menu("Muscle Groups") {
                                Toggle("All Muscles", isOn: Binding(get: { showAllMuscleGroups }, set: { isOn in
                                    toggleShowAllMuscles(isOn)
                                }))
                                Divider()
                                ForEach(Muscle.allMajor, id: \.rawValue) { muscle in
                                    Toggle(muscle.rawValue, isOn: Binding(get: { selectedMuscles.contains(muscle) }, set: { _ in toggleMuscle(muscle) }))
                                }
                            }
                            .menuOrder(.fixed)
                            Divider()
                            Toggle("Selected Only", isOn: $selectedOnly)
                            Toggle("Favorites Only", isOn: $favoritesOnly)
                        }
                        .labelStyle(.iconOnly)
                        .menuOrder(.fixed)
                    }
                    ToolbarSpacer(.fixed, placement: .bottomBar)
                    DefaultToolbarItem(kind: .search, placement: .bottomBar)
                }
                .searchable(text: $searchText)
                .searchPresentationToolbarBehavior(.avoidHidingContent)
                .task {
                    DataManager.dedupeCatalogExercisesIfNeeded(context: context)
                }
        }
    }
    
    private func addSelectedExercises() {
        for exercise in selectedExercises {
            workout.addExercise(exercise, markSetsComplete: isEditing)
            exercise.updateLastUsed()
        }
        selectedExercises.removeAll()
        saveContext(context: context)
        dismiss()
    }

    private func toggleMuscle(_ muscle: Muscle) {
        if showAllMuscleGroups {
            showAllMuscleGroups = false
            selectedMuscles = [muscle]
            Haptics.selection()
            return
        }
        
        if selectedMuscles.contains(muscle) {
            selectedMuscles.remove(muscle)
            if selectedMuscles.isEmpty {
                showAllMuscleGroups = true
            }
        } else {
            selectedMuscles.insert(muscle)
        }
        Haptics.selection()
    }
    
    private func toggleShowAllMuscles(_ isOn: Bool) {
        if isOn {
            showAllMuscleGroups = true
            selectedMuscles.removeAll()
            Haptics.selection()
            return
        }
        
        if selectedMuscles.isEmpty {
            showAllMuscleGroups = true
            return
        }
        
        showAllMuscleGroups = false
        Haptics.selection()
    }
    
}

#Preview {
    AddExerciseView(workout: sampleIncompleteWorkout(), isEditing: false)
        .sampleDataContainerIncomplete()
}

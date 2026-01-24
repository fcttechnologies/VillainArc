import SwiftUI
import SwiftData

struct AddExerciseView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var workout: Workout
    let isEditing: Bool
    
    @State private var searchText = ""
    @State private var selectedExercises: [Exercise] = []
    @State private var selectedExerciseIDs: Set<String> = []
    @State private var selectedMuscles: Set<Muscle> = []
    @State private var showMuscleFilterSheet = false
    @State private var favoritesOnly = false
    @State private var selectedOnly = false
    @State private var showCancelConfirmation = false
    @State private var exerciseSort: ExerciseSortOption = .mostRecent

    var body: some View {
        NavigationStack {
            FilteredExerciseListView(selectedExercises: $selectedExercises, selectedExerciseIDs: $selectedExerciseIDs, searchText: searchText, muscleFilters: selectedMuscles, favoritesOnly: favoritesOnly, selectedOnly: selectedOnly, sortOption: exerciseSort)
                .navigationTitle("Exercises")
                .navigationSubtitle(Text("\(selectedExercises.count) Selected"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .close) {
                            if selectedExercises.isEmpty {
                                Haptics.selection()
                                dismiss()
                            } else {
                                showCancelConfirmation = true
                            }
                        }
                        .confirmationDialog("Discard selected exercises?", isPresented: $showCancelConfirmation) {
                            Button("Discard Selections", role: .destructive) {
                                Haptics.selection()
                                dismiss()
                            }
                        } message: {
                            Text("If you leave now, the selected exercises will not be added to your workout.")
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(role: .confirm) {
                            Haptics.selection()
                            addSelectedExercises()
                        }
                    }
                    ToolbarItem(placement: .bottomBar) {
                        Menu("Filters", systemImage: "line.3.horizontal.decrease") {
                            Menu("Sort", systemImage: "arrow.up.arrow.down") {
                                Picker("Sort Options", selection: $exerciseSort) {
                                    ForEach(ExerciseSortOption.allCases, id: \.self) { option in
                                        Text(option.rawValue)
                                            .tag(option)
                                    }
                                }
                            }
                            Divider()
                            Toggle("Selected", systemImage: "checkmark.circle", isOn: $selectedOnly)
                            Toggle("Favorites", systemImage: "star", isOn: $favoritesOnly)
                            Button("Muscle Filters", systemImage: "figure") {
                                presentMuscleFilterSheet()
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
                .sheet(isPresented: $showMuscleFilterSheet) {
                    MuscleFilterSheetView(selectedMuscles: selectedMuscles) { updatedMuscles in
                        selectedMuscles = updatedMuscles
                    }
                    .presentationBackground(Color(.systemBackground))
                    .presentationDetents([.fraction(0.3)])
                }
                .task {
                    DataManager.dedupeCatalogExercisesIfNeeded(context: context)
                }
                .onChange(of: favoritesOnly) {
                    Haptics.selection()
                }
                .onChange(of: selectedOnly) {
                    Haptics.selection()
                }
                .onChange(of: exerciseSort) {
                    Haptics.selection()
                }
        }
    }
    
    private func addSelectedExercises() {
        for exercise in selectedExercises {
            workout.addExercise(exercise, markSetsComplete: isEditing)
            exercise.updateLastUsed()
        }
        selectedExercises.removeAll()
        selectedExerciseIDs.removeAll()
        saveContext(context: context)
        dismiss()
    }

    private func presentMuscleFilterSheet() {
        Haptics.selection()
        showMuscleFilterSheet = true
    }
}

enum ExerciseSortOption: String, CaseIterable {
    case mostRecent = "Most Recent"
    case alphabetical = "Alphabetical"

    var sortDescriptors: [SortDescriptor<Exercise>] {
        switch self {
        case .mostRecent:
            return Exercise.recentsSort
        case .alphabetical:
            return [SortDescriptor(\Exercise.name)]
        }
    }
}

#Preview {
    AddExerciseView(workout: sampleIncompleteWorkout(), isEditing: false)
        .sampleDataContainerIncomplete()
}

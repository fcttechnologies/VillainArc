import SwiftUI
import SwiftData

struct AddExerciseView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    private let workout: Workout?
    private let template: WorkoutTemplate?
    private let isEditing: Bool
    
    @State private var searchText = ""
    @State private var selectedExercises: [Exercise] = []
    @State private var selectedExerciseIDs: Set<String> = []
    @State private var selectedMuscles: Set<Muscle> = []
    @State private var showMuscleFilterSheet = false
    @State private var favoritesOnly = false
    @State private var selectedOnly = false
    @State private var showCancelConfirmation = false
    @State private var exerciseSort: ExerciseSortOption = .mostRecent

    init(workout: Workout, isEditing: Bool = false) {
        self.workout = workout
        self.template = nil
        self.isEditing = isEditing
    }
    
    init(template: WorkoutTemplate) {
        self.workout = nil
        self.template = template
        self.isEditing = false
    }

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
                        .accessibilityLabel("Close")
                        .accessibilityIdentifier("addExerciseCloseButton")
                        .confirmationDialog("Discard selected exercises?", isPresented: $showCancelConfirmation) {
                            Button("Discard Selections", role: .destructive) {
                                Haptics.selection()
                                dismiss()
                            }
                            .accessibilityIdentifier("addExerciseDiscardSelectionsButton")
                        } message: {
                            Text(confirmationMessage)
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(role: .confirm) {
                            Haptics.selection()
                            addSelectedExercises()
                        }
                        .accessibilityLabel("Add Exercises")
                        .accessibilityIdentifier("addExerciseConfirmButton")
                        .accessibilityHint(confirmationHint)
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
                            .accessibilityIdentifier("addExerciseSortMenu")
                            Divider()
                            Toggle("Selected", systemImage: "checkmark.circle", isOn: $selectedOnly)
                                .accessibilityIdentifier("addExerciseSelectedToggle")
                            Toggle("Favorites", systemImage: "star", isOn: $favoritesOnly)
                                .accessibilityIdentifier("addExerciseFavoritesToggle")
                            Button("Muscle Filters", systemImage: "figure") {
                                presentMuscleFilterSheet()
                            }
                            .accessibilityIdentifier("addExerciseMuscleFiltersButton")
                            .accessibilityHint("Shows muscle filter options.")
                        }
                        .labelStyle(.iconOnly)
                        .menuOrder(.fixed)
                        .accessibilityIdentifier("addExerciseFiltersMenu")
                        .accessibilityHint("Shows filter options.")
                    }
                    ToolbarSpacer(.fixed, placement: .bottomBar)
                    DefaultToolbarItem(kind: .search, placement: .bottomBar)
                }
                .searchable(text: $searchText)
                .searchPresentationToolbarBehavior(.avoidHidingContent)
                .accessibilityIdentifier("addExerciseListContainer")
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
    
    private var confirmationMessage: String {
        if workout != nil {
            return "If you leave now, the selected exercises will not be added to your workout."
        } else {
            return "If you leave now, the selected exercises will not be added to your template."
        }
    }
    
    private var confirmationHint: String {
        if workout != nil {
            return "Adds the selected exercises to your workout."
        } else {
            return "Adds the selected exercises to your template."
        }
    }
    
    private func addSelectedExercises() {
        if let workout {
            for exercise in selectedExercises {
                workout.addExercise(exercise, markSetsComplete: isEditing)
                exercise.updateLastUsed()
            }
        } else if let template {
            for exercise in selectedExercises {
                template.addExercise(exercise)
                exercise.updateLastUsed()
            }
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

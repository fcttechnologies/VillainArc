import SwiftUI
import SwiftData

struct AddExerciseView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    private let workout: WorkoutSession?
    private let plan: WorkoutPlan?
    
    @State private var searchText = ""
    @State private var selectedExercises: [Exercise] = []
    @State private var selectedExerciseIDs: Set<String> = []
    @State private var selectedMuscles: Set<Muscle> = []
    @State private var showMuscleFilterSheet = false
    @State private var favoritesOnly = false
    @State private var exerciseSort: ExerciseSortOption = .mostRecent

    init(workout: WorkoutSession) {
        self.workout = workout
        self.plan = nil
    }

    init(plan: WorkoutPlan) {
        self.workout = nil
        self.plan = plan
    }

    var body: some View {
        NavigationStack {
            FilteredExerciseListView(
                selectedExercises: $selectedExercises,
                selectedExerciseIDs: $selectedExerciseIDs,
                searchText: searchText,
                muscleFilters: selectedMuscles,
                favoritesOnly: favoritesOnly,
                selectedOnly: false,
                sortOption: exerciseSort,
                onToggle: { exercise, added in
                    if added {
                        if let workout { workout.addExercise(exercise) }
                        else if let plan { plan.addExercise(exercise) }
                    } else {
                        if let workout {
                            if let performance = workout.sortedExercises.last(where: { $0.catalogID == exercise.catalogID }) {
                                workout.deleteExercise(performance)
                            }
                        } else if let plan {
                            if let prescription = plan.sortedExercises.last(where: { $0.catalogID == exercise.catalogID }) {
                                plan.deleteExercise(prescription)
                            }
                        }
                    }
                    saveContext(context: context)
                }
            )
            .navigationTitle("Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Menu("Filters", systemImage: "line.3.horizontal.decrease") {
                        Menu("Sort", systemImage: "arrow.up.arrow.down") {
                            Picker("Sort Options", selection: $exerciseSort) {
                                ForEach(ExerciseSortOption.allCases, id: \.self) { option in
                                    Text(option.displayName)
                                        .tag(option)
                                }
                            }
                        }
                        .accessibilityIdentifier(AccessibilityIdentifiers.addExerciseSortMenu)
                        Divider()
                        Toggle("Favorites", systemImage: "star", isOn: $favoritesOnly)
                            .accessibilityIdentifier(AccessibilityIdentifiers.addExerciseFavoritesToggle)
                        Button("Muscle Filters", systemImage: "figure") {
                            Haptics.selection()
                            showMuscleFilterSheet = true
                        }
                        .accessibilityIdentifier(AccessibilityIdentifiers.addExerciseMuscleFiltersButton)
                        .accessibilityHint(AccessibilityText.addExerciseMuscleFiltersHint)
                    }
                    .labelStyle(.iconOnly)
                    .menuOrder(.fixed)
                    .accessibilityIdentifier(AccessibilityIdentifiers.addExerciseFiltersMenu)
                    .accessibilityHint(AccessibilityText.addExerciseFiltersHint)
                }
                ToolbarSpacer(.fixed, placement: .bottomBar)
                DefaultToolbarItem(kind: .search, placement: .bottomBar)
            }
            .searchable(text: $searchText)
            .searchPresentationToolbarBehavior(.avoidHidingContent)
            .accessibilityIdentifier(AccessibilityIdentifiers.addExerciseListContainer)
            .sheet(isPresented: $showMuscleFilterSheet) {
                MuscleFilterSheetView(selectedMuscles: selectedMuscles) { updatedMuscles in
                    selectedMuscles = updatedMuscles
                }
                .presentationBackground(Color.sheetBg)
                .presentationDetents([.fraction(0.3)])
            }
            .onChange(of: favoritesOnly) {
                Haptics.selection()
            }
            .onChange(of: exerciseSort) {
                Haptics.selection()
            }
            .onDisappear {
                let added = selectedExercises
                for exercise in added { exercise.updateLastAddedAt() }
                saveContext(context: context)
                Task {
                    if added.count == 1, let exercise = added.first {
                        await IntentDonations.donateAddExercise(exercise: exercise)
                    } else if added.count > 1 {
                        await IntentDonations.donateAddExercises(exercises: added)
                    }
                }
            }
        }
    }
}

enum ExerciseSortOption: String, CaseIterable {
    case mostRecent = "Most Recent"
    case alphabetical = "Alphabetical"

    var displayName: String {
        switch self {
        case .mostRecent:
            return String(localized: "Most Recent")
        case .alphabetical:
            return String(localized: "Alphabetical")
        }
    }

    var sortDescriptors: [SortDescriptor<Exercise>] {
        switch self {
        case .mostRecent:
            return Exercise.recentsSort
        case .alphabetical:
            return [SortDescriptor(\Exercise.name)]
        }
    }
}

#Preview(traits: .sampleDataIncomplete) {
    AddExerciseView(workout: sampleIncompleteSession())
}

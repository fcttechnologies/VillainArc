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
    @State private var selectedOnly = false
    @State private var showCancelConfirmation = false
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
            FilteredExerciseListView(selectedExercises: $selectedExercises, selectedExerciseIDs: $selectedExerciseIDs, searchText: searchText, muscleFilters: selectedMuscles, favoritesOnly: favoritesOnly, selectedOnly: selectedOnly, sortOption: exerciseSort)
                .navigationTitle("Exercises")
                .navigationSubtitle(Text(localizedCountText(selectedExercises.count, singular: "selected exercise", plural: "selected exercises")))
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
                        .accessibilityLabel(AccessibilityText.addExerciseCloseLabel)
                        .accessibilityIdentifier(AccessibilityIdentifiers.addExerciseCloseButton)
                        .confirmationDialog("Discard selected exercises?", isPresented: $showCancelConfirmation) {
                            Button("Discard Selections", role: .destructive) {
                                Haptics.selection()
                                dismiss()
                            }
                            .accessibilityIdentifier(AccessibilityIdentifiers.addExerciseDiscardSelectionsButton)
                        } message: {
                            Text(confirmationMessage)
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(role: .confirm) {
                            Haptics.selection()
                            addSelectedExercises()
                        }
                        .accessibilityLabel(AccessibilityText.addExerciseConfirmLabel)
                        .accessibilityIdentifier(AccessibilityIdentifiers.addExerciseConfirmButton)
                        .accessibilityHint(confirmationHint)
                    }
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
                            Toggle("Selected", systemImage: "checkmark.circle", isOn: $selectedOnly)
                                .accessibilityIdentifier(AccessibilityIdentifiers.addExerciseSelectedToggle)
                            Toggle("Favorites", systemImage: "star", isOn: $favoritesOnly)
                                .accessibilityIdentifier(AccessibilityIdentifiers.addExerciseFavoritesToggle)
                            Button("Muscle Filters", systemImage: "figure") {
                                presentMuscleFilterSheet()
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
            return String(localized: "If you leave now, the selected exercises will not be added to your workout.")
        } else {
            return String(localized: "If you leave now, the selected exercises will not be added to your plan.")
        }
    }
    
    private var confirmationHint: String {
        if workout != nil {
            return String(localized: "Adds the selected exercises to your workout.")
        } else {
            return String(localized: "Adds the selected exercises to your plan.")
        }
    }
    
    private func addSelectedExercises() {
        if let workout {
            for exercise in selectedExercises {
                workout.addExercise(exercise)
                exercise.updateLastAddedAt()
            }
        } else if let plan {
            for exercise in selectedExercises {
                plan.addExercise(exercise)
                exercise.updateLastAddedAt()
            }
        }
        let donatedExercises = selectedExercises
        selectedExercises.removeAll()
        selectedExerciseIDs.removeAll()
        saveContext(context: context)
        Task {
            guard !donatedExercises.isEmpty else { return }
            if donatedExercises.count == 1, let exercise = donatedExercises.first {
                await IntentDonations.donateAddExercise(exercise: exercise)
            } else {
                await IntentDonations.donateAddExercises(exercises: donatedExercises)
            }
        }
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

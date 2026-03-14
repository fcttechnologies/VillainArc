import SwiftUI
import SwiftData

struct ReplaceExerciseView: View {
    @Environment(\.dismiss) private var dismiss

    let currentCatalogID: String
    let onReplace: (Exercise, Bool) -> Void

    @State private var searchText = ""
    @State private var selectedExercises: [Exercise] = []
    @State private var selectedExerciseIDs: Set<String> = []
    @State private var selectedMuscles: Set<Muscle> = []
    @State private var showMuscleFilterSheet = false
    @State private var favoritesOnly = false
    @State private var exerciseSort: ExerciseSortOption = .mostRecent
    @State private var showSetsConfirmation = false

    private var selectedExercise: Exercise? {
        selectedExercises.first
    }

    var body: some View {
        NavigationStack {
            FilteredExerciseListView(selectedExercises: $selectedExercises, selectedExerciseIDs: $selectedExerciseIDs, searchText: searchText, muscleFilters: selectedMuscles, favoritesOnly: favoritesOnly, selectedOnly: false, sortOption: exerciseSort, singleSelection: true, excludedCatalogIDs: [currentCatalogID])
            .navigationTitle("Replace Exercise")
            .navigationSubtitle(Text(selectedExercise?.name ?? "Select an exercise"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) {
                        Haptics.selection()
                        dismiss()
                    }
                    .accessibilityLabel(AccessibilityText.replaceExerciseCloseLabel)
                    .accessibilityIdentifier(AccessibilityIdentifiers.replaceExerciseCloseButton)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Replace") {
                        Haptics.selection()
                        showSetsConfirmation = true
                    }
                    .disabled(selectedExercise == nil)
                    .accessibilityIdentifier(AccessibilityIdentifiers.replaceExerciseConfirmButton)
                    .accessibilityHint(AccessibilityText.replaceExerciseConfirmHint)
                    .confirmationDialog("What about existing sets?", isPresented: $showSetsConfirmation) {
                        Button("Keep Sets") {
                            guard let selected = selectedExercise else { return }
                            Haptics.selection()
                            onReplace(selected, true)
                            dismiss()
                        }
                        Button("Clear Sets", role: .destructive) {
                            guard let selected = selectedExercise else { return }
                            Haptics.selection()
                            onReplace(selected, false)
                            dismiss()
                        }
                    }
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
                        Divider()
                        Toggle("Favorites", systemImage: "star", isOn: $favoritesOnly)
                            .accessibilityIdentifier(AccessibilityIdentifiers.replaceExerciseFavoritesToggle)
                        Button("Muscle Filters", systemImage: "figure") {
                            Haptics.selection()
                            showMuscleFilterSheet = true
                        }
                        .accessibilityIdentifier(AccessibilityIdentifiers.replaceExerciseMuscleFiltersButton)
                    }
                    .labelStyle(.iconOnly)
                    .menuOrder(.fixed)
                    .accessibilityIdentifier(AccessibilityIdentifiers.replaceExerciseFiltersMenu)
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
            .onChange(of: favoritesOnly) {
                Haptics.selection()
            }
            .onChange(of: exerciseSort) {
                Haptics.selection()
            }
        }
    }
}

#Preview {
    ReplaceExerciseView(currentCatalogID: "barbell_bench_press") { _, _ in }
        .sampleDataContainerIncomplete()
}

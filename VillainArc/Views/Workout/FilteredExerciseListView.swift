import SwiftUI
import SwiftData

struct FilteredExerciseListView: View {
    @Environment(\.modelContext) private var context
    @Query private var allExercises: [Exercise]
    @Binding var selectedExercises: [Exercise]
    @Binding var selectedExerciseIDs: Set<String>
    @State private var progressionStepExercise: Exercise?
    
    let searchText: String
    let muscleFilters: Set<Muscle>
    let favoritesOnly: Bool
    let selectedOnly: Bool
    let sortOption: ExerciseSortOption
    let singleSelection: Bool
    let excludedCatalogIDs: Set<String>

    init(selectedExercises: Binding<[Exercise]>, selectedExerciseIDs: Binding<Set<String>>, searchText: String, muscleFilters: Set<Muscle>, favoritesOnly: Bool, selectedOnly: Bool, sortOption: ExerciseSortOption, singleSelection: Bool = false, excludedCatalogIDs: Set<String> = []) {
        _selectedExercises = selectedExercises
        _selectedExerciseIDs = selectedExerciseIDs
        self.searchText = searchText
        self.muscleFilters = muscleFilters
        self.favoritesOnly = favoritesOnly
        self.selectedOnly = selectedOnly
        self.sortOption = sortOption
        self.singleSelection = singleSelection
        self.excludedCatalogIDs = excludedCatalogIDs
        
        let predicate: Predicate<Exercise>?
        if selectedOnly {
            predicate = #Predicate<Exercise> { _ in false }
        } else if favoritesOnly {
            predicate = #Predicate<Exercise> { $0.favorite }
        } else {
            predicate = nil
        }
        _allExercises = Query(filter: predicate, sort: sortOption.sortDescriptors)
    }
    
    private var hasFavorites: Bool {
        if selectedOnly {
            return selectedExercises.contains(where: { $0.favorite })
        }
        
        return allExercises.contains(where: { $0.favorite })
    }
    
    private var filteredExercises: [Exercise] {
        let sourceExercises = (selectedOnly ? selectedExercises : allExercises).filter { !excludedCatalogIDs.contains($0.catalogID) }
        let needsFavoriteFilter = favoritesOnly && selectedOnly
        let needsMuscleFilter = !muscleFilters.isEmpty
        let needsFilters = needsFavoriteFilter || needsMuscleFilter

        let baseFiltered = needsFilters ? sourceExercises.filter { exercise in
            let matchesFavorites = !needsFavoriteFilter || exercise.favorite
            let matchesMuscleFilter = !needsMuscleFilter ||
                exercise.musclesTargeted.contains(where: { muscleFilters.contains($0) })
            
            return matchesFavorites && matchesMuscleFilter
        } : sourceExercises

        return searchedExercises(in: baseFiltered, query: searchText, orderedBy: isOrderedBefore, score: { exercise, _, queryTokens in
                exerciseSearchScore(for: exercise, queryTokens: queryTokens)
            })
    }
    
    var body: some View {
        let visibleExercises = filteredExercises

        return List {
            ForEach(visibleExercises) { exercise in
                if selectedExerciseIDs.contains(exercise.catalogID) {
                    Button {
                        Haptics.selection()
                        selectedExercises.removeAll { $0 == exercise }
                        selectedExerciseIDs.remove(exercise.catalogID)
                    } label: {
                        exerciseRow(for: exercise)
                    }
                    .tint(.primary)
                    .listRowBackground(Color.blue.opacity(0.45))
                    .swipeActions(edge: .leading) {
                        favoriteAction(for: exercise)
                    }
                    .contextMenu {
                        progressionStepAction(for: exercise)
                        favoriteAction(for: exercise)
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.exerciseCatalogRow(exercise))
                    .accessibilityLabel(exercise.name)
                    .accessibilityValue(AccessibilityText.exerciseCatalogValue(for: exercise, isSelected: true))
                    .accessibilityHint(AccessibilityText.exerciseSelectionRemoveHint)
                } else {
                    Button {
                        Haptics.selection()
                        if singleSelection {
                            selectedExercises.removeAll()
                            selectedExerciseIDs.removeAll()
                        }
                        selectedExercises.append(exercise)
                        selectedExerciseIDs.insert(exercise.catalogID)
                    } label: {
                        exerciseRow(for: exercise)
                    }
                    .tint(.primary)
                    .swipeActions(edge: .leading) {
                        favoriteAction(for: exercise)
                    }
                    .contextMenu {
                        progressionStepAction(for: exercise)
                        favoriteAction(for: exercise)
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.exerciseCatalogRow(exercise))
                    .accessibilityLabel(exercise.name)
                    .accessibilityValue(AccessibilityText.exerciseCatalogValue(for: exercise, isSelected: false))
                    .accessibilityHint(AccessibilityText.exerciseSelectionAddHint)
                }
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .sheet(isPresented: Binding(get: { progressionStepExercise != nil }, set: { if !$0 { progressionStepExercise = nil } })) {
            if let progressionStepExercise {
                ProgressionStepEditorSheet(exercise: progressionStepExercise)
            }
        }
        .accessibilityIdentifier(AccessibilityIdentifiers.filteredExerciseList)
        .overlay {
            if visibleExercises.isEmpty {
                emptyStateView
            }
        }
    }
    
    @ViewBuilder
    private func exerciseRow(for exercise: Exercise) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(exercise.name)
                    Spacer()
                    if exercise.favorite {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .accessibilityHidden(true)
                    }
                }
                .font(.headline)
                HStack {
                    Text(exercise.equipmentType.displayName)
                    Spacer()
                    Text(exercise.displayMuscle)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fontWeight(.semibold)
            }
        }
        .accessibilityElement(children: .combine)
    }
    
    @ViewBuilder
    private func favoriteAction(for exercise: Exercise) -> some View {
        Button {
            exercise.toggleFavorite()
            Haptics.selection()
            saveContext(context: context)
            Task { await IntentDonations.donateToggleExerciseFavorite(exercise: exercise) }
        } label: {
            if exercise.favorite {
                Label("Unfavorite", systemImage: "star.slash")
            } else {
                Label("Favorite", systemImage: "star")
            }
        }
        .tint(.yellow)
        .accessibilityIdentifier(AccessibilityIdentifiers.exerciseFavoriteToggle(exercise))
    }

    @ViewBuilder
    private func progressionStepAction(for exercise: Exercise) -> some View {
        Button {
            progressionStepExercise = exercise
            Haptics.selection()
        } label: {
            Label("Edit Progression Step", systemImage: "slider.horizontal.3")
        }
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        if selectedOnly && selectedExercises.isEmpty {
            ContentUnavailableView("No Exercises Selected", systemImage: "checkmark.circle", description: Text("Select exercises to see them here."))
                .accessibilityIdentifier(AccessibilityIdentifiers.filteredExerciseEmptySelectedState)
        } else if favoritesOnly && !hasFavorites {
            if selectedOnly {
                ContentUnavailableView("No Favorites Selected", systemImage: "star", description: Text("Select favorite exercises to see them here."))
                    .accessibilityIdentifier(AccessibilityIdentifiers.filteredExerciseEmptyFavoritesSelectedState)
            } else {
                ContentUnavailableView("No Favorites", systemImage: "star", description: Text("Swipe right on an exercise to favorite it."))
                    .accessibilityIdentifier(AccessibilityIdentifiers.filteredExerciseEmptyFavoritesState)
            }
        } else {
            ContentUnavailableView.search(text: searchText)
                .accessibilityIdentifier(AccessibilityIdentifiers.filteredExerciseEmptySearchState)
        }
    }

    private func isOrderedBefore(_ left: Exercise, _ right: Exercise) -> Bool {
        switch sortOption {
        case .mostRecent:
            let leftDate = left.lastAddedAt ?? .distantPast
            let rightDate = right.lastAddedAt ?? .distantPast
            if leftDate != rightDate {
                return leftDate > rightDate
            }
            return left.name.localizedStandardCompare(right.name) == .orderedAscending
        case .alphabetical:
            let nameComparison = left.name.localizedStandardCompare(right.name)
            if nameComparison != .orderedSame {
                return nameComparison == .orderedAscending
            }
            let leftDate = left.lastAddedAt ?? .distantPast
            let rightDate = right.lastAddedAt ?? .distantPast
            return leftDate > rightDate
        }
    }
}

#Preview {
    AddExerciseView(workout: sampleIncompleteSession())
        .sampleDataContainerIncomplete()
}

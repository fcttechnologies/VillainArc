import SwiftUI
import SwiftData

struct FilteredExerciseListView: View {
    @Environment(\.modelContext) private var context
    @Query private var allExercises: [Exercise]
    @Binding var selectedExercises: [Exercise]
    @Binding var selectedExerciseIDs: Set<String>
    @State private var progressionStepExercise: Exercise?
    @State private var infoExercise: Exercise?

    let searchText: String
    let muscleFilters: Set<Muscle>
    let favoritesOnly: Bool
    let selectedOnly: Bool
    let sortOption: ExerciseSortOption
    let singleSelection: Bool
    let excludedCatalogIDs: Set<String>
    let preferredMuscles: Set<Muscle>
    let onToggle: ((Exercise, Bool) -> Void)?

    init(selectedExercises: Binding<[Exercise]>, selectedExerciseIDs: Binding<Set<String>>, searchText: String, muscleFilters: Set<Muscle>, favoritesOnly: Bool, selectedOnly: Bool, sortOption: ExerciseSortOption, singleSelection: Bool = false, excludedCatalogIDs: Set<String> = [], preferredMuscles: Set<Muscle> = [], onToggle: ((Exercise, Bool) -> Void)? = nil) {
        _selectedExercises = selectedExercises
        _selectedExerciseIDs = selectedExerciseIDs
        self.searchText = searchText
        self.muscleFilters = muscleFilters
        self.favoritesOnly = favoritesOnly
        self.selectedOnly = selectedOnly
        self.sortOption = sortOption
        self.singleSelection = singleSelection
        self.excludedCatalogIDs = excludedCatalogIDs
        self.preferredMuscles = preferredMuscles
        self.onToggle = onToggle
        
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
            ForEach(Array(visibleExercises.enumerated()), id: \.element.catalogID) { index, exercise in
                let isSelected = selectedExerciseIDs.contains(exercise.catalogID)
                exerciseListRow(exercise: exercise, isSelected: isSelected, index: index, count: visibleExercises.count)
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .scrollContentBackground(.hidden)
        .sheet(item: $progressionStepExercise) { progressionStepExercise in
            ExerciseSuggestionSettingsSheet(exercise: progressionStepExercise)
                .presentationBackground(Color.sheetBg)
        }
        .sheet(item: $infoExercise) { exercise in
            ExerciseInfoView(
                catalogID: exercise.catalogID,
                isSelected: selectedExerciseIDs.contains(exercise.catalogID),
                onToggleSelect: {
                    if selectedExerciseIDs.contains(exercise.catalogID) {
                        selectedExercises.removeAll { $0 == exercise }
                        selectedExerciseIDs.remove(exercise.catalogID)
                    } else {
                        if singleSelection {
                            selectedExercises.removeAll()
                            selectedExerciseIDs.removeAll()
                        }
                        selectedExercises.append(exercise)
                        selectedExerciseIDs.insert(exercise.catalogID)
                    }
                }
            )
            .presentationBackground(Color.sheetBg)
        }
        .accessibilityIdentifier(AccessibilityIdentifiers.filteredExerciseList)
        .overlay {
            if visibleExercises.isEmpty {
                emptyStateView
            }
        }
    }
    
    @ViewBuilder
    private func exerciseListRow(exercise: Exercise, isSelected: Bool, index: Int, count: Int) -> some View {
        HStack(spacing: 12) {
            Button {
                Haptics.selection()
                infoExercise = exercise
            } label: {
                exerciseRowContent(for: exercise)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.primary)

            Spacer()

            Button {
                Haptics.selection()
                if isSelected {
                    selectedExercises.removeAll { $0 == exercise }
                    selectedExerciseIDs.remove(exercise.catalogID)
                    onToggle?(exercise, false)
                } else {
                    if singleSelection {
                        selectedExercises.removeAll()
                        selectedExerciseIDs.removeAll()
                    }
                    selectedExercises.append(exercise)
                    selectedExerciseIDs.insert(exercise.catalogID)
                    onToggle?(exercise, true)
                }
            } label: {
                Image(systemName: isSelected ? "checkmark" : "plus")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .blue : .primary)
                    .contentTransition(.symbolEffect(.replace))
                    .padding(3)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel(isSelected ? "Remove from selection" : "Add to selection")
        }
        .appGroupedListRow(
            position: rowPosition(for: index, count: count),
            fillColor: nil
        )
        .swipeActions(edge: .leading) {
            favoriteAction(for: exercise)
        }
        .contextMenu {
            progressionStepAction(for: exercise)
            favoriteAction(for: exercise)
        }
        .accessibilityIdentifier(AccessibilityIdentifiers.exerciseCatalogRow(exercise))
        .accessibilityLabel(exercise.name)
        .accessibilityValue(AccessibilityText.exerciseCatalogValue(for: exercise, isSelected: isSelected))
    }

    @ViewBuilder
    private func exerciseRowContent(for exercise: Exercise) -> some View {
        HStack(spacing: 0) {
            if exercise.favorite {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .font(.subheadline)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name)
                    .font(.headline)
                Text("\(exercise.equipmentType.displayName) · \(exercise.displayMuscle)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(1)
            }
            .accessibilityElement(children: .combine)
        }
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
            Label("Suggestion Settings", systemImage: "slider.horizontal.3")
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
        if muscleFilters.isEmpty && !preferredMuscles.isEmpty {
            let leftPreferred = matchesPreferredMuscles(left)
            let rightPreferred = matchesPreferredMuscles(right)
            if leftPreferred != rightPreferred {
                return leftPreferred
            }
        }

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

    private func matchesPreferredMuscles(_ exercise: Exercise) -> Bool {
        exercise.musclesTargeted.contains { preferredMuscles.contains($0) }
    }

    private func rowPosition(for index: Int, count: Int) -> AppGroupedListRowPosition {
        if count <= 1 { return .single }
        if index == 0 { return .top }
        if index == count - 1 { return .bottom }
        return .middle
    }
}

#Preview(traits: .sampleDataIncomplete) {
    AddExerciseView(workout: sampleIncompleteSession())
}

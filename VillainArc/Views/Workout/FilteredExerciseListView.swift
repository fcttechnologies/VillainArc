import SwiftUI
import SwiftData

struct FilteredExerciseListView: View {
    @Environment(\.modelContext) private var context
    @Query private var allExercises: [Exercise]
    @Binding var selectedExercises: [Exercise]
    @Binding var selectedExerciseIDs: Set<String>
    
    let searchText: String
    let muscleFilters: Set<Muscle>
    let favoritesOnly: Bool
    let selectedOnly: Bool
    let sortOption: ExerciseSortOption
    
    init(selectedExercises: Binding<[Exercise]>, selectedExerciseIDs: Binding<Set<String>>, searchText: String, muscleFilters: Set<Muscle>, favoritesOnly: Bool, selectedOnly: Bool, sortOption: ExerciseSortOption) {
        _selectedExercises = selectedExercises
        _selectedExerciseIDs = selectedExerciseIDs
        self.searchText = searchText
        self.muscleFilters = muscleFilters
        self.favoritesOnly = favoritesOnly
        self.selectedOnly = selectedOnly
        self.sortOption = sortOption
        
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
        let cleanText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let queryTokens = normalizedTokens(for: cleanText)
        let sourceExercises = selectedOnly ? selectedExercises : allExercises
        let needsFavoriteFilter = favoritesOnly && selectedOnly
        let needsMuscleFilter = !muscleFilters.isEmpty
        let needsFilters = needsFavoriteFilter || needsMuscleFilter
        
        let isSearchMatch: (Exercise) -> Bool = { exercise in
            matchesSearch(exercise, queryTokens: queryTokens)
        }
        
        if queryTokens.isEmpty && !needsFilters {
            return sourceExercises
        }
        
        let baseFiltered = needsFilters ? sourceExercises.filter { exercise in
            let matchesFavorites = !needsFavoriteFilter || exercise.favorite
            let matchesMuscleFilter = !needsMuscleFilter ||
                exercise.musclesTargeted.contains(where: { muscleFilters.contains($0) })
            
            return matchesFavorites && matchesMuscleFilter
        } : sourceExercises
        
        if queryTokens.isEmpty {
            return baseFiltered
        }
        
        let exactFiltered = baseFiltered.filter { exercise in
            isSearchMatch(exercise)
        }
        
        if !exactFiltered.isEmpty {
            return exactFiltered
        }
        
        guard shouldUseFuzzySearch(queryTokens: queryTokens) else {
            return []
        }
        
        return baseFiltered.filter { exercise in
            matchesSearchFuzzy(exercise, queryTokens: queryTokens)
        }
    }
    
    var body: some View {
        List {
            ForEach(filteredExercises) { exercise in
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
                    .accessibilityIdentifier(AccessibilityIdentifiers.exerciseCatalogRow(exercise))
                    .accessibilityLabel(exercise.name)
                    .accessibilityValue(AccessibilityText.exerciseCatalogValue(for: exercise, isSelected: true))
                    .accessibilityHint("Removes this exercise from your selection.")
                } else {
                    Button {
                        Haptics.selection()
                        selectedExercises.append(exercise)
                        selectedExerciseIDs.insert(exercise.catalogID)
                    } label: {
                        exerciseRow(for: exercise)
                    }
                    .tint(.primary)
                    .swipeActions(edge: .leading) {
                        favoriteAction(for: exercise)
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.exerciseCatalogRow(exercise))
                    .accessibilityLabel(exercise.name)
                    .accessibilityValue(AccessibilityText.exerciseCatalogValue(for: exercise, isSelected: false))
                    .accessibilityHint("Adds this exercise to your selection.")
                }
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .accessibilityIdentifier("filteredExerciseList")
        .overlay {
            if filteredExercises.isEmpty {
                emptyStateView
            }
        }
    }
    
    @ViewBuilder
    private func exerciseRow(for exercise: Exercise) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                Text(exercise.name)
                    .font(.headline)
                Text(exercise.displayMuscles)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
            if exercise.favorite {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .accessibilityHidden(true)
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
    private var emptyStateView: some View {
        if selectedOnly && selectedExercises.isEmpty {
            ContentUnavailableView("No Exercises Selected", systemImage: "checkmark.circle", description: Text("Select exercises to see them here."))
                .accessibilityIdentifier("filteredExerciseEmptySelectedState")
        } else if favoritesOnly && !hasFavorites {
            if selectedOnly {
                ContentUnavailableView("No Favorites Selected", systemImage: "star", description: Text("Select favorite exercises to see them here."))
                    .accessibilityIdentifier("filteredExerciseEmptyFavoritesSelectedState")
            } else {
                ContentUnavailableView("No Favorites", systemImage: "star", description: Text("Swipe right on an exercise to favorite it."))
                    .accessibilityIdentifier("filteredExerciseEmptyFavoritesState")
            }
        } else {
            ContentUnavailableView.search(text: searchText)
                .accessibilityIdentifier("filteredExerciseEmptySearchState")
        }
    }

    private func matchesSearch(_ exercise: Exercise, queryTokens: [String]) -> Bool {
        if queryTokens.isEmpty {
            return true
        }
        
        let haystack = exercise.searchIndex
        return queryTokens.allSatisfy { haystack.contains($0) }
    }

    private func matchesSearchFuzzy(_ exercise: Exercise, queryTokens: [String]) -> Bool {
        if queryTokens.isEmpty {
            return true
        }
        
        let haystackTokens = exercise.searchTokens
        
        return queryTokens.allSatisfy { queryToken in
            let maxDistance = maximumFuzzyDistance(for: queryToken)
            return haystackTokens.contains { token in
                if token == queryToken {
                    return true
                }
                if maxDistance == 0 {
                    return false
                }
                if abs(token.count - queryToken.count) > maxDistance {
                    return false
                }
                return levenshteinDistance(between: token, and: queryToken, maxDistance: maxDistance) <= maxDistance
            }
        }
    }
}

#Preview {
    AddExerciseView(workout: sampleIncompleteWorkout(), isEditing: false)
        .sampleDataContainerIncomplete()
}

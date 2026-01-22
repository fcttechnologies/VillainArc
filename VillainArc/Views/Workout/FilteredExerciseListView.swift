import SwiftUI
import SwiftData

struct FilteredExerciseListView: View {
    @Environment(\.modelContext) private var context
    @Query private var allExercises: [Exercise]
    @Binding var selectedExercises: [Exercise]
    
    let searchText: String
    let muscleFilters: Set<Muscle>
    let showAllMuscleGroups: Bool
    let favoritesOnly: Bool
    let selectedOnly: Bool
    
    init(selectedExercises: Binding<[Exercise]>, searchText: String, muscleFilters: Set<Muscle>, showAllMuscleGroups: Bool, favoritesOnly: Bool, selectedOnly: Bool) {
        _selectedExercises = selectedExercises
        self.searchText = searchText
        self.muscleFilters = muscleFilters
        self.showAllMuscleGroups = showAllMuscleGroups
        self.favoritesOnly = favoritesOnly
        self.selectedOnly = selectedOnly
        
        let predicate: Predicate<Exercise>?
        if selectedOnly {
            predicate = #Predicate<Exercise> { _ in false }
        } else if favoritesOnly {
            predicate = #Predicate<Exercise> { $0.favorite }
        } else {
            predicate = nil
        }
        _allExercises = Query(filter: predicate, sort: Exercise.recentsSort)
    }
    
    private var hasFavorites: Bool {
        if selectedOnly {
            return selectedExercises.contains(where: { $0.favorite })
        }
        
        return allExercises.contains(where: { $0.favorite })
    }
    
    var filteredExercises: [Exercise] {
        let cleanText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let queryTokens = Exercise.normalizedTokens(for: cleanText)
        
        let isSearchMatch: (Exercise) -> Bool = { exercise in
            matchesSearch(exercise, queryTokens: queryTokens)
        }
        
        let sourceExercises = selectedOnly ? selectedExercises : allExercises
        let baseFiltered = sourceExercises.filter { exercise in
            let matchesFavorites = !(favoritesOnly && selectedOnly) || exercise.favorite
            let matchesMuscleFilter = showAllMuscleGroups ||
                muscleFilters.isEmpty ||
                exercise.musclesTargeted.contains(where: { muscleFilters.contains($0) })
            
            return matchesFavorites && matchesMuscleFilter
        }
        
        if queryTokens.isEmpty {
            return baseFiltered
        }
        
        let exactFiltered = baseFiltered.filter { exercise in
            isSearchMatch(exercise)
        }
        
        if !exactFiltered.isEmpty {
            return exactFiltered
        }
        
        return baseFiltered.filter { exercise in
            matchesSearchFuzzy(exercise, queryTokens: queryTokens)
        }
    }
    
    var body: some View {
        List {
            ForEach(filteredExercises) { exercise in
                if selectedExercises.contains(exercise) {
                    Button {
                        Haptics.selection()
                        selectedExercises.removeAll { $0 == exercise }
                    } label: {
                        exerciseRow(for: exercise)
                    }
                    .tint(.primary)
                    .listRowBackground(Color.blue.opacity(0.45))
                    .swipeActions(edge: .leading) {
                        favoriteAction(for: exercise)
                    }
                } else {
                    Button {
                        Haptics.selection()
                        selectedExercises.append(exercise)
                    } label: {
                        exerciseRow(for: exercise)
                    }
                    .tint(.primary)
                    .swipeActions(edge: .leading) {
                        favoriteAction(for: exercise)
                    }
                }
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .overlay {
            if filteredExercises.isEmpty {
                emptyStateView
            }
        }
    }
    
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
            }
        }
    }

    private func matchesSearch(_ exercise: Exercise, queryTokens: [String]) -> Bool {
        if queryTokens.isEmpty {
            return true
        }
        
        let haystack: String
        if exercise.searchIndex.isEmpty {
            let combined = ([exercise.name] + exercise.musclesTargeted.map(\.rawValue)).joined(separator: " ")
            haystack = Exercise.normalizedTokens(for: combined).joined()
        } else {
            haystack = exercise.searchIndex
        }

        return queryTokens.allSatisfy { haystack.contains($0) }
    }

    private func matchesSearchFuzzy(_ exercise: Exercise, queryTokens: [String]) -> Bool {
        if queryTokens.isEmpty {
            return true
        }
        
        let haystackTokens: [String]
        if exercise.searchTokens.isEmpty {
            let combined = ([exercise.name] + exercise.musclesTargeted.map(\.rawValue)).joined(separator: " ")
            haystackTokens = Exercise.normalizedTokens(for: combined)
        } else {
            haystackTokens = exercise.searchTokens
        }
        
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
    
    private func maximumFuzzyDistance(for token: String) -> Int {
        switch token.count {
        case 0...2:
            return 0
        case 3...5:
            return 1
        default:
            return 2
        }
    }
    
    private func levenshteinDistance(between left: String, and right: String, maxDistance: Int) -> Int {
        if left == right {
            return 0
        }
        
        let leftChars = Array(left)
        let rightChars = Array(right)
        
        if abs(leftChars.count - rightChars.count) > maxDistance {
            return maxDistance + 1
        }
        
        var previous = Array(0...rightChars.count)
        
        for i in 0..<leftChars.count {
            var current = [i + 1]
            current.reserveCapacity(rightChars.count + 1)
            var rowMinimum = current[0]
            
            for j in 0..<rightChars.count {
                let cost = leftChars[i] == rightChars[j] ? 0 : 1
                let deletion = previous[j + 1] + 1
                let insertion = current[j] + 1
                let substitution = previous[j] + cost
                let value = min(deletion, insertion, substitution)
                current.append(value)
                rowMinimum = min(rowMinimum, value)
            }
            
            if rowMinimum > maxDistance {
                return maxDistance + 1
            }
            
            previous = current
        }
        
        return previous.last ?? maxDistance + 1
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
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        if selectedOnly && selectedExercises.isEmpty {
            ContentUnavailableView("No Exercises Selected", systemImage: "checkmark.circle", description: Text("Select exercises to see them here."))
        } else if favoritesOnly && !hasFavorites {
            if selectedOnly {
                ContentUnavailableView("No Favorites Selected", systemImage: "star", description: Text("Select favorite exercises to see them here."))
            } else {
                ContentUnavailableView("No Favorites Yet", systemImage: "star", description: Text("Swipe right on an exercise to favorite it."))
            }
        } else {
            ContentUnavailableView.search(text: searchText)
        }
    }
}

#Preview {
    AddExerciseView(workout: sampleIncompleteWorkout(), isEditing: false)
        .sampleDataContainerIncomplete()
}

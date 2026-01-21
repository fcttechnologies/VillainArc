import SwiftUI
import SwiftData

struct FilteredExerciseListView: View {
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]
    @Binding var selectedExercises: [Exercise]
    
    let searchText: String
    let muscleFilters: Set<Muscle>
    let showAllMuscleGroups: Bool
    let favoritesOnly: Bool
    let selectedOnly: Bool
    
    @Environment(\.modelContext) private var context
    
    private var hasFavorites: Bool {
        allExercises.contains(where: { $0.favorite })
    }
    
    var filteredExercises: [Exercise] {
        let cleanText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let matchesSearch: (Exercise) -> Bool = { exercise in
            cleanText.isEmpty ||
            exercise.name.localizedStandardContains(cleanText) ||
            exercise.musclesTargeted.contains(where: { $0.rawValue.localizedStandardContains(cleanText) })
        }
        
        if selectedOnly {
            let filtered = favoritesOnly
                ? selectedExercises.filter { $0.favorite }
                : selectedExercises
            
            return filtered
                .sorted { $0.name < $1.name }
        }
        
        let filtered = allExercises.filter { exercise in
            let matchesFavorites = !favoritesOnly || exercise.favorite
            let matchesMuscleFilter = showAllMuscleGroups ||
                muscleFilters.isEmpty ||
                exercise.musclesTargeted.contains(where: { muscleFilters.contains($0) })
            
            return matchesSearch(exercise) && matchesFavorites && matchesMuscleFilter
        }
        
        return filtered.sorted { first, second in
            switch (first.lastUsed, second.lastUsed) {
            case (.some(let date1), .some(let date2)):
                return date1 > date2
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                return first.name < second.name
            }
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
        if favoritesOnly && !hasFavorites {
            ContentUnavailableView("No Favorites Yet", systemImage: "star", description: Text("Swipe right on an exercise to favorite it."))
        } else if selectedOnly {
            ContentUnavailableView("No Exercises Selected", systemImage: "checkmark.circle", description: Text("Select exercises to see them here."))
        } else {
            ContentUnavailableView.search(text: searchText)
        }
    }
}

#Preview {
    AddExerciseView(workout: Workout(), isEditing: false)
        .sampleDataConainer()
}

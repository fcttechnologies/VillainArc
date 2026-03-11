import SwiftUI
import SwiftData

struct ExercisesListView: View {
    @Environment(\.modelContext) private var context
    @Query(Exercise.all) private var exercises: [Exercise]
    @State private var searchText = ""
    @State private var favoritesOnly = false
    private let appRouter = AppRouter.shared

    private var hasFavorites: Bool {
        exercises.contains(where: \.favorite)
    }

    private var filteredExercises: [Exercise] {
        let sourceExercises = favoritesOnly ? exercises.filter(\.favorite) : exercises
        let cleanText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let queryTokens = normalizedTokens(for: cleanText)

        if queryTokens.isEmpty {
            return sourceExercises
        }

        let scored = exerciseSearchMatches(in: sourceExercises, queryTokens: queryTokens)
        if !scored.isEmpty {
            return scored
                .sorted { left, right in
                    if left.score != right.score {
                        return left.score > right.score
                    }
                    return isOrderedBefore(left.exercise, right.exercise)
                }
                .map(\.exercise)
        }

        guard shouldUseFuzzySearch(queryTokens: queryTokens) else { return [] }

        return sourceExercises
            .filter { matchesSearchFuzzy($0, queryTokens: queryTokens) }
            .sorted(by: isOrderedBefore)
    }

    var body: some View {
        List {
            ForEach(filteredExercises) { exercise in
                Button {
                    appRouter.navigate(to: .exerciseDetail(exercise.catalogID))
                    Task { await IntentDonations.donateOpenExercise(exercise: exercise) }
                } label: {
                    exerciseRow(for: exercise)
                }
                .buttonStyle(.borderless)
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    favoriteAction(for: exercise)
                }
                    .accessibilityIdentifier("exerciseListRow-\(exercise.catalogID)")
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollDismissesKeyboard(.immediately)
        .searchable(text: $searchText)
        .searchPresentationToolbarBehavior(.avoidHidingContent)
        .overlay {
            if exercises.isEmpty {
                ContentUnavailableView("No Exercises", systemImage: "dumbbell", description: Text("Exercises will appear here once the catalog is available."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("exercisesListEmptyState")
            } else if favoritesOnly && !hasFavorites {
                ContentUnavailableView("No Favorites", systemImage: "star.slash", description: Text("Swipe right on an exercise to favorite it."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("exercisesListNoFavoritesState")
            } else if filteredExercises.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("exercisesListSearchEmptyState")
            }
        }
        .accessibilityIdentifier("exercisesListScrollView")
        .navigationTitle("Exercises")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !exercises.isEmpty {
                    Menu("Options", systemImage: "ellipsis") {
                        Toggle("Favorites", systemImage: "star", isOn: $favoritesOnly)
                            .accessibilityIdentifier("exercisesListFavoritesToggle")
                    }
                    .accessibilityIdentifier("exercisesListOptionsMenu")
                }
            }
        }
        .onChange(of: favoritesOnly) {
            Haptics.selection()
        }
    }

    @ViewBuilder
    private func exerciseRow(for exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(exercise.name)
                    .lineLimit(1)
                Spacer()
                if exercise.favorite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .accessibilityHidden(true)
                }
            }
            .font(.title3)

            HStack {
                Text(exercise.equipmentType.rawValue)
                Spacer()
                Text(exercise.displayMuscle)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .fontWeight(.semibold)
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .fontDesign(.rounded)
        .tint(.primary)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func favoriteAction(for exercise: Exercise) -> some View {
        Button(exercise.favorite ? "Unfavorite" : "Favorite", systemImage: exercise.favorite ? "star.slash.fill" : "star.fill") {
            exercise.toggleFavorite()
            Haptics.selection()
            saveContext(context: context)
            Task { await IntentDonations.donateToggleExerciseFavorite(exercise: exercise) }
        }
        .tint(.yellow)
        .accessibilityIdentifier(AccessibilityIdentifiers.exerciseFavoriteToggle(exercise))
    }

    private func matchesSearchFuzzy(_ exercise: Exercise, queryTokens: [String]) -> Bool {
        if queryTokens.isEmpty {
            return true
        }

        let haystackTokens = cachedExerciseSearchTokens(for: exercise)

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

    private func isOrderedBefore(_ left: Exercise, _ right: Exercise) -> Bool {
        let leftDate = left.lastUsed ?? .distantPast
        let rightDate = right.lastUsed ?? .distantPast

        if leftDate != rightDate {
            return leftDate > rightDate
        }

        return left.name.localizedStandardCompare(right.name) == .orderedAscending
    }
}

#Preview {
    NavigationStack {
        ExercisesListView()
    }
    .sampleDataContainerSuggestionGeneration()
}

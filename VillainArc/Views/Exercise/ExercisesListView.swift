import SwiftUI
import SwiftData

struct ExercisesListView: View {
    @Environment(\.modelContext) private var context
    @Query private var exercises: [Exercise]
    @Query(ExerciseHistory.recentCompleted()) private var histories: [ExerciseHistory]
    @Query(AppSettings.single) private var appSettings: [AppSettings]
    @State private var searchText = ""
    @State private var favoritesOnly = false

    private var appSettingsSnapshot: AppSettingsSnapshot { AppSettingsSnapshot(settings: appSettings.first) }

    private var hasFavorites: Bool {
        exercises.contains(where: \.favorite)
    }

    private var historyOrdering: ExerciseHistoryOrdering {
        ExerciseHistoryOrdering(histories: histories)
    }

    private var filteredExercises: [Exercise] {
        let sourceExercises = favoritesOnly ? exercises.filter(\.favorite) : exercises
        return searchedExercises(in: sourceExercises, query: searchText, orderedBy: historyOrdering.isOrderedBefore, score: { exercise, _, queryTokens in
                exerciseSearchScore(for: exercise, queryTokens: queryTokens)
            }
        )
    }

    var body: some View {
        List {
            ForEach(filteredExercises) { exercise in
                ExerciseSummaryRow(exercise: exercise, history: historyOrdering.history(for: exercise), appSettingsSnapshot: appSettingsSnapshot)
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    favoriteAction(for: exercise)
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.exerciseListRow(exercise))
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
                    .accessibilityIdentifier(AccessibilityIdentifiers.exercisesListEmptyState)
            } else if favoritesOnly && !hasFavorites {
                ContentUnavailableView("No Favorites", systemImage: "star.slash", description: Text("Swipe right on an exercise to favorite it."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier(AccessibilityIdentifiers.exercisesListNoFavoritesState)
            } else if filteredExercises.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier(AccessibilityIdentifiers.exercisesListSearchEmptyState)
            }
        }
        .accessibilityIdentifier(AccessibilityIdentifiers.exercisesListScrollView)
        .navigationTitle("Exercises")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !exercises.isEmpty {
                    Menu("Options", systemImage: "ellipsis") {
                        Toggle("Favorites", systemImage: "star", isOn: $favoritesOnly)
                            .accessibilityIdentifier(AccessibilityIdentifiers.exercisesListFavoritesToggle)
                            .accessibilityHint(AccessibilityText.exercisesListFavoritesToggleHint)
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.exercisesListOptionsMenu)
                }
            }
        }
        .onChange(of: favoritesOnly) {
            Haptics.selection()
        }
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
}

#Preview {
    NavigationStack {
        ExercisesListView()
    }
    .sampleDataContainerSuggestionGeneration()
}

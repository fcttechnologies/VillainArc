import SwiftUI
import SwiftData

struct RecentExercisesSectionView: View {
    @Environment(\.modelContext) private var context
    @Query(ExerciseHistory.recentCompleted(limit: 3)) private var histories: [ExerciseHistory]
    @Query(AppSettings.single) private var appSettings: [AppSettings]
    @State private var exercises: [Exercise] = []

    private let appRouter = AppRouter.shared
    private var appSettingsSnapshot: AppSettingsSnapshot { AppSettingsSnapshot(settings: appSettings.first) }

    private var historyOrdering: ExerciseHistoryOrdering {
        ExerciseHistoryOrdering(histories: histories)
    }

    private var recentCatalogIDs: [String] {
        histories.map(\.catalogID)
    }

    private var recentExercises: [Exercise] {
        historyOrdering.recentExercises(from: exercises, orderedBy: histories)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HomeSectionHeaderButton(title: "Exercises", accessibilityIdentifier: AccessibilityIdentifiers.homeExercisesLink, accessibilityHint: AccessibilityText.recentExercisesHeaderHint) {
                appRouter.navigate(to: .exercisesList)
                Task { await IntentDonations.donateOpenExercises() }
            }

            if recentExercises.isEmpty {
                unavailableView
                    .accessibilityIdentifier(AccessibilityIdentifiers.recentExercisesEmptyState)
            } else {
                VStack(spacing: 10) {
                    ForEach(recentExercises) { exercise in
                        ExerciseSummaryRow(exercise: exercise, history: historyOrdering.history(for: exercise), appSettingsSnapshot: appSettingsSnapshot)
                            .accessibilityIdentifier(AccessibilityIdentifiers.recentExerciseRow(exercise))
                    }
                }
            }
        }
        .task(id: recentCatalogIDs) {
            fetchRecentExercises()
        }
    }

    private var unavailableView: some View {
        Button {
            appRouter.navigate(to: .exercisesList)
            Task { await IntentDonations.donateOpenExercises() }
        } label: {
            SmallUnavailableView(sfIconName: "dumbbell", title: "No Exercises Used", subtitle: "Complete exercises in workouts to track progress here.")
                .padding()
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AccessibilityText.recentExercisesUnavailableLabel)
        .accessibilityValue(AccessibilityText.recentExercisesUnavailableValue)
        .accessibilityHint(AccessibilityText.recentExercisesUnavailableHint)
    }

    private func fetchRecentExercises() {
        guard !recentCatalogIDs.isEmpty else {
            exercises = []
            return
        }

        let fetchedExercises = (try? context.fetch(Exercise.withCatalogIDs(recentCatalogIDs))) ?? []
        let exerciseByCatalogID = Dictionary(uniqueKeysWithValues: fetchedExercises.map { ($0.catalogID, $0) })
        exercises = recentCatalogIDs.compactMap { exerciseByCatalogID[$0] }
    }
}

#Preview(traits: .sampleDataSuggestionGeneration) {
    NavigationStack {
        RecentExercisesSectionView()
            .padding()
    }
}

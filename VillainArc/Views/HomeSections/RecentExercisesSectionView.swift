import SwiftUI
import SwiftData

struct RecentExercisesSectionView: View {
    @Query private var exercises: [Exercise]
    @Query private var histories: [ExerciseHistory]

    private let appRouter = AppRouter.shared

    init() {
        _exercises = Query()
        _histories = Query(ExerciseHistory.recentCompleted(limit: 3))
    }

    private var recentExercises: [Exercise] {
        let exerciseByCatalogID = Dictionary(uniqueKeysWithValues: exercises.map { ($0.catalogID, $0) })
        return histories.compactMap { exerciseByCatalogID[$0.catalogID] }
    }

    private var historyByCatalogID: [String: ExerciseHistory] {
        Dictionary(uniqueKeysWithValues: histories.map { ($0.catalogID, $0) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HomeSectionHeaderButton(title: "Exercises", accessibilityIdentifier: "homeExercisesLink", accessibilityHint: "Shows all tracked exercises.") {
                appRouter.navigate(to: .exercisesList)
                Task { await IntentDonations.donateOpenExercises() }
            }

            if recentExercises.isEmpty {
                unavailableView
                    .accessibilityIdentifier("recentExercisesEmptyState")
            } else {
                VStack(spacing: 10) {
                    ForEach(recentExercises) { exercise in
                        ExerciseSummaryRow(exercise: exercise, history: historyByCatalogID[exercise.catalogID])
                            .accessibilityIdentifier("recentExerciseRow-\(exercise.catalogID)")
                    }
                }
            }
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
        .accessibilityLabel("No Exercises Used")
        .accessibilityValue("Complete exercises in workouts to track progress here.")
        .accessibilityHint("Shows all tracked exercises.")
    }
}

#Preview {
    NavigationStack {
        RecentExercisesSectionView()
            .padding()
    }
    .sampleDataContainerSuggestionGeneration()
}

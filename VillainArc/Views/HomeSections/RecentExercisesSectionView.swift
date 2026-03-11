import SwiftUI
import SwiftData

struct RecentExercisesSectionView: View {
    @Query private var exercises: [Exercise]
    @Query private var histories: [ExerciseHistory]

    private let appRouter = AppRouter.shared

    init() {
        _exercises = Query(Exercise.all)
        _histories = Query()
    }

    private var recentExercises: [Exercise] {
        Array(exercises.filter { $0.lastUsed != nil }.prefix(3))
    }

    private var historyByCatalogID: [String: ExerciseHistory] {
        Dictionary(uniqueKeysWithValues: histories.map { ($0.catalogID, $0) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HomeSectionHeaderButton(title: "Exercises", accessibilityIdentifier: "homeExercisesLink", accessibilityHint: "Shows all tracked exercises.") {
                appRouter.navigate(to: .exercisesList)
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

import SwiftUI
import SwiftData

struct ExerciseHistoryView: View {
    let catalogID: String

    private let workoutExercise: ExercisePerformance?
    private let planExercise: ExercisePrescription?

    @Query private var exercises: [Exercise]
    @Query private var performances: [ExercisePerformance]

    init(catalogID: String) {
        self.catalogID = catalogID
        workoutExercise = nil
        planExercise = nil
        _exercises = Query(Exercise.withCatalogID(catalogID))
        _performances = Query(ExercisePerformance.matching(catalogID: catalogID))
    }

    init(exercise: ExercisePerformance) {
        catalogID = exercise.catalogID
        workoutExercise = exercise
        planExercise = nil
        _exercises = Query(Exercise.withCatalogID(exercise.catalogID))
        _performances = Query(ExercisePerformance.matching(catalogID: exercise.catalogID))
    }

    init(exercise: ExercisePrescription) {
        catalogID = exercise.catalogID
        workoutExercise = nil
        planExercise = exercise
        _exercises = Query(Exercise.withCatalogID(catalogID))
        _performances = Query(ExercisePerformance.matching(catalogID: catalogID))
    }

    private var exercise: Exercise? {
        exercises.first
    }

    var body: some View {
        List {
            ForEach(performances) { performance in
                Section {
                    Grid(verticalSpacing: 10) {
                        GridRow {
                            Text("Set")
                            Spacer()
                            Text("Reps")
                            Spacer()
                            Text("Weight")
                            Spacer()
                            Text("Rest")
                        }
                        .font(.title3)
                        .bold()
                        .accessibilityHidden(true)

                        ForEach(performance.sortedSets) { set in
                            GridRow {
                                setIndicator(for: set)
                                    .gridColumnAlignment(.leading)
                                Spacer()
                                Text(set.reps > 0 ? "\(set.reps)" : "-")
                                    .gridColumnAlignment(.leading)
                                Spacer()
                                Text(set.weight > 0 ? "\(set.weight, format: .number) lbs" : "-")
                                    .gridColumnAlignment(.leading)
                                Spacer()
                                Text(set.effectiveRestSeconds > 0 ? secondsToTime(set.effectiveRestSeconds) : "-")
                                    .gridColumnAlignment(.leading)
                            }
                            .font(.title3)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    HStack(alignment: .bottom) {
                        Text(formattedDateRange(start: performance.date))
                        Spacer()
                        if let repRange = performance.repRange, repRange.activeMode != .notSet {
                            Text(repRange.displayText)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                    }
                } footer: {
                    if !performance.notes.isEmpty {
                        Text(performance.notes)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if performances.isEmpty {
                ContentUnavailableView("No Exercise History", systemImage: "clock.arrow.circlepath", description: Text("Complete this exercise in a workout to see every performance here."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("exerciseHistoryEmptyState")
            }
        }
        .accessibilityIdentifier("exerciseHistoryList")
        .navigationTitle(exercise?.name ?? "Exercise History")
        .navigationSubtitle(Text(exercise?.detailSubtitle ?? "Unknown Equipment"))
        .toolbarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func setIndicator(for set: SetPerformance) -> some View {
        Text(set.type == .working ? String(set.index + 1) : set.type.shortLabel)
            .foregroundStyle(set.type.tintColor)
            .overlay(alignment: .bottomTrailing) {
                if let visibleRPE = set.visibleRPE {
                    RPEBadge(value: visibleRPE)
                        .offset(x: visibleRPE == 10 ? 12 : 9, y: 5)
                }
            }
    }
}

#Preview("Exercise History") {
    NavigationStack {
        ExerciseHistoryView(catalogID: "dumbbell_incline_bench_press")
    }
    .sampleDataContainerSuggestionGeneration()
}

#Preview("Exercise History Empty") {
    NavigationStack {
        ExerciseHistoryView(catalogID: "barbell_bent_over_row")
    }
    .sampleDataContainer()
}

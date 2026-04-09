import SwiftUI
import SwiftData

struct ExerciseHistoryView: View {
    let catalogID: String

    private let workoutExercise: ExercisePerformance?
    private let planExercise: ExercisePrescription?

    @Query private var exercises: [Exercise]
    @Query private var performances: [ExercisePerformance]
    @Query(AppSettings.single) private var appSettings: [AppSettings]

    private var weightUnit: WeightUnit { appSettings.first?.weightUnit ?? .lbs }

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
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(performances) { performance in
                    ExerciseHistoryPerformanceCard(performance: performance, weightUnit: weightUnit)
                }
            }
            .fontDesign(.rounded)
            .padding(.horizontal)
            .padding(.vertical, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if performances.isEmpty {
                ContentUnavailableView("No Exercise History", systemImage: "clock.arrow.circlepath", description: Text("Complete this exercise in a workout to see every performance here."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier(AccessibilityIdentifiers.exerciseHistoryEmptyState)
            }
        }
        .accessibilityIdentifier(AccessibilityIdentifiers.exerciseHistoryList)
        .navigationTitle(exercise?.name ?? "Exercise History")
        .navigationSubtitle(Text(exercise?.detailSubtitle ?? "Unknown Equipment"))
        .toolbarTitleDisplayMode(.inline)
    }
}

private struct ExerciseHistoryPerformanceCard: View {
    let performance: ExercisePerformance
    let weightUnit: WeightUnit

    private var exerciseNotes: String {
        performance.notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var workoutNotes: String {
        performance.workoutSession?.notes.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 12) {
                    Text(formattedDateRange(start: performance.date))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let repRange = performance.repRange, repRange.activeMode != .notSet {
                        Text(repRange.displayText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .fontWeight(.semibold)

                if !exerciseNotes.isEmpty || !workoutNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        if !exerciseNotes.isEmpty {
                            Text(workoutNotes.isEmpty ? exerciseNotes : "Exercise notes: \(exerciseNotes)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }

                        if !workoutNotes.isEmpty {
                            Text("Workout notes: \(workoutNotes)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                    }
                }
            }

            Divider()

            ExerciseSetTable(
                rows: performance.sortedSets,
                repsText: { $0.reps > 0 ? "\($0.reps)" : "-" },
                weightText: { $0.weight > 0 ? formattedWeightText($0.weight, unit: weightUnit) : "-" },
                restText: { $0.effectiveRestSeconds > 0 ? secondsToTime($0.effectiveRestSeconds) : "-" }
            ) { set in
                ExerciseHistorySetIndicator(set: set)
            }
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct ExerciseHistorySetIndicator: View {
    let set: SetPerformance

    var body: some View {
        Text(set.type == .working ? String(set.index + 1) : set.type.shortLabel)
            .foregroundStyle(set.type.tintColor)
            .overlay(alignment: .topTrailing) {
                if let visibleRPE = set.visibleRPE {
                    RPEBadge(value: visibleRPE)
                        .offset(x: 7, y: -7)
                }
            }
    }
}

#Preview("Exercise History", traits: .sampleDataSuggestionGeneration) {
    NavigationStack {
        ExerciseHistoryView(catalogID: "dumbbell_incline_bench_press")
    }
}

#Preview("Exercise History Empty", traits: .sampleData) {
    NavigationStack {
        ExerciseHistoryView(catalogID: "barbell_bent_over_row")
    }
}

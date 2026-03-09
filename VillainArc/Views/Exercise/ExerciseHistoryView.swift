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

    private var subtitle: String {
        let majorMuscles = ListFormatter.localizedString(byJoining: (exercise?.musclesTargeted ?? []).filter(\.isMajor).map(\.rawValue))
        let muscles = majorMuscles.isEmpty ? (exercise?.displayMuscle ?? "") : majorMuscles
        let equipment = exercise?.equipmentType.rawValue ?? "Unknown Equipment"
        return muscles.isEmpty ? equipment : "\(muscles) • \(equipment)"
    }

    var body: some View {
        List {
            ForEach(performances) { performance in
                Section {
                    Grid(verticalSpacing: 6) {
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
                                Text(set.type == .working ? String(set.index + 1) : set.type.shortLabel)
                                    .foregroundStyle(set.type.tintColor)
                                    .gridColumnAlignment(.leading)
                                Spacer()
                                Text(set.reps, format: .number)
                                    .gridColumnAlignment(.leading)
                                Spacer()
                                Text("\(set.weight, format: .number) lbs")
                                    .gridColumnAlignment(.leading)
                                Spacer()
                                Text(secondsToTime(set.effectiveRestSeconds))
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
                        Text(performance.repRange?.displayText ?? "Rep Range: Not Set")
                            .font(.subheadline)
                            .fontWeight(.semibold)
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
        .navigationSubtitle(Text(subtitle))
        .toolbarTitleDisplayMode(.inline)
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

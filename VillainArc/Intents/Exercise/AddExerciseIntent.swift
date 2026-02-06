import AppIntents
import SwiftData

struct AddExerciseIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Exercise"
    static let description = IntentDescription("Adds an exercise to the workout session or workout plan.")
    static let supportedModes: IntentModes = .background
    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$exercise)")
    }

    @Parameter(title: "Exercise", requestValueDialog: IntentDialog("Which exercise?"))
    var exercise: ExerciseEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedModelContainer.container.mainContext
        DataManager.dedupeCatalogExercisesIfNeeded(context: context)

        let exerciseID = exercise.id
        let predicate = #Predicate<Exercise> { $0.catalogID == exerciseID }
        let descriptor = FetchDescriptor(predicate: predicate)
        
        guard let resolvedExercise = try? context.fetch(descriptor).first else {
            return .result(dialog: "Exercise not found.")
        }

        if let workout = try? context.fetch(WorkoutSession.incomplete).first {
            workout.addExercise(resolvedExercise)
            resolvedExercise.updateLastUsed()
            SpotlightIndexer.index(exercise: resolvedExercise)
            ExerciseHistoryUpdater.createIfNeeded(for: resolvedExercise.catalogID, context: context)
            saveContext(context: context)
            WorkoutActivityManager.update(for: workout)
            return .result(dialog: "Added \(resolvedExercise.name) to your workout.")
        }

        if let workoutPlan = try? context.fetch(WorkoutPlan.incomplete).first {
            workoutPlan.addExercise(resolvedExercise)
            resolvedExercise.updateLastUsed()
            SpotlightIndexer.index(exercise: resolvedExercise)
            saveContext(context: context)
            return .result(dialog: "Added \(resolvedExercise.name) to your template.")
        }

        return .result(dialog: "No active workout or workout plan found.")
    }
}

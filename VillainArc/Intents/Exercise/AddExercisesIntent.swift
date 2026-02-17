import AppIntents
import SwiftData

struct AddExercisesIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Exercises"
    static let description = IntentDescription("Adds exercises to the workout session or workout plan.")
    static let supportedModes: IntentModes = .background
    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$exercises)")
    }

    @Parameter(title: "Exercises", requestValueDialog: IntentDialog("Which exercises?"))
    var exercises: [ExerciseEntity]

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedModelContainer.container.mainContext

        guard !exercises.isEmpty else {
            return .result(dialog: "No exercises selected.")
        }

        if let workout = try? context.fetch(WorkoutSession.incomplete).first {
            let dialog = addExercises(to: workout, context: context)
            return .result(dialog: dialog)
        }

        if let workoutPlan = try? context.fetch(WorkoutPlan.incomplete).first {
            let dialog = addExercises(to: workoutPlan, context: context)
            return .result(dialog: dialog)
        }

        return .result(dialog: "No current workout session or workout plan found.")
    }

    @MainActor
    private func addExercises(to workout: WorkoutSession, context: ModelContext) -> IntentDialog {
        let resolvedExercises = resolveExercises(in: context)
        guard !resolvedExercises.isEmpty else {
            return "No exercises found to add."
        }

        for exercise in resolvedExercises {
            workout.addExercise(exercise)
            exercise.updateLastUsed()
            SpotlightIndexer.index(exercise: exercise)
        }
        saveContext(context: context)
        let count = resolvedExercises.count
        if count == 1 {
            return "Added exercise to your workout."
        }
        return "Added \(count) exercises to your workout."
    }

    @MainActor
    private func addExercises(to plan: WorkoutPlan, context: ModelContext) -> IntentDialog {
        let resolvedExercises = resolveExercises(in: context)
        guard !resolvedExercises.isEmpty else {
            return "No exercises found to add."
        }

        for exercise in resolvedExercises {
            plan.addExercise(exercise)
            exercise.updateLastUsed()
            SpotlightIndexer.index(exercise: exercise)
        }
        saveContext(context: context)
        let count = resolvedExercises.count
        if count == 1 {
            return "Added exercise to your workout plan."
        }
        return "Added \(count) exercises to your workout plan."
    }

    @MainActor
    private func resolveExercises(in context: ModelContext) -> [Exercise] {
        let ids = exercises.map(\.id)
        guard !ids.isEmpty else { return [] }
        let predicate = #Predicate<Exercise> { ids.contains($0.catalogID) }
        let descriptor = FetchDescriptor(predicate: predicate)
        let matchedExercises = (try? context.fetch(descriptor)) ?? []
        let exercisesByID = Dictionary(matchedExercises.map { ($0.catalogID, $0) }, uniquingKeysWith: { first, _ in first })
        return ids.compactMap { exercisesByID[$0] }
    }
}

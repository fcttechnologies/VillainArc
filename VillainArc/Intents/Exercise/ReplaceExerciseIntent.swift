import AppIntents
import SwiftData

struct ReplaceExerciseIntent: AppIntent {
    static let title: LocalizedStringResource = "Replace Exercise"
    static let description = IntentDescription("Replaces the current exercise in the active workout with a different one.")
    static let supportedModes: IntentModes = .background
    static var parameterSummary: some ParameterSummary {
        Summary("Replace current exercise with \(\.$newExercise)")
    }

    @Parameter(title: "New Exercise", requestValueDialog: IntentDialog("Which exercise should replace it?"))
    var newExercise: ExerciseEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedModelContainer.container.mainContext

        guard let workout = try? context.fetch(WorkoutSession.incomplete).first else {
            return .result(dialog: "No active workout found.")
        }

        guard let activeExercise = workout.activeExercise else {
            return .result(dialog: "No active exercise to replace.")
        }

        let exerciseID = newExercise.id
        let predicate = #Predicate<Exercise> { $0.catalogID == exerciseID }
        let descriptor = FetchDescriptor(predicate: predicate)

        guard let resolvedExercise = try? context.fetch(descriptor).first else {
            return .result(dialog: "Exercise not found.")
        }

        let oldName = activeExercise.name
        let hasSets = !activeExercise.sets!.isEmpty

        let keepSets: Bool
        if hasSets {
            let keepOption = IntentChoiceOption(title: "Keep existing sets", style: .default)
            let clearOption = IntentChoiceOption(title: "Clear sets and start fresh", style: .destructive)
            let choice = try await requestChoice(
                between: [keepOption, clearOption, .cancel],
                dialog: IntentDialog("What should happen to the existing sets?")
            )
            if choice.style == .cancel {
                return .result(dialog: "Replace canceled.")
            }
            keepSets = choice.style == .default
        } else {
            keepSets = false
        }

        activeExercise.replaceWith(resolvedExercise, keepSets: keepSets)
        resolvedExercise.updateLastUsed()
        SpotlightIndexer.index(exercise: resolvedExercise)
        saveContext(context: context)
        WorkoutActivityManager.update(for: workout)

        if keepSets {
            return .result(dialog: "Replaced \(oldName) with \(resolvedExercise.name), kept existing sets.")
        }
        return .result(dialog: "Replaced \(oldName) with \(resolvedExercise.name).")
    }
}

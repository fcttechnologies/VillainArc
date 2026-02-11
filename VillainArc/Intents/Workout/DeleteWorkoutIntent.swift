import AppIntents
import SwiftData

struct DeleteWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Delete Workout"
    static let description = IntentDescription("Deletes a completed workout.")
    static let supportedModes: IntentModes = .foreground(.dynamic)
    static var parameterSummary: some ParameterSummary {
        Summary("Delete \(\.$workout)")
    }

    @Parameter(title: "Workout", requestValueDialog: IntentDialog("Which workout would you like to delete?"))
    var workout: WorkoutSessionEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedModelContainer.container.mainContext

        let workoutID = workout.id
        let predicate = #Predicate<WorkoutSession> { $0.id == workoutID }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1

        guard let storedWorkout = try context.fetch(descriptor).first else {
            throw DeleteWorkoutIntentError.workoutNotFound
        }
        guard storedWorkout.status == SessionStatus.done.rawValue else {
            throw DeleteWorkoutIntentError.workoutIncomplete
        }

        let choice = try await requestChoice(
            between: [IntentChoiceOption(title: "Delete Workout", style: .destructive), .cancel],
            dialog: IntentDialog("Delete \"\(storedWorkout.title)\"? This action cannot be undone.")
        )

        guard choice.style == .destructive else {
            throw DeleteWorkoutIntentError.cancelled
        }

        var affectedCatalogIDs = Set<String>()
        affectedCatalogIDs.formUnion(storedWorkout.exercises.map { $0.catalogID })

        SpotlightIndexer.deleteWorkoutSession(id: storedWorkout.id)
        context.delete(storedWorkout)

        for catalogID in affectedCatalogIDs {
            ExerciseHistoryUpdater.updateHistory(for: catalogID, context: context)
        }

        saveContext(context: context)
        return .result(dialog: "Workout deleted.")
    }
}

enum DeleteWorkoutIntentError: Error, CustomLocalizedStringResourceConvertible {
    case workoutNotFound
    case workoutIncomplete
    case cancelled

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .workoutNotFound:
            return "That workout is no longer available."
        case .workoutIncomplete:
            return "Only completed workouts can be deleted."
        case .cancelled:
            return "Delete workout canceled."
        }
    }
}

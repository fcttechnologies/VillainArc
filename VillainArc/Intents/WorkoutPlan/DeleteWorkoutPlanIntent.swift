import AppIntents
import SwiftData

struct DeleteWorkoutPlanIntent: AppIntent {
    static let title: LocalizedStringResource = "Delete Workout Plan"
    static let description = IntentDescription("Deletes a workout plan.")
    static let supportedModes: IntentModes = .foreground(.dynamic)
    static var parameterSummary: some ParameterSummary {
        Summary("Delete \(\.$workoutPlan)")
    }

    @Parameter(title: "Workout Plan", requestValueDialog: IntentDialog("Which workout plan would you like to delete?"))
    var workoutPlan: WorkoutPlanEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedModelContainer.container.mainContext

        let workoutPlanID = workoutPlan.id
        let predicate = #Predicate<WorkoutPlan> { $0.id == workoutPlanID }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1

        guard let storedPlan = try context.fetch(descriptor).first else {
            throw DeleteWorkoutPlanIntentError.workoutPlanNotFound
        }
        guard storedPlan.completed else {
            throw DeleteWorkoutPlanIntentError.workoutPlanIncomplete
        }

        let choice = try await requestChoice(
            between: [IntentChoiceOption(title: "Delete Workout Plan", style: .destructive), .cancel],
            dialog: IntentDialog("Delete \"\(storedPlan.title)\"? This action cannot be undone.")
        )

        guard choice.style == .destructive else {
            throw DeleteWorkoutPlanIntentError.cancelled
        }

        SpotlightIndexer.deleteWorkoutPlan(id: storedPlan.id)
        context.delete(storedPlan)
        saveContext(context: context)
        return .result(dialog: "Workout plan deleted.")
    }
}

enum DeleteWorkoutPlanIntentError: Error, CustomLocalizedStringResourceConvertible {
    case workoutPlanNotFound
    case workoutPlanIncomplete
    case cancelled

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .workoutPlanNotFound:
            return "That workout plan is no longer available."
        case .workoutPlanIncomplete:
            return "Only completed workout plans can be deleted."
        case .cancelled:
            return "Delete workout plan canceled."
        }
    }
}

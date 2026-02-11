import AppIntents
import SwiftData

struct ToggleWorkoutPlanFavoriteIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Workout Plan Favorite"
    static let description = IntentDescription("Toggles favorite status for a workout plan.")
    static let supportedModes: IntentModes = .foreground(.dynamic)
    static var parameterSummary: some ParameterSummary {
        Summary("Toggle favorite for \(\.$workoutPlan)")
    }

    @Parameter(title: "Workout Plan", requestValueDialog: IntentDialog("Which workout plan would you like to update?"))
    var workoutPlan: WorkoutPlanEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedModelContainer.container.mainContext

        let workoutPlanID = workoutPlan.id
        let predicate = #Predicate<WorkoutPlan> { $0.id == workoutPlanID }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1

        guard let storedPlan = try context.fetch(descriptor).first else {
            throw ToggleWorkoutPlanFavoriteIntentError.workoutPlanNotFound
        }
        guard storedPlan.completed else {
            throw ToggleWorkoutPlanFavoriteIntentError.workoutPlanIncomplete
        }

        let willBeFavorite = !storedPlan.favorite
        storedPlan.favorite = willBeFavorite
        saveContext(context: context)
        if willBeFavorite {
            return .result(dialog: "Workout plan marked as favorite.")
        } else {
            return .result(dialog: "Workout plan removed from favorites.")
        }
    }
}

enum ToggleWorkoutPlanFavoriteIntentError: Error, CustomLocalizedStringResourceConvertible {
    case workoutPlanNotFound
    case workoutPlanIncomplete

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .workoutPlanNotFound:
            return "That workout plan is no longer available."
        case .workoutPlanIncomplete:
            return "Only completed workout plans can be favorited."
        }
    }
}

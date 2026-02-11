import AppIntents
import SwiftData

struct ToggleExerciseFavoriteIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Exercise Favorite"
    static let description = IntentDescription("Toggles favorite status for an exercise.")
    static let supportedModes: IntentModes = .foreground(.dynamic)
    static var parameterSummary: some ParameterSummary {
        Summary("Toggle favorite for \(\.$exercise)")
    }

    @Parameter(title: "Exercise", requestValueDialog: IntentDialog("Which exercise would you like to update?"))
    var exercise: ExerciseEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedModelContainer.container.mainContext

        let catalogID = exercise.id
        let predicate = #Predicate<Exercise> { $0.catalogID == catalogID }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1

        guard let storedExercise = try context.fetch(descriptor).first else {
            throw ToggleExerciseFavoriteIntentError.exerciseNotFound
        }

        storedExercise.toggleFavorite()
        if storedExercise.favorite {
            SpotlightIndexer.index(exercise: storedExercise)
        }
        saveContext(context: context)

        if storedExercise.favorite {
            return .result(dialog: "Exercise marked as favorite.")
        } else {
            return .result(dialog: "Exercise removed from favorites.")
        }
    }
}

enum ToggleExerciseFavoriteIntentError: Error, CustomLocalizedStringResourceConvertible {
    case exerciseNotFound

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .exerciseNotFound:
            return "That exercise is no longer available."
        }
    }
}

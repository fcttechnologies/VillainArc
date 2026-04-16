import AppIntents
import SwiftData

struct OpenExerciseIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Exercise"
    static let description = IntentDescription("Opens progress and history for a specific exercise.")
    static let supportedModes: IntentModes = .foreground(.dynamic)
    static var parameterSummary: some ParameterSummary { Summary("Open \(\.$exercise)") }

    @Parameter(title: "Exercise", requestValueDialog: IntentDialog("Which exercise would you like to open?")) var exercise: ExerciseEntity

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        let context = SharedModelContainer.container.mainContext
        try SetupGuard.requireReady(context: context)

        let catalogID = exercise.id
        guard let storedExercise = try context.fetch(Exercise.withCatalogID(catalogID)).first else { throw OpenExerciseError.exerciseNotFound }

        AppRouter.shared.collapseActiveFlowPresentations()
        AppRouter.shared.popToRoot()
        AppRouter.shared.navigate(to: .exerciseDetail(storedExercise.catalogID))
        return .result(opensIntent: OpenAppIntent())
    }
}

enum OpenExerciseError: Error, CustomLocalizedStringResourceConvertible {
    case exerciseNotFound

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .exerciseNotFound: return "That exercise is no longer available."
        }
    }
}

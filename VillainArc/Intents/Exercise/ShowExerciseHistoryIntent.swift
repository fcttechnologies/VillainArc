import AppIntents
import SwiftData

struct ShowExerciseHistoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Exercise History"
    static let description = IntentDescription("Shows completed performance history for a specific exercise.")
    static let supportedModes: IntentModes = .foreground(.dynamic)
    static var parameterSummary: some ParameterSummary { Summary("Show history for \(\.$exercise)") }

    @Parameter(title: "Exercise", requestValueDialog: IntentDialog("Which exercise history would you like to open?")) var exercise: ExerciseEntity

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        let context = SharedModelContainer.container.mainContext
        try SetupGuard.requireReady(context: context)

        let catalogID = exercise.id
        guard let storedExercise = try context.fetch(Exercise.withCatalogID(catalogID)).first else { throw ShowExerciseHistoryError.exerciseNotFound }
        guard (try? context.fetch(ExerciseHistory.forCatalogID(catalogID)).first) != nil else { throw ShowExerciseHistoryError.noExerciseHistoryFound }

        var descriptor = ExercisePerformance.matching(catalogID: catalogID)
        descriptor.fetchLimit = 1
        guard (try? context.fetch(descriptor).first) != nil else { throw ShowExerciseHistoryError.noExerciseHistoryFound }

        AppRouter.shared.collapseActiveFlowPresentations()
        AppRouter.shared.popToRoot()
        AppRouter.shared.navigate(to: .exerciseHistory(storedExercise.catalogID))
        return .result(opensIntent: OpenAppIntent())
    }
}

enum ShowExerciseHistoryError: Error, CustomLocalizedStringResourceConvertible {
    case exerciseNotFound
    case noExerciseHistoryFound

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .exerciseNotFound: return "That exercise is no longer available."
        case .noExerciseHistoryFound: return "Complete this exercise in a workout before opening its history."
        }
    }
}

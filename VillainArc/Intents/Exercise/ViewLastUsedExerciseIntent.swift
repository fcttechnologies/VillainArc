import AppIntents
import SwiftData

struct ViewLastUsedExerciseIntent: AppIntent {
    static let title: LocalizedStringResource = "View Last Used Exercise"
    static let description = IntentDescription("Shows the most recently used exercise that has recorded history.")
    static let supportedModes: IntentModes = .foreground(.dynamic)

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        let context = SharedModelContainer.container.mainContext
        try SetupGuard.requireReadyAndNoActiveFlow(context: context)

        guard let history = try context.fetch(ExerciseHistory.recentCompleted(limit: 1)).first else { throw ViewLastUsedExerciseError.noExerciseHistoryFound }

        let storedExercise = try context.fetch(Exercise.withCatalogID(history.catalogID)).first
        guard let storedExercise else { throw ViewLastUsedExerciseError.noExerciseHistoryFound }

        AppRouter.shared.popToRoot()
        AppRouter.shared.navigate(to: .exerciseDetail(storedExercise.catalogID))
        return .result(opensIntent: OpenAppIntent())
    }
}

enum ViewLastUsedExerciseError: Error, CustomLocalizedStringResourceConvertible {
    case noExerciseHistoryFound

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noExerciseHistoryFound: return "You haven't completed any exercises with tracked history yet."
        }
    }
}

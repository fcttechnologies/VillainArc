import AppIntents
import SwiftData

struct ViewLastUsedExerciseIntent: AppIntent {
    static let title: LocalizedStringResource = "View Last Used Exercise"
    static let description = IntentDescription("Shows the most recently used exercise that has recorded history.")
    static let supportedModes: IntentModes = .foreground(.dynamic)

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        let context = SharedModelContainer.container.mainContext
        try SetupGuard.requireReadyAndNoActiveFlow(context: context)

        let histories = (try? context.fetch(FetchDescriptor<ExerciseHistory>())) ?? []
        let historyCatalogIDs = Set(histories.map(\.catalogID))
        guard !historyCatalogIDs.isEmpty else {
            throw ViewLastUsedExerciseError.noExerciseHistoryFound
        }

        let exercises = try context.fetch(Exercise.all)
        let storedExercise = exercises.first(where: { historyCatalogIDs.contains($0.catalogID) })
        guard let storedExercise else {
            throw ViewLastUsedExerciseError.noExerciseHistoryFound
        }

        AppRouter.shared.popToRoot()
        AppRouter.shared.navigate(to: .exerciseDetail(storedExercise.catalogID))
        return .result(opensIntent: OpenAppIntent())
    }
}

enum ViewLastUsedExerciseError: Error, CustomLocalizedStringResourceConvertible {
    case noExerciseHistoryFound

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noExerciseHistoryFound:
            return "You haven't completed any exercises with tracked history yet."
        }
    }
}

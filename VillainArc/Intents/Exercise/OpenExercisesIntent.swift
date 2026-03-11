import AppIntents
import SwiftData

struct OpenExercisesIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Exercises"
    static let description = IntentDescription("Opens your exercises list.")
    static let supportedModes: IntentModes = .foreground

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        let context = SharedModelContainer.container.mainContext
        try SetupGuard.requireReadyAndNoActiveFlow(context: context)

        var descriptor = Exercise.all
        descriptor.fetchLimit = 1
        guard (try? context.fetch(descriptor).first) != nil else {
            throw OpenExercisesError.noExercisesAvailable
        }

        AppRouter.shared.popToRoot()
        AppRouter.shared.navigate(to: .exercisesList)
        return .result(opensIntent: OpenAppIntent())
    }
}

enum OpenExercisesError: Error, CustomLocalizedStringResourceConvertible {
    case noExercisesAvailable

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noExercisesAvailable:
            return "No exercises are available yet."
        }
    }
}

import AppIntents
import SwiftData

struct OpenActiveCardioSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Active Cardio Session"
    static let description = IntentDescription("Opens your in-progress cardio session.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        let context = SharedModelContainer.container.mainContext
        try SetupGuard.requireReady(context: context)

        guard AppRouter.shared.activeCardioSession != nil || ((try? context.fetch(CardioSession.incomplete).first) != nil) else {
            throw OpenActiveCardioSessionError.noActiveCardio
        }

        AppRouter.shared.presentActiveCardioSessionIfPossible()
        return .result(opensIntent: OpenAppIntent())
    }
}

enum OpenActiveCardioSessionError: Error, CustomLocalizedStringResourceConvertible {
    case noActiveCardio

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noActiveCardio: return "You don't have an active cardio session."
        }
    }
}

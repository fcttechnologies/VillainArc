import AppIntents
import SwiftData

struct CancelCardioSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Cancel Cardio Session"
    static let description = IntentDescription("Cancels and deletes the current cardio session.")
    static let supportedModes: IntentModes = .background

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedModelContainer.container.mainContext
        guard let cardioSession = try? context.fetch(CardioSession.incomplete).first else {
            return .result(dialog: "No current cardio session to cancel.")
        }

        AppRouter.shared.cancelCardioSession(cardioSession)

        return .result(dialog: "Cardio session cancelled.")
    }
}

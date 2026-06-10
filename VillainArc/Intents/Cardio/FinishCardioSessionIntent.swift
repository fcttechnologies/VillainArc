import AppIntents
import SwiftData

struct FinishCardioSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Finish Cardio Session"
    static let description = IntentDescription("Finishes and saves the current cardio session, including any route or Health data captured.")
    static let supportedModes: IntentModes = .background

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedModelContainer.container.mainContext
        guard let cardioSession = try? context.fetch(CardioSession.incomplete).first else {
            return .result(dialog: "No current cardio session to finish.")
        }

        AppRouter.shared.finishCardioSession(cardioSession)

        return .result(dialog: "Cardio session finished.")
    }
}

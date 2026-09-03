import AppIntents
import FCTMetrics
import SwiftData

struct FinishCardioSessionIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentFinishCardioSession

    static let title: LocalizedStringResource = "Finish Cardio Session"
    static let description = IntentDescription("Finishes and saves the current cardio session, including any route or Health data captured.")
    static let supportedModes: IntentModes = .background

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        Diag.breadcrumb(Self.diagCrumb)
        let context = SharedModelContainer.container.mainContext
        guard let cardioSession = try? context.fetch(CardioSession.incomplete).first else {
            return .result(dialog: "No current cardio session to finish.")
        }

        AppRouter.shared.finishCardioSession(cardioSession)

        return .result(dialog: "Cardio session finished.")
    }
}

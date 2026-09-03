import AppIntents
import FCTMetrics
import SwiftData

struct CancelCardioSessionIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentCancelCardioSession

    static let title: LocalizedStringResource = "Cancel Cardio Session"
    static let description = IntentDescription("Cancels and deletes the current cardio session.")
    static let supportedModes: IntentModes = .background

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        Diag.breadcrumb(Self.diagCrumb)
        let context = SharedModelContainer.container.mainContext
        guard let cardioSession = try? context.fetch(CardioSession.incomplete).first else {
            return .result(dialog: "No current cardio session to cancel.")
        }

        AppRouter.shared.cancelCardioSession(cardioSession)

        return .result(dialog: "Cardio session cancelled.")
    }
}

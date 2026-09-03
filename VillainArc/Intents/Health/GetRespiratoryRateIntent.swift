import AppIntents
import FCTMetrics
import SwiftData

struct GetRespiratoryRateIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentGetRespiratoryRate

    static let title: LocalizedStringResource = "Get Respiratory Rate"
    static let description = IntentDescription("Tells you your respiratory rate range for today.")
    static let supportedModes: IntentModes = .background

    nonisolated func perform() async throws -> some IntentResult & ProvidesDialog {
        Diag.breadcrumb(Self.diagCrumb)
        let context = makeHealthIntentReadContext()
        return .result(dialog: IntentDialog(stringLiteral: try respiratoryRateDialog(for: .now, context: context)))
    }
}

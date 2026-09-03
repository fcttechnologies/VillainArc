import AppIntents
import FCTMetrics
import SwiftData

struct GetHydrationIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentGetHydration

    static let title: LocalizedStringResource = "Get Hydration"
    static let description = IntentDescription("Tells you how much water you've had today.")
    static let supportedModes: IntentModes = .background

    nonisolated func perform() async throws -> some IntentResult & ProvidesDialog {
        Diag.breadcrumb(Self.diagCrumb)
        let context = makeHealthIntentReadContext()
        return .result(dialog: IntentDialog(stringLiteral: try hydrationDialog(for: .now, context: context)))
    }
}

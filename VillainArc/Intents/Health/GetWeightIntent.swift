import AppIntents
import FCTMetrics
import SwiftData

struct GetWeightIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentGetWeight

    static let title: LocalizedStringResource = "Get Weight"
    static let description = IntentDescription("Tells you your latest logged weight for today.")
    static let supportedModes: IntentModes = .background

    nonisolated func perform() async throws -> some IntentResult & ProvidesDialog {
        Diag.breadcrumb(Self.diagCrumb)
        let context = makeHealthIntentReadContext()
        let snapshot = try loadHealthDaySnapshot(for: .now, context: context)
        return .result(dialog: IntentDialog(stringLiteral: healthMetricDialog(for: .weight, snapshot: snapshot)))
    }
}

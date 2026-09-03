import AppIntents
import FCTMetrics
import SwiftData

struct GetHealthDaySummaryIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentGetHealthDaySummary

    static let title: LocalizedStringResource = "Get Health Day Summary"
    static let description = IntentDescription("Summarizes your health metrics for today.")
    static let supportedModes: IntentModes = .background

    nonisolated func perform() async throws -> some IntentResult & ProvidesDialog {
        func run() async throws -> some IntentResult & ProvidesDialog {
            let context = makeHealthIntentReadContext()
            let snapshot = try loadHealthDaySnapshot(for: .now, context: context)
            return .result(dialog: IntentDialog(stringLiteral: healthDaySummaryDialog(for: snapshot)))
        }
        return try await Diag.intent(Self.diagCrumb, run)
    }
}

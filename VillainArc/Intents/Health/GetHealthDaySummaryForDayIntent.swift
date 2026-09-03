import AppIntents
import FCTMetrics
import SwiftData

struct GetHealthDaySummaryForDayIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentGetHealthDaySummaryForDay

    static let title: LocalizedStringResource = "Get Health Day Summary For Day"
    static let description = IntentDescription("Summarizes your health metrics for a specific day.")
    static let supportedModes: IntentModes = .background

    static var parameterSummary: some ParameterSummary {
        Summary("Get my health summary for \(\.$date)")
    }

    @Parameter(title: "Date") var date: Date

    nonisolated func perform() async throws -> some IntentResult & ProvidesDialog {
        Diag.breadcrumb(Self.diagCrumb)
        let context = makeHealthIntentReadContext()
        let snapshot = try loadHealthDaySnapshot(for: date, context: context)
        return .result(dialog: IntentDialog(stringLiteral: healthDaySummaryDialog(for: snapshot)))
    }
}

import AppIntents
import FCTMetrics
import SwiftData

struct GetHealthMetricForDayIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentGetHealthMetricForDay

    static let title: LocalizedStringResource = "Get Health Metric For Day"
    static let description = IntentDescription("Tells you a health metric for a specific day.")
    static let supportedModes: IntentModes = .background

    static var parameterSummary: some ParameterSummary {
        Summary("Get \(\.$metric) for \(\.$date)")
    }

    @Parameter(title: "Metric") var metric: HealthMetric
    @Parameter(title: "Date") var date: Date

    nonisolated func perform() async throws -> some IntentResult & ProvidesDialog {
        func run() async throws -> some IntentResult & ProvidesDialog {
            let context = makeHealthIntentReadContext()
            let snapshot = try loadHealthDaySnapshot(for: date, context: context)
            return .result(dialog: IntentDialog(stringLiteral: healthMetricDialog(for: metric, snapshot: snapshot)))
        }
        return try await Diag.intent(Self.diagCrumb, run)
    }
}

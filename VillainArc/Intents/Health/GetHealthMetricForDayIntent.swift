import AppIntents
import SwiftData

struct GetHealthMetricForDayIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Health Metric For Day"
    static let description = IntentDescription("Tells you a health metric for a specific day.")
    static let supportedModes: IntentModes = .background

    static var parameterSummary: some ParameterSummary {
        Summary("Get \(\.$metric) for \(\.$date)")
    }

    @Parameter(title: "Metric") var metric: HealthMetric
    @Parameter(title: "Date") var date: Date

    nonisolated func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = makeHealthIntentReadContext()
        let snapshot = try loadHealthDaySnapshot(for: date, context: context)
        return .result(dialog: IntentDialog(stringLiteral: healthMetricDialog(for: metric, snapshot: snapshot)))
    }
}

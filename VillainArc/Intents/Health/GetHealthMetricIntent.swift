import AppIntents
import SwiftData

struct GetHealthMetricIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Health Metric"
    static let description = IntentDescription("Tells you a health metric for today.")
    static let supportedModes: IntentModes = .background

    static var parameterSummary: some ParameterSummary {
        Summary("Get \(\.$metric)")
    }

    @Parameter(title: "Metric") var metric: HealthMetric

    nonisolated func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = makeHealthIntentReadContext()
        let snapshot = try loadHealthDaySnapshot(for: .now, context: context)
        return .result(dialog: IntentDialog(stringLiteral: healthMetricDialog(for: metric, snapshot: snapshot)))
    }
}

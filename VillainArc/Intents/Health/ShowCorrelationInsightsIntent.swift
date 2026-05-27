import AppIntents

struct ShowCorrelationInsightsIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Performance Correlations"
    static let description = IntentDescription("Opens the correlation between your sleep, RPE, and session quality.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        try openHealthDestination(.correlationInsights)
        return .result(opensIntent: OpenAppIntent())
    }
}

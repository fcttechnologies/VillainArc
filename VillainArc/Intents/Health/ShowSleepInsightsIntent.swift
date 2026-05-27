import AppIntents

struct ShowSleepInsightsIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Sleep Insights"
    static let description = IntentDescription("Opens your sleep timing patterns and consistency score.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        try openHealthDestination(.sleepTimingInsights)
        return .result(opensIntent: OpenAppIntent())
    }
}

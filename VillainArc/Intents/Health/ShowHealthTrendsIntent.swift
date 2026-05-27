import AppIntents

struct ShowHealthTrendsIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Health Trends"
    static let description = IntentDescription("Opens trend views for your key health metrics.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        try openHealthDestination(.healthTrends)
        return .result(opensIntent: OpenAppIntent())
    }
}

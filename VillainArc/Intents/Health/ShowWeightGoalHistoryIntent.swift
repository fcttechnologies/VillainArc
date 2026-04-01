import AppIntents

struct ShowWeightGoalHistoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Weight Goal History"
    static let description = IntentDescription("Opens your weight goal history.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        try openHealthDestination(.weightGoalHistory)
        return .result(opensIntent: OpenAppIntent())
    }
}

import AppIntents

struct ShowSleepGoalHistoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Sleep Goal History"
    static let description = IntentDescription("Opens your sleep goal history.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        try openHealthDestination(.sleepGoalHistory)
        return .result(opensIntent: OpenAppIntent())
    }
}

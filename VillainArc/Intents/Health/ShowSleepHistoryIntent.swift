import AppIntents

struct ShowSleepHistoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Sleep History"
    static let description = IntentDescription("Opens your sleep history.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        try openHealthDestination(.sleepHistory)
        return .result(opensIntent: OpenAppIntent())
    }
}

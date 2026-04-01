import AppIntents

struct ShowWeightHistoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Weight History"
    static let description = IntentDescription("Opens your weight history.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        try openHealthDestination(.weightHistory)
        return .result(opensIntent: OpenAppIntent())
    }
}

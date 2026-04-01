import AppIntents

struct ShowStepsHistoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Steps History"
    static let description = IntentDescription("Opens your steps and distance history.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        try openHealthDestination(.stepsDistanceHistory)
        return .result(opensIntent: OpenAppIntent())
    }
}

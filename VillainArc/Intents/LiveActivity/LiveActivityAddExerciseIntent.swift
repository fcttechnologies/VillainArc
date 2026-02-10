import AppIntents

struct LiveActivityAddExerciseIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Add Exercise"
    static let isDiscoverable: Bool = false
    static let supportedModes: IntentModes = .foreground(.immediate)

    @MainActor
    func perform() async throws -> some IntentResult {
        AppRouter.shared.showAddExerciseFromLiveActivity = true
        return .result()
    }
}

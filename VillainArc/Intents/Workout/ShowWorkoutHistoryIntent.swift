import AppIntents

struct ShowWorkoutHistoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Workout History"
    static let description = IntentDescription("Opens your workout history.")
    static let supportedModes: IntentModes = .foreground

    @MainActor
    func perform() async throws -> some IntentResult {
        AppRouter.shared.popToRoot()
        AppRouter.shared.navigate(to: .workoutsList)
        return .result()
    }
}

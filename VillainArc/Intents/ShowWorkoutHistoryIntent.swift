import AppIntents

struct ShowWorkoutHistoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Workout History"
    static let description = IntentDescription("Opens your workout history.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        AppRouter.shared.navigate(to: .workoutsList)
        return .result(opensIntent: OpenAppIntent())
    }
}

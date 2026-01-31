import AppIntents

struct ShowWorkoutPlansIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Workout Plans"
    static let description = IntentDescription("Opens your workout plans list.")
    static let supportedModes: IntentModes = .foreground

    @MainActor
    func perform() async throws -> some IntentResult {
        AppRouter.shared.popToRoot()
        AppRouter.shared.navigate(to: .workoutPlansList)
        return .result()
    }
}

import AppIntents

extension Notification.Name {
    static let workoutStartedFromIntent = Notification.Name("workoutStartedFromIntent")
}

struct StartWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Workout"
    static let description = IntentDescription("Starts a new workout or resumes the current one.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // Just notify the app - ContentView will handle starting/resuming
        NotificationCenter.default.post(name: .workoutStartedFromIntent, object: nil)
        return .result()
    }
}

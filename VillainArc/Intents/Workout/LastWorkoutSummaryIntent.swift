import AppIntents
import SwiftData

struct LastWorkoutSummaryIntent: AppIntent {
    static let title: LocalizedStringResource = "Last Workout Summary"
    static let description = IntentDescription("Tells you about your last workout session.")
    static let supportedModes: IntentModes = .background

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedModelContainer.container.mainContext
        
        guard let lastWorkoutSession = try context.fetch(WorkoutSession.recent).first else {
            return .result(dialog: "You haven't completed a workout.")
        }
        
        let exercisesList = lastWorkoutSession.exerciseSummary
        
        return .result(dialog: "In your last workout, you did \(exercisesList).")
    }
}

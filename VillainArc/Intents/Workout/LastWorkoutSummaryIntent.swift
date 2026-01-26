import AppIntents
import SwiftData

struct LastWorkoutSummaryIntent: AppIntent {
    static let title: LocalizedStringResource = "Last Workout Summary"
    static let description = IntentDescription("Tells you about your last workout.")
    static let supportedModes: IntentModes = .background

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedModelContainer.container.mainContext
        
        guard let lastWorkout = try context.fetch(Workout.recentWorkout).first else {
            return .result(dialog: "You haven't completed a workout.")
        }
        
        let exercisesList = lastWorkout.exerciseSummary
        
        return .result(dialog: "In your last workout, you did \(exercisesList).")
    }
}

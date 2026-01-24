import AppIntents
import SwiftData

struct LastWorkoutSummaryIntent: AppIntent {
    static let title: LocalizedStringResource = "Last Workout Summary"
    static let description = IntentDescription("Tells you about your last workout.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContext(SharedModelContainer.container)
        
        guard let lastWorkout = try context.fetch(Workout.recentWorkout).first else {
            return .result(dialog: "You haven't completed a workout.")
        }
        
        let exercises = lastWorkout.sortedExercises
        let exerciseSummaries = exercises.map { exercise in
            let setCount = exercise.sets.count
            let setWord = setCount == 1 ? "set" : "sets"
            return "\(setCount) \(setWord) of \(exercise.name)"
        }
        let exercisesList = ListFormatter.localizedString(byJoining: exerciseSummaries)
        
        return .result(dialog: "In your last workout, you did \(exercisesList).")
    }
}

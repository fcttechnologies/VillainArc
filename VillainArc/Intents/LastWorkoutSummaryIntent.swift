import AppIntents
import SwiftData

struct LastWorkoutSummaryIntent: AppIntent {
    static let title: LocalizedStringResource = "Last Workout Summary"
    static let description = IntentDescription("Tells you when your last workout was.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContext(SharedModelContainer.container)
        
        guard let lastWorkout = try context.fetch(Workout.recentWorkout).first,
              let endTime = lastWorkout.endTime else {
            return .result(dialog: "You don't have any completed workouts yet.")
        }
        
        let daysAgo = Calendar.current.dateComponents([.day], from: endTime, to: Date()).day ?? 0
        let timeAgoText: String
        
        switch daysAgo {
        case 0:
            timeAgoText = "today"
        case 1:
            timeAgoText = "yesterday"
        default:
            timeAgoText = "\(daysAgo) days ago"
        }
        
        return .result(dialog: "Your last workout was \(timeAgoText): \(lastWorkout.title)")
    }
}

import AppIntents
import SwiftData

struct ViewLastWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "View Last Workout"
    static let description = IntentDescription("Shows your most recent completed workout.")
    static let supportedModes: IntentModes = .foreground(.dynamic)

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        let context = SharedModelContainer.container.mainContext
        
        guard let lastWorkout = try context.fetch(Workout.recentWorkout).first else {
            throw ViewLastWorkoutError.noWorkoutsFound
        }
        
        AppRouter.shared.popToRoot()
        AppRouter.shared.navigate(to: .workoutDetail(lastWorkout))
        return .result(opensIntent: OpenAppIntent())
    }
}

enum ViewLastWorkoutError: Error, CustomLocalizedStringResourceConvertible {
    case noWorkoutsFound
    
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noWorkoutsFound:
            return "You haven't completed a workout."
        }
    }
}

import AppIntents
import SwiftData

struct ViewLastWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "View Last Workout"
    static let description = IntentDescription("Shows your most recent completed workout.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        let context = ModelContext(SharedModelContainer.container)
        
        guard let lastWorkout = try context.fetch(Workout.recentWorkout).first else {
            throw ViewLastWorkoutError.noWorkoutsFound
        }
        
        AppRouter.shared.navigate(to: .workoutDetail(lastWorkout))
        
        // Open the app after setting up navigation
        return .result(opensIntent: OpenAppIntent())
    }
}

struct OpenAppIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Villain Arc"
    static var openAppWhenRun = true
    
    func perform() async throws -> some IntentResult {
        return .result()
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

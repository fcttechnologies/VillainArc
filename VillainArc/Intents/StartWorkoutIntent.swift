import AppIntents
import SwiftData

struct StartWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Workout"
    static let description = IntentDescription("Starts a new workout or resumes the current one.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
//        let context = ModelContext(SharedModelContainer.container)
//        if let _ = try? context.fetch(WorkoutTemplate.incomplete).first {
//            throw StartWorkoutError.templateIsActive
//        }
//        if let workout = try? context.fetch(Workout.incomplete).first {
//            AppRouter.shared.resumeWorkout(workout)
//        } else {
//            AppRouter.shared.startWorkout(context: context)
//        }
        return .result(opensIntent: OpenAppIntent())
    }
}

enum StartWorkoutError: Error, CustomLocalizedStringResourceConvertible {
    case templateIsActive
    
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .templateIsActive:
            return "You are currently creating a template. Finish that first."
        }
    }
}

import AppIntents
import SwiftData

struct OpenWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Workout"
    static let description = IntentDescription("Opens a specific workout.")
    static let supportedModes: IntentModes = .foreground(.dynamic)
    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$workout)")
    }

    @Parameter(title: "Workout", requestValueDialog: IntentDialog("Which workout would you like to open?"))
    var workout: WorkoutSessionEntity

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        let context = SharedModelContainer.container.mainContext
        if let _ = try? context.fetch(WorkoutPlan.incomplete).first {
            throw StartWorkoutError.workoutPlanIsActive
        }
        if let _ = try? context.fetch(WorkoutSession.incomplete).first {
            throw StartWorkoutError.workoutIsActive
        }

        let workoutID = workout.id
        let predicate = #Predicate<WorkoutSession> { $0.id == workoutID }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        guard let storedWorkout = try context.fetch(descriptor).first else {
            throw OpenWorkoutError.workoutNotFound
        }
        guard storedWorkout.status == SessionStatus.done.rawValue else {
            throw OpenWorkoutError.workoutIncomplete
        }

        AppRouter.shared.popToRoot()
        AppRouter.shared.navigate(to: .workoutSessionDetail(storedWorkout))
        return .result(opensIntent: OpenAppIntent())
    }
}

enum OpenWorkoutError: Error, CustomLocalizedStringResourceConvertible {
    case workoutNotFound
    case workoutIncomplete

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .workoutNotFound:
            return "That workout is no longer available."
        case .workoutIncomplete:
            return "Finish the workout before opening its details."
        }
    }
}

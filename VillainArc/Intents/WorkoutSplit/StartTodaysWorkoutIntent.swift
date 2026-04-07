import AppIntents
import SwiftData

struct StartTodaysWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Today's Workout"
    static let description = IntentDescription("Starts today's workout from your active split.")
    static let supportedModes: IntentModes = .foreground(.dynamic)

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        let context = SharedModelContainer.container.mainContext
        try SetupGuard.requireReady(context: context)
        guard let split = try? context.fetch(WorkoutSplit.active).first else { throw StartTodaysWorkoutError.noActiveSplit }
        guard !(split.days?.isEmpty ?? true) else { throw StartTodaysWorkoutError.noDaysInSplit }

        if (try? context.fetch(WorkoutPlan.incomplete).first) != nil { throw StartWorkoutError.workoutPlanIsActive }
        if (try? context.fetch(WorkoutSession.incomplete).first) != nil { throw StartWorkoutError.workoutIsActive }

        let resolution = SplitScheduleResolver.resolve(split, context: context)
        guard let todaysDay = resolution.splitDay else { throw StartTodaysWorkoutError.noDayForToday }
        guard !resolution.isPaused else { throw StartTodaysWorkoutError.trainingIsPaused }
        guard !todaysDay.isRestDay else { throw StartTodaysWorkoutError.todayIsRestDay }
        guard let workoutPlan = resolution.workoutPlan else { throw StartTodaysWorkoutError.noWorkoutPlanForToday }

        AppRouter.shared.startWorkoutSession(from: workoutPlan)
        return .result(opensIntent: OpenAppIntent())
    }
}

enum StartTodaysWorkoutError: Error, CustomLocalizedStringResourceConvertible {
    case noActiveSplit
    case noDaysInSplit
    case noDayForToday
    case trainingIsPaused
    case todayIsRestDay
    case noWorkoutPlanForToday

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noActiveSplit: return "You don't have an active workout split."
        case .noDaysInSplit: return "Your split doesn't have any days set up yet."
        case .noDayForToday: return "Couldn't determine today's workout."
        case .trainingIsPaused: return "Training is currently paused because of your active condition."
        case .todayIsRestDay: return "Today is a rest day! Enjoy your recovery."
        case .noWorkoutPlanForToday: return "You don't have a workout plan assigned for today."
        }
    }
}

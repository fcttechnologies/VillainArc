import AppIntents
import SwiftData

struct OpenTodaysPlanIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Today's Plan"
    static let description = IntentDescription("Opens today's workout plan from your active split.")
    static let supportedModes: IntentModes = .foreground(.dynamic)

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        let context = SharedModelContainer.container.mainContext
        try SetupGuard.requireReady(context: context)

        guard let split = try? context.fetch(WorkoutSplit.active).first else { throw OpenTodaysPlanError.noActiveSplit }
        guard !(split.days?.isEmpty ?? true) else { throw OpenTodaysPlanError.noDaysInSplit }

        let resolution = SplitScheduleResolver.resolve(split, context: context)
        guard let todaysDay = resolution.splitDay else { throw OpenTodaysPlanError.noDayForToday }
        guard !resolution.isPaused else { throw OpenTodaysPlanError.trainingIsPaused }
        guard !todaysDay.isRestDay else { throw OpenTodaysPlanError.todayIsRestDay }
        guard let workoutPlan = resolution.workoutPlan else { throw OpenTodaysPlanError.noWorkoutPlanForToday }

        AppRouter.shared.collapseActiveFlowPresentations()
        AppRouter.shared.popToRoot()
        AppRouter.shared.navigate(to: .workoutPlanDetail(workoutPlan, true))
        return .result(opensIntent: OpenAppIntent())
    }
}

enum OpenTodaysPlanError: Error, CustomLocalizedStringResourceConvertible {
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

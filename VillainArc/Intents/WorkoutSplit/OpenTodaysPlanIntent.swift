import AppIntents
import SwiftData

struct OpenTodaysPlanIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Today's Plan"
    static let description = IntentDescription("Opens today's workout plan from your active split.")
    static let supportedModes: IntentModes = .foreground(.dynamic)

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        let context = SharedModelContainer.container.mainContext
        try SetupGuard.requireReadyAndNoActiveFlow(context: context)

        guard let split = try? context.fetch(WorkoutSplit.active).first else {
            throw OpenTodaysPlanError.noActiveSplit
        }
        guard !(split.days?.isEmpty ?? true) else {
            throw OpenTodaysPlanError.noDaysInSplit
        }

        split.refreshRotationIfNeeded(context: context)

        guard let todaysDay = split.todaysSplitDay else {
            throw OpenTodaysPlanError.noDayForToday
        }
        guard !todaysDay.isRestDay else {
            throw OpenTodaysPlanError.todayIsRestDay
        }
        guard let workoutPlan = todaysDay.workoutPlan else {
            throw OpenTodaysPlanError.noWorkoutPlanForToday
        }

        AppRouter.shared.popToRoot()
        AppRouter.shared.navigate(to: .workoutPlanDetail(workoutPlan, true))
        return .result(opensIntent: OpenAppIntent())
    }
}

enum OpenTodaysPlanError: Error, CustomLocalizedStringResourceConvertible {
    case noActiveSplit
    case noDaysInSplit
    case noDayForToday
    case todayIsRestDay
    case noWorkoutPlanForToday

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noActiveSplit:
            return "You don't have an active workout split."
        case .noDaysInSplit:
            return "Your split doesn't have any days set up yet."
        case .noDayForToday:
            return "Couldn't determine today's workout."
        case .todayIsRestDay:
            return "Today is a rest day! Enjoy your recovery."
        case .noWorkoutPlanForToday:
            return "You don't have a workout plan assigned for today."
        }
    }
}

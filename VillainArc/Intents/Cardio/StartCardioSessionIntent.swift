import AppIntents
import SwiftData

struct StartCardioSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Cardio Session"
    static let description = IntentDescription("Starts a cardio session of the chosen type.")
    static let supportedModes: IntentModes = .foreground(.dynamic)

    @Parameter(title: "Type", description: "Outdoor or treadmill, run or walk.")
    var kind: CardioKindAppEnum

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        let context = SharedModelContainer.container.mainContext
        try SetupGuard.requireReady(context: context)

        if (try? context.fetch(WorkoutSession.incomplete).first) != nil { throw StartCardioSessionError.workoutIsActive }
        if (try? context.fetch(WorkoutPlan.incomplete).first) != nil { throw StartCardioSessionError.workoutPlanIsActive }
        if (try? context.fetch(CardioSession.incomplete).first) != nil { throw StartCardioSessionError.cardioIsActive }

        let sessionKind = kind.sessionKind
        if sessionKind.isOutdoor {
            AppRouter.shared.requestOutdoorCardioSession(kind: sessionKind)
        } else {
            AppRouter.shared.requestManualCardioSession(kind: sessionKind)
        }
        return .result(opensIntent: OpenAppIntent())
    }
}

enum StartCardioSessionError: Error, CustomLocalizedStringResourceConvertible {
    case workoutIsActive
    case workoutPlanIsActive
    case cardioIsActive

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .workoutIsActive: return "Finish your active workout before starting cardio."
        case .workoutPlanIsActive: return "Finish your active plan before starting cardio."
        case .cardioIsActive: return "You already have an active cardio session."
        }
    }
}

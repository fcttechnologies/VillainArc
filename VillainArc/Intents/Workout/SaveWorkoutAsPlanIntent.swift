import AppIntents
import SwiftData

struct SaveWorkoutAsPlanIntent: AppIntent {
    static let title: LocalizedStringResource = "Save Workout as Plan"
    static let description = IntentDescription("Creates a completed workout plan from a completed workout.")
    static let supportedModes: IntentModes = .foreground(.dynamic)
    static var parameterSummary: some ParameterSummary {
        Summary("Save \(\.$workout) as workout plan")
    }

    @Parameter(title: "Workout", requestValueDialog: IntentDialog("Which workout would you like to save as a plan?"))
    var workout: WorkoutSessionEntity

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        let context = SharedModelContainer.container.mainContext

        let workoutID = workout.id
        let predicate = #Predicate<WorkoutSession> { $0.id == workoutID }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1

        guard let storedWorkout = try context.fetch(descriptor).first else {
            throw SaveWorkoutAsPlanError.workoutNotFound
        }
        // First validation: don't create duplicates when the workout is already linked.
        guard storedWorkout.workoutPlan == nil else {
            throw SaveWorkoutAsPlanError.workoutAlreadyHasPlan
        }
        guard storedWorkout.status == SessionStatus.done.rawValue else {
            throw SaveWorkoutAsPlanError.workoutIncomplete
        }

        let plan = WorkoutPlan(from: storedWorkout, completed: true)
        context.insert(plan)
        storedWorkout.workoutPlan = plan
        saveContext(context: context)
        SpotlightIndexer.index(workoutPlan: plan)

        AppRouter.shared.popToRoot()
        AppRouter.shared.navigate(to: .workoutPlanDetail(plan, false))
        return .result(opensIntent: OpenAppIntent())
    }
}

enum SaveWorkoutAsPlanError: Error, CustomLocalizedStringResourceConvertible {
    case workoutNotFound
    case workoutAlreadyHasPlan
    case workoutIncomplete

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .workoutNotFound:
            return "That workout is no longer available."
        case .workoutAlreadyHasPlan:
            return "This workout is already linked to a workout plan."
        case .workoutIncomplete:
            return "Finish the workout before saving it as a plan."
        }
    }
}

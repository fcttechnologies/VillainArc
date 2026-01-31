import AppIntents
import SwiftData

struct StartWorkoutWithPlanIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Workout with Plan"
    static let description = IntentDescription("Starts a workout session from a workout plan.")
    static let supportedModes: IntentModes = .foreground(.dynamic)
    static var parameterSummary: some ParameterSummary {
        Summary("Start workout session with \(\.$workoutPlan)")
    }

    @Parameter(title: "Template", requestValueDialog: IntentDialog("Which template?"))
    var workoutPlan: WorkoutPlanEntity

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        let context = SharedModelContainer.container.mainContext
        if let _ = try? context.fetch(WorkoutPlan.incomplete).first {
            throw StartWorkoutError.workoutPlanIsActive
        }
        if let _ = try? context.fetch(WorkoutSession.incomplete).first {
            throw StartWorkoutError.workoutIsActive
        }
        let workoutPlanID = workoutPlan.id
        let predicate = #Predicate<WorkoutPlan> { $0.id == workoutPlanID }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        guard let storedPlan = try context.fetch(descriptor).first else {
            throw StartWorkoutWithPlanError.workoutPlanNotFound
        }
        guard storedPlan.completed else {
            throw StartWorkoutWithPlanError.workoutPlanIncomplete
        }
        AppRouter.shared.startWorkoutSession(from: storedPlan)
        return .result(opensIntent: OpenAppIntent())
    }
}

enum StartWorkoutWithPlanError: Error, CustomLocalizedStringResourceConvertible {
    case workoutPlanNotFound
    case workoutPlanIncomplete

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .workoutPlanNotFound:
            return "That workout plan is no longer available."
        case .workoutPlanIncomplete:
            return "Finish creating the workout plan before starting a workout from it."
        }
    }
}

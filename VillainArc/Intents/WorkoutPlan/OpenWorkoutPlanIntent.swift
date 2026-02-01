import AppIntents
import SwiftData

struct OpenWorkoutPlanIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Workout Plan"
    static let description = IntentDescription("Opens a specific workout plan.")
    static let supportedModes: IntentModes = .foreground(.dynamic)
    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$workoutPlan)")
    }

    @Parameter(title: "Workout Plan", requestValueDialog: IntentDialog("Which workout plan would you like to open?"))
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
            throw OpenWorkoutPlanError.workoutPlanNotFound
        }
        guard storedPlan.completed else {
            throw OpenWorkoutPlanError.workoutPlanIncomplete
        }

        AppRouter.shared.popToRoot()
        AppRouter.shared.navigate(to: .workoutPlanDetail(storedPlan))
        return .result(opensIntent: OpenAppIntent())
    }
}

enum OpenWorkoutPlanError: Error, CustomLocalizedStringResourceConvertible {
    case workoutPlanNotFound
    case workoutPlanIncomplete

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .workoutPlanNotFound:
            return "That workout plan is no longer available."
        case .workoutPlanIncomplete:
            return "Finish creating the workout plan before opening it."
        }
    }
}

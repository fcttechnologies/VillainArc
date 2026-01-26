import AppIntents
import SwiftData

struct StartWorkoutWithTemplateIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Workout with Template"
    static let description = IntentDescription("Starts a new workout from a template.")
    static let supportedModes: IntentModes = .foreground(.dynamic)
    static var parameterSummary: some ParameterSummary {
        Summary("Start workout with \(\.$template)")
    }

    @Parameter(title: "Template", requestValueDialog: IntentDialog("Which template?"))
    var template: WorkoutTemplateEntity

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        let context = SharedModelContainer.container.mainContext
        if let _ = try? context.fetch(WorkoutTemplate.incomplete).first {
            throw StartWorkoutError.templateIsActive
        }
        if let _ = try? context.fetch(Workout.incomplete).first {
            throw StartWorkoutError.workoutIsActive
        }
        let templateID = template.id
        let predicate = #Predicate<WorkoutTemplate> { $0.id == templateID }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        guard let storedTemplate = try context.fetch(descriptor).first else {
            throw StartWorkoutWithTemplateError.templateNotFound
        }
        guard storedTemplate.complete else {
            throw StartWorkoutWithTemplateError.templateIncomplete
        }
        AppRouter.shared.startWorkout(from: storedTemplate)
        return .result(opensIntent: OpenAppIntent())
    }
}

enum StartWorkoutWithTemplateError: Error, CustomLocalizedStringResourceConvertible {
    case templateNotFound
    case templateIncomplete

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .templateNotFound:
            return "That template is no longer available."
        case .templateIncomplete:
            return "Finish the template before starting a workout from it."
        }
    }
}

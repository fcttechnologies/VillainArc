import AppIntents
import SwiftData

struct CreateTemplateIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Template"
    static let description = IntentDescription("Creates a new workout template")
    static let supportedModes: IntentModes = .foreground(.dynamic)

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        let context = SharedModelContainer.container.mainContext
        if let _ = try? context.fetch(Workout.incomplete).first {
            throw StartTemplateError.workoutIsActive
        }
        if let _ = try? context.fetch(WorkoutTemplate.incomplete).first {
            throw StartTemplateError.templateIsActive
        }
        AppRouter.shared.createTemplate()
        return .result(opensIntent: OpenAppIntent())
    }
}

enum StartTemplateError: Error, CustomLocalizedStringResourceConvertible {
    case templateIsActive
    case workoutIsActive
    
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .templateIsActive:
            return "You are currently creating a template. Finish that first."
        case .workoutIsActive:
            return "You are currently working out, finish that first."
        }
    }
}

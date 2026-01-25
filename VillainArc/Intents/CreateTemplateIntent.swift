import AppIntents
import SwiftData

struct CreateTemplateIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Template"
    static let description = IntentDescription("Creates a new workout template")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
//        let context = ModelContext(SharedModelContainer.container)
//        if let _ = try? context.fetch(Workout.incomplete).first {
//            throw StartTemplateError.workoutIsActive
//        }
//        if let template = try? context.fetch(WorkoutTemplate.incomplete).first {
//            AppRouter.shared.resumeTemplate(template)
//        } else {
//            AppRouter.shared.createTemplate(context: context)
//        }
        return .result(opensIntent: OpenAppIntent())
    }
}

enum StartTemplateError: Error, CustomLocalizedStringResourceConvertible {
    case workoutIsActive
    
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .workoutIsActive:
            return "You are currently working out, finish that first."
        }
    }
}

import AppIntents
import SwiftData

struct ResumeActiveSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Resume Active Session"
    static let description = IntentDescription("Resumes your current workout or template.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        let context = SharedModelContainer.container.mainContext
        if let workout = try? context.fetch(Workout.incomplete).first {
            AppRouter.shared.resumeWorkout(workout)
            return .result(opensIntent: OpenAppIntent())
        }
        if let template = try? context.fetch(WorkoutTemplate.incomplete).first {
            AppRouter.shared.resumeTemplate(template)
            return .result(opensIntent: OpenAppIntent())
        }
        throw ResumeActiveSessionError.noActiveSession
    }
}

enum ResumeActiveSessionError: Error, CustomLocalizedStringResourceConvertible {
    case noActiveSession

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noActiveSession:
            return "You don't have an active workout or template."
        }
    }
}

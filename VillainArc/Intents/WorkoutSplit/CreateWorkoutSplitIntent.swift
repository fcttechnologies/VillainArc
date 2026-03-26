import AppIntents
import SwiftData

struct CreateWorkoutSplitIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Workout Split"
    static let description = IntentDescription("Opens workout split creation.")
    static let supportedModes: IntentModes = .foreground(.dynamic)

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        let context = SharedModelContainer.container.mainContext
        try SetupGuard.requireReadyAndNoActiveFlow(context: context)

        AppRouter.shared.showSplitBuilderFromIntent = true
        AppRouter.shared.popToRoot()
        AppRouter.shared.navigate(to: .workoutSplit(autoPresentBuilder: false))
        return .result(opensIntent: OpenAppIntent())
    }
}

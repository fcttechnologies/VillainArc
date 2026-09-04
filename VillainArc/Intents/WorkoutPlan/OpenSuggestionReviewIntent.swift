import AppIntents
import FCTMetrics
import SwiftData

struct OpenSuggestionReviewIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentOpenSuggestionReview

    static let title: LocalizedStringResource = "Open Suggestion Review"
    static let description = IntentDescription("Opens the suggested changes waiting on a workout plan.")
    static let supportedModes: IntentModes = .foreground(.dynamic)
    static var parameterSummary: some ParameterSummary { Summary("Review suggestions for \(\.$workoutPlan)") }

    @Parameter(title: "Workout Plan", requestValueDialog: IntentDialog("Which workout plan's suggestions would you like to review?")) var workoutPlan: WorkoutPlanEntity

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        func run() async throws -> some IntentResult & OpensIntent {
            let context = SharedModelContainer.container.mainContext
            try SetupGuard.requireReady(context: context)

            let workoutPlanID = workoutPlan.id
            guard let storedPlan = try context.fetch(WorkoutPlan.byID(workoutPlanID)).first else { throw OpenSuggestionReviewIntentError.workoutPlanNotFound }
            // The same content the plan screen's own sparkles button appears for: something to
            // decide, or something already decided and waiting on a later workout to judge it.
            let hasContent = !pendingSuggestionEvents(for: storedPlan, in: context).isEmpty
                || !pendingOutcomeSuggestionEvents(for: storedPlan, in: context).isEmpty
            guard hasContent else { throw OpenSuggestionReviewIntentError.noSuggestions }

            AppRouter.shared.collapseActiveFlowPresentations()
            AppRouter.shared.pendingSuggestionReviewPlanID = workoutPlanID
            AppRouter.shared.navigate(to: .workoutPlanDetail(storedPlan, false))
            return .result(opensIntent: OpenAppIntent())
        }
        return try await Diag.intent(Self.diagCrumb, run)
    }
}

enum OpenSuggestionReviewIntentError: Error, CustomLocalizedStringResourceConvertible {
    case workoutPlanNotFound
    case noSuggestions

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .workoutPlanNotFound: return "That workout plan is no longer available."
        case .noSuggestions: return "There are no suggestions to review for that workout plan."
        }
    }
}

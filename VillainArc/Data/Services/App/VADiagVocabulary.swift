import FCTMetrics
import Foundation

// MARK: - The Diag vocabulary

/// Villain Arc's breadcrumbs: the shape of what happened, never a destination, a value, or a name.
/// Every name is a compile-time constant — free text is structurally unable to leave the device.
nonisolated enum VACrumb: String, DiagBreadcrumb, CaseIterable {
    case workoutStarted = "workout_started"
    case workoutFinished = "workout_finished"
    case workoutDiscarded = "workout_discarded"
    case cardioStarted = "cardio_started"
    case cardioFinished = "cardio_finished"
    case planCreated = "plan_created"
    case suggestionDecided = "suggestion_decided"
    case assistantAsked = "assistant_asked"
    case healthSyncRan = "health_sync_ran"
    case paywallShown = "paywall_shown"
}

/// The funnels whose abandonment is itself the signal.
nonisolated enum VAFunnel: String, DiagFunnel, CaseIterable {
    case onboarding = "onboarding"
    case workoutSession = "workout_session"
    case cardioSession = "cardio_session"
}

/// Dated deltas, coalesced by day on-device before they ride.
nonisolated enum VACounter: String, DiagCounter, CaseIterable {
    case workoutsCompleted = "workouts_completed"
    case cardioCompleted = "cardio_completed"
    case setsLogged = "sets_logged"
    case aiPlansGenerated = "ai_plans_generated"
    case aiReplacementsSuggested = "ai_replacements_suggested"
    case assistantQuestions = "assistant_questions"
}

import AppIntents
import SwiftData

@MainActor enum SetupGuard {
    static func requireReady(context: ModelContext) throws {
        guard DataManager.hasCompletedInitialBootstrap() else { throw SetupGuardError.onboardingNotComplete }

        guard (try context.fetch(AppSettings.single).first) != nil else { throw SetupGuardError.onboardingNotComplete }
        guard (try context.fetch(HealthSyncState.single).first) != nil else { throw SetupGuardError.onboardingNotComplete }

        guard let profile = try context.fetch(UserProfile.single).first else { throw SetupGuardError.onboardingNotComplete }

        guard profile.firstMissingStep == nil else { throw SetupGuardError.onboardingNotComplete }
    }

    static func requireNoActiveFlow(context: ModelContext) throws {
        if (try? context.fetch(WorkoutPlan.incomplete).first) != nil { throw StartWorkoutError.workoutPlanIsActive }
        if (try? context.fetch(WorkoutSession.incomplete).first) != nil { throw StartWorkoutError.workoutIsActive }
    }

    static func requireReadyAndNoActiveFlow(context: ModelContext) throws {
        try requireReady(context: context)
        try requireNoActiveFlow(context: context)
    }
}

enum SetupGuardError: Error, CustomLocalizedStringResourceConvertible {
    case onboardingNotComplete

    var localizedStringResource: LocalizedStringResource { "You need to launch and finish setting up the app before you can use this feature." }
}

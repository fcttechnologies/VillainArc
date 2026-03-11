import AppIntents
import SwiftData

@MainActor
enum SetupGuard {
    static func requireReady(context: ModelContext) throws {
        guard DataManager.hasCompletedInitialBootstrap() else {
            throw SetupGuardError.onboardingNotComplete
        }

        _ = try SystemState.ensureAppSettings(context: context)
        let profile = try SystemState.ensureUserProfile(context: context)
        guard profile.firstMissingStep == nil else {
            throw SetupGuardError.onboardingNotComplete
        }
    }
}

enum SetupGuardError: Error, CustomLocalizedStringResourceConvertible {
    case onboardingNotComplete

    var localizedStringResource: LocalizedStringResource {
        "You need to launch and finish setting up the app before you can use this feature."
    }
}

import AppIntents
import FCTMetrics
import SwiftData

struct OpenWorkoutPreferencesIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentOpenWorkoutPreferences

    static let title: LocalizedStringResource = "Open Workout Preferences"
    static let description = IntentDescription("Opens workout preferences in app settings.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        func run() async throws -> some IntentResult & OpensIntent {
            try openAppSettings(destination: .workouts)
            return .result(opensIntent: OpenAppIntent())
        }
        return try await Diag.intent(Self.diagCrumb, run)
    }
}

struct OpenAppleHealthSettingsIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentOpenAppleHealthSettings

    static let title: LocalizedStringResource = "Open Health Settings"
    static let description = IntentDescription("Opens Health integration settings.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        func run() async throws -> some IntentResult & OpensIntent {
            try openAppSettings(destination: .appleHealth)
            return .result(opensIntent: OpenAppIntent())
        }
        return try await Diag.intent(Self.diagCrumb, run)
    }
}

struct OpenNotificationSettingsIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentOpenNotificationSettings

    static let title: LocalizedStringResource = "Open Notification Settings"
    static let description = IntentDescription("Opens notification settings.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        func run() async throws -> some IntentResult & OpensIntent {
            try openAppSettings(destination: .notifications)
            return .result(opensIntent: OpenAppIntent())
        }
        return try await Diag.intent(Self.diagCrumb, run)
    }
}

struct OpenUnitSettingsIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentOpenUnitSettings

    static let title: LocalizedStringResource = "Open Unit Settings"
    static let description = IntentDescription("Opens unit settings.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        func run() async throws -> some IntentResult & OpensIntent {
            try openAppSettings(destination: .units)
            return .result(opensIntent: OpenAppIntent())
        }
        return try await Diag.intent(Self.diagCrumb, run)
    }
}


@MainActor
private func openAppSettings(destination: AppSettingsDestination) throws {
    let context = SharedModelContainer.container.mainContext
    try SetupGuard.requireReady(context: context)

    AppRouter.shared.presentSettingsFromSystem(destination)
}

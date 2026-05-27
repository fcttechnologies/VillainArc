import AppIntents
import SwiftData

struct OpenWorkoutPreferencesIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Workout Preferences"
    static let description = IntentDescription("Opens workout preferences in app settings.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        try openAppSettings(destination: .workouts)
        return .result(opensIntent: OpenAppIntent())
    }
}

struct OpenAppleHealthSettingsIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Health Settings"
    static let description = IntentDescription("Opens Health integration settings.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        try openAppSettings(destination: .appleHealth)
        return .result(opensIntent: OpenAppIntent())
    }
}

struct OpenNotificationSettingsIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Notification Settings"
    static let description = IntentDescription("Opens notification settings.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        try openAppSettings(destination: .notifications)
        return .result(opensIntent: OpenAppIntent())
    }
}

struct OpenUnitSettingsIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Unit Settings"
    static let description = IntentDescription("Opens unit settings.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        try openAppSettings(destination: .units)
        return .result(opensIntent: OpenAppIntent())
    }
}


@MainActor
private func openAppSettings(destination: AppSettingsDestination) throws {
    let context = SharedModelContainer.container.mainContext
    try SetupGuard.requireReady(context: context)

    AppRouter.shared.presentSettingsFromSystem(destination)
}

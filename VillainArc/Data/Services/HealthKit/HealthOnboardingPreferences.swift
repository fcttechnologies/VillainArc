import Foundation

enum HealthOnboardingPreferences {
    private static let onboardingKey = "health_onboarding_completed"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: SharedModelContainer.appGroupID) ?? .standard
    }

    static var hasCompletedPrompt: Bool {
        defaults.bool(forKey: onboardingKey)
    }

    static func markCompleted() {
        defaults.set(true, forKey: onboardingKey)
    }
}

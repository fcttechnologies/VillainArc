import Foundation
import HealthKit

enum HealthPermissionPreferences {
    static let currentPermissionVersion = "1.1"

    private static let lastPromptedPermissionVersionKey = "health_last_prompted_permission_version"

    private static var defaults: UserDefaults {
        SharedModelContainer.sharedDefaults
    }

    static var lastPromptedPermissionVersion: String? {
        defaults.string(forKey: lastPromptedPermissionVersionKey)
    }

    static var shouldPromptForCurrentVersion: Bool {
        lastPromptedPermissionVersion != currentPermissionVersion
    }

    static func markPromptHandledForCurrentVersion() {
        defaults.set(currentPermissionVersion, forKey: lastPromptedPermissionVersionKey)
    }
}

enum HealthSyncPreferences {
    private static let workoutAnchorKey = "health_workout_anchor"

    private static var defaults: UserDefaults {
        SharedModelContainer.sharedDefaults
    }

    static var workoutAnchor: HKQueryAnchor? {
        get {
            guard let data = defaults.data(forKey: workoutAnchorKey) else { return nil }
            return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
        }
        set {
            guard let newValue else {
                defaults.removeObject(forKey: workoutAnchorKey)
                return
            }

            guard let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: true) else {
                return
            }

            defaults.set(data, forKey: workoutAnchorKey)
        }
    }
}

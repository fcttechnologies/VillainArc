import Foundation
import HealthKit

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

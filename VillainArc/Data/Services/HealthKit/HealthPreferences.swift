import Foundation
import HealthKit

enum HealthSyncPreferences {
    private static let workoutAnchorKey = "health_workout_anchor"
    private static let weightEntryAnchorKey = "health_weight_entry_anchor"

    private static var defaults: UserDefaults { SharedModelContainer.sharedDefaults }

    static var workoutAnchor: HKQueryAnchor? {
        get { anchor(forKey: workoutAnchorKey) }
        set { setAnchor(newValue, forKey: workoutAnchorKey) }
    }

    static var weightEntryAnchor: HKQueryAnchor? {
        get { anchor(forKey: weightEntryAnchorKey) }
        set { setAnchor(newValue, forKey: weightEntryAnchorKey) }
    }

    private static func anchor(forKey key: String) -> HKQueryAnchor? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    }

    private static func setAnchor(_ anchor: HKQueryAnchor?, forKey key: String) {
        guard let anchor else {
            defaults.removeObject(forKey: key)
            return
        }

        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true) else { return }

        defaults.set(data, forKey: key)
    }
}

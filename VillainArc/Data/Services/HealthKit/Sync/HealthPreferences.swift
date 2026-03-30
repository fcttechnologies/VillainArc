import Foundation
import HealthKit

nonisolated enum HealthSyncPreferences {
    private static let workoutAnchorKey = "health_workout_anchor"
    private static let weightEntryAnchorKey = "health_weight_entry_anchor"
    private static let stepCountAnchorKey = "health_step_count_anchor"
    private static let walkingRunningDistanceAnchorKey = "health_walking_running_distance_anchor"
    private static let activeEnergyBurnedAnchorKey = "health_active_energy_burned_anchor"
    private static let restingEnergyBurnedAnchorKey = "health_resting_energy_burned_anchor"

    nonisolated(unsafe) private static var defaults: UserDefaults { SharedModelContainer.sharedDefaults }

    static var workoutAnchor: HKQueryAnchor? {
        get { anchor(forKey: workoutAnchorKey) }
        set { setAnchor(newValue, forKey: workoutAnchorKey) }
    }

    static var weightEntryAnchor: HKQueryAnchor? {
        get { anchor(forKey: weightEntryAnchorKey) }
        set { setAnchor(newValue, forKey: weightEntryAnchorKey) }
    }

    static var stepCountAnchor: HKQueryAnchor? {
        get { anchor(forKey: stepCountAnchorKey) }
        set { setAnchor(newValue, forKey: stepCountAnchorKey) }
    }

    static var walkingRunningDistanceAnchor: HKQueryAnchor? {
        get { anchor(forKey: walkingRunningDistanceAnchorKey) }
        set { setAnchor(newValue, forKey: walkingRunningDistanceAnchorKey) }
    }

    static var activeEnergyBurnedAnchor: HKQueryAnchor? {
        get { anchor(forKey: activeEnergyBurnedAnchorKey) }
        set { setAnchor(newValue, forKey: activeEnergyBurnedAnchorKey) }
    }

    static var restingEnergyBurnedAnchor: HKQueryAnchor? {
        get { anchor(forKey: restingEnergyBurnedAnchorKey) }
        set { setAnchor(newValue, forKey: restingEnergyBurnedAnchorKey) }
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

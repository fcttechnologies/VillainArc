import Foundation
import HealthKit

enum HealthSyncPreferences {
    private static let workoutAnchorKey = "health_workout_anchor"
    private static let weightEntryAnchorKey = "health_weight_entry_anchor"
    private static let stepCountAnchorKey = "health_step_count_anchor"
    private static let walkingRunningDistanceAnchorKey = "health_walking_running_distance_anchor"
    private static let activeEnergyBurnedAnchorKey = "health_active_energy_burned_anchor"
    private static let restingEnergyBurnedAnchorKey = "health_resting_energy_burned_anchor"
    private static let stepCountSyncedRangeStartKey = "health_step_count_synced_range_start"
    private static let stepCountSyncedRangeEndKey = "health_step_count_synced_range_end"
    private static let walkingRunningDistanceSyncedRangeStartKey = "health_walking_running_distance_synced_range_start"
    private static let walkingRunningDistanceSyncedRangeEndKey = "health_walking_running_distance_synced_range_end"
    private static let activeEnergyBurnedSyncedRangeStartKey = "health_active_energy_burned_synced_range_start"
    private static let activeEnergyBurnedSyncedRangeEndKey = "health_active_energy_burned_synced_range_end"
    private static let restingEnergyBurnedSyncedRangeStartKey = "health_resting_energy_burned_synced_range_start"
    private static let restingEnergyBurnedSyncedRangeEndKey = "health_resting_energy_burned_synced_range_end"

    private static var defaults: UserDefaults { SharedModelContainer.sharedDefaults }

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

    static var stepCountSyncedRange: ClosedRange<Date>? { get { dateRange(startKey: stepCountSyncedRangeStartKey, endKey: stepCountSyncedRangeEndKey) } set { setDateRange(newValue, startKey: stepCountSyncedRangeStartKey, endKey: stepCountSyncedRangeEndKey) } }

    static var walkingRunningDistanceSyncedRange: ClosedRange<Date>? { get { dateRange(startKey: walkingRunningDistanceSyncedRangeStartKey, endKey: walkingRunningDistanceSyncedRangeEndKey) } set { setDateRange(newValue, startKey: walkingRunningDistanceSyncedRangeStartKey, endKey: walkingRunningDistanceSyncedRangeEndKey) } }

    static var activeEnergyBurnedSyncedRange: ClosedRange<Date>? { get { dateRange(startKey: activeEnergyBurnedSyncedRangeStartKey, endKey: activeEnergyBurnedSyncedRangeEndKey) } set { setDateRange(newValue, startKey: activeEnergyBurnedSyncedRangeStartKey, endKey: activeEnergyBurnedSyncedRangeEndKey) } }

    static var restingEnergyBurnedSyncedRange: ClosedRange<Date>? { get { dateRange(startKey: restingEnergyBurnedSyncedRangeStartKey, endKey: restingEnergyBurnedSyncedRangeEndKey) } set { setDateRange(newValue, startKey: restingEnergyBurnedSyncedRangeStartKey, endKey: restingEnergyBurnedSyncedRangeEndKey) } }

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

    private static func dateRange(startKey: String, endKey: String) -> ClosedRange<Date>? {
        guard let start = defaults.object(forKey: startKey) as? Date, let end = defaults.object(forKey: endKey) as? Date else { return nil }
        return start...end
    }

    private static func setDateRange(_ range: ClosedRange<Date>?, startKey: String, endKey: String) {
        guard let range else {
            defaults.removeObject(forKey: startKey)
            defaults.removeObject(forKey: endKey)
            return
        }

        defaults.set(range.lowerBound, forKey: startKey)
        defaults.set(range.upperBound, forKey: endKey)
    }
}

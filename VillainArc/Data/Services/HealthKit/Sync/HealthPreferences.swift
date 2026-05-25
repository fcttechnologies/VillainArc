import Foundation
import HealthKit
import SwiftData

nonisolated enum HealthSyncPreferences {
    private static let workoutAnchorKey = "health_workout_anchor"
    private static let weightEntryAnchorKey = "health_weight_entry_anchor"
    private static let stepCountAnchorKey = "health_step_count_anchor"
    private static let walkingRunningDistanceAnchorKey = "health_walking_running_distance_anchor"
    private static let activeEnergyBurnedAnchorKey = "health_active_energy_burned_anchor"
    private static let restingEnergyBurnedAnchorKey = "health_resting_energy_burned_anchor"
    private static let sleepAnalysisAnchorKey = "health_sleep_analysis_anchor"
    private static let heartRateAnchorKey = "health_heart_rate_anchor"
    private static let restingHeartRateAnchorKey = "health_resting_heart_rate_anchor"
    private static let walkingHeartRateAnchorKey = "health_walking_heart_rate_anchor"
    private static let heartRateVariabilityAnchorKey = "health_heart_rate_variability_anchor"
    private static let respiratoryRateAnchorKey = "health_respiratory_rate_anchor"
    private static let wristTemperatureAnchorKey = "health_wrist_temperature_anchor"
    private static let dietaryWaterAnchorKey = "health_dietary_water_anchor"

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

    static var sleepAnalysisAnchor: HKQueryAnchor? {
        get { anchor(forKey: sleepAnalysisAnchorKey) }
        set { setAnchor(newValue, forKey: sleepAnalysisAnchorKey) }
    }

    static var heartRateAnchor: HKQueryAnchor? {
        get { anchor(forKey: heartRateAnchorKey) }
        set { setAnchor(newValue, forKey: heartRateAnchorKey) }
    }

    static var restingHeartRateAnchor: HKQueryAnchor? {
        get { anchor(forKey: restingHeartRateAnchorKey) }
        set { setAnchor(newValue, forKey: restingHeartRateAnchorKey) }
    }

    static var walkingHeartRateAnchor: HKQueryAnchor? {
        get { anchor(forKey: walkingHeartRateAnchorKey) }
        set { setAnchor(newValue, forKey: walkingHeartRateAnchorKey) }
    }

    static var heartRateVariabilityAnchor: HKQueryAnchor? {
        get { anchor(forKey: heartRateVariabilityAnchorKey) }
        set { setAnchor(newValue, forKey: heartRateVariabilityAnchorKey) }
    }

    static var respiratoryRateAnchor: HKQueryAnchor? {
        get { anchor(forKey: respiratoryRateAnchorKey) }
        set { setAnchor(newValue, forKey: respiratoryRateAnchorKey) }
    }

    static var wristTemperatureAnchor: HKQueryAnchor? {
        get { anchor(forKey: wristTemperatureAnchorKey) }
        set { setAnchor(newValue, forKey: wristTemperatureAnchorKey) }
    }

    static var dietaryWaterAnchor: HKQueryAnchor? {
        get { anchor(forKey: dietaryWaterAnchorKey) }
        set { setAnchor(newValue, forKey: dietaryWaterAnchorKey) }
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

nonisolated enum HealthReadProbe {
    static func hasReadableWorkoutSampleBeyondKnownLocalCount() async -> Bool {
        let localContext = ModelContext(SharedModelContainer.container)
        let knownLocalWorkoutCount = (try? localContext.fetchCount(HealthWorkout.linkedToLocalSession)) ?? 0
        let descriptor = HKSampleQueryDescriptor(predicates: [.workout()], sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)], limit: knownLocalWorkoutCount + 1)

        guard let workouts = try? await descriptor.result(for: HealthAuthorizationManager.healthStore) else { return false }
        return workouts.count > knownLocalWorkoutCount
    }

    static func hasReadableBodyMassSampleBeyondKnownLocalCount() async -> Bool {
        let localContext = ModelContext(SharedModelContainer.container)
        let knownLocalWeightCount = (try? localContext.fetchCount(WeightEntry.exportedToHealth)) ?? 0
        let descriptor = HKSampleQueryDescriptor(predicates: [.quantitySample(type: HealthKitCatalog.bodyMassType)], sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)], limit: knownLocalWeightCount + 1)

        guard let samples = try? await descriptor.result(for: HealthAuthorizationManager.healthStore) else { return false }
        return samples.count > knownLocalWeightCount
    }

    static func hasReadableQuantitySample(for type: HKQuantityType) async -> Bool {
        let descriptor = HKSampleQueryDescriptor(predicates: [.quantitySample(type: type)], sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)], limit: 1)

        return (try? await descriptor.result(for: HealthAuthorizationManager.healthStore).isEmpty == false) ?? false
    }

    static func hasReadableCategorySample(for type: HKCategoryType) async -> Bool {
        let descriptor = HKSampleQueryDescriptor(predicates: [.categorySample(type: type)], sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)], limit: 1)

        return (try? await descriptor.result(for: HealthAuthorizationManager.healthStore).isEmpty == false) ?? false
    }
}

extension HealthWorkout {
    fileprivate static var linkedToLocalSession: FetchDescriptor<HealthWorkout> {
        let predicate = #Predicate<HealthWorkout> { $0.workoutSession != nil }
        return FetchDescriptor(predicate: predicate)
    }
}

extension WeightEntry {
    fileprivate static var exportedToHealth: FetchDescriptor<WeightEntry> {
        let predicate = #Predicate<WeightEntry> { $0.hasBeenExportedToHealth && $0.healthSampleUUID != nil }
        return FetchDescriptor(predicate: predicate)
    }
}

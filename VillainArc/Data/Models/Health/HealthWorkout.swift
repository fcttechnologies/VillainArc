import Foundation
import HealthKit
import SwiftData

@Model final class HealthWorkout {
    #Index<HealthWorkout>([\.healthWorkoutUUID])

    var healthWorkoutUUID: UUID = UUID()
    var workoutSession: WorkoutSession?
    var startDate: Date = Date()
    var endDate: Date = Date()
    var duration: TimeInterval = 0
    var activityTypeRawValue: UInt = HKWorkoutActivityType.other.rawValue
    var isIndoorWorkout: Bool?
    var averageHeartRateBPM: Double?
    var maximumHeartRateBPM: Double?
    var activeEnergyBurned: Double?
    var restingEnergyBurned: Double?
    var totalDistance: Double?
    var isAvailableInHealthKit: Bool = true

    var activityType: HKWorkoutActivityType {
        get { HKWorkoutActivityType(rawValue: activityTypeRawValue) ?? .other }
        set { activityTypeRawValue = newValue.rawValue }
    }

    var totalEnergyBurned: Double? {
        guard let activeEnergyBurned, let restingEnergyBurned else { return nil }
        return activeEnergyBurned + restingEnergyBurned
    }

    init(workout: HKWorkout, workoutSession: WorkoutSession? = nil) {
        healthWorkoutUUID = workout.uuid
        self.workoutSession = workoutSession
        startDate = workout.startDate
        endDate = workout.endDate
        duration = workout.duration
        activityType = workout.workoutActivityType
        isIndoorWorkout = workout.metadata?[HKMetadataKeyIndoorWorkout] as? Bool
        let heartRateStats = Self.heartRateStats(for: workout)
        averageHeartRateBPM = heartRateStats.average
        maximumHeartRateBPM = heartRateStats.maximum
        activeEnergyBurned = Self.energyBurned(for: HealthKitCatalog.activeEnergyBurnedType, in: workout)
        restingEnergyBurned = Self.energyBurned(for: HealthKitCatalog.restingEnergyBurnedType, in: workout)
        totalDistance = workout.totalDistance?.doubleValue(for: .meter())
        isAvailableInHealthKit = true
    }

    func update(from workout: HKWorkout) {
        startDate = workout.startDate
        endDate = workout.endDate
        duration = workout.duration
        activityType = workout.workoutActivityType
        isIndoorWorkout = workout.metadata?[HKMetadataKeyIndoorWorkout] as? Bool
        let heartRateStats = Self.heartRateStats(for: workout)
        averageHeartRateBPM = heartRateStats.average
        maximumHeartRateBPM = heartRateStats.maximum
        activeEnergyBurned = Self.energyBurned(for: HealthKitCatalog.activeEnergyBurnedType, in: workout)
        restingEnergyBurned = Self.energyBurned(for: HealthKitCatalog.restingEnergyBurnedType, in: workout)
        totalDistance = workout.totalDistance?.doubleValue(for: .meter())
        isAvailableInHealthKit = true
    }

    private static func energyBurned(for type: HKQuantityType, in workout: HKWorkout) -> Double? {
        workout.statistics(for: type)?.sumQuantity()?.doubleValue(for: .kilocalorie())
    }

    private static func heartRateStats(for workout: HKWorkout) -> (average: Double?, maximum: Double?) {
        let statistics = workout.statistics(for: HealthKitCatalog.heartRateType)
        return (
            statistics?.averageQuantity()?.doubleValue(for: HealthKitCatalog.bpmUnit),
            statistics?.maximumQuantity()?.doubleValue(for: HealthKitCatalog.bpmUnit)
        )
    }
}

extension HealthWorkout {
    static func byHealthWorkoutUUID(_ id: UUID) -> FetchDescriptor<HealthWorkout> {
        let predicate = #Predicate<HealthWorkout> { $0.healthWorkoutUUID == id }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        return descriptor
    }

    static var history: FetchDescriptor<HealthWorkout> { FetchDescriptor(sortBy: [SortDescriptor(\.startDate, order: .reverse)]) }

    static func recentStandaloneWorkouts(limit: Int? = nil) -> FetchDescriptor<HealthWorkout> {
        let predicate = #Predicate<HealthWorkout> { $0.workoutSession == nil || $0.workoutSession?.isHidden == true }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        if let limit { descriptor.fetchLimit = limit }
        return descriptor
    }

    static var recentStandalone: FetchDescriptor<HealthWorkout> { recentStandaloneWorkouts(limit: 1) }

    var activityTypeDisplayName: String { activityType.displayName(indoorWorkout: isIndoorWorkout) }
}

extension HKWorkoutActivityType {
    nonisolated var displayName: String { displayName(indoorWorkout: nil) }

    nonisolated func displayName(indoorWorkout: Bool?) -> String {
        switch self {
        case .traditionalStrengthTraining: return "Traditional Strength Training"
        case .functionalStrengthTraining: return "Functional Strength Training"
        case .highIntensityIntervalTraining: return "HIIT"
        case .running: return locationQualifiedName(indoorWorkout: indoorWorkout, indoor: "Indoor Run", outdoor: "Outdoor Run", fallback: "Running")
        case .walking: return locationQualifiedName(indoorWorkout: indoorWorkout, indoor: "Indoor Walk", outdoor: "Outdoor Walk", fallback: "Walking")
        case .cycling: return locationQualifiedName(indoorWorkout: indoorWorkout, indoor: "Indoor Ride", outdoor: "Outdoor Ride", fallback: "Cycling")
        case .hiking: return "Hiking"
        case .mixedCardio: return "Mixed Cardio"
        case .elliptical: return "Elliptical"
        case .rowing: return "Rowing"
        case .stairClimbing: return "Stair Climbing"
        case .cooldown: return "Cooldown"
        case .coreTraining: return "Core Training"
        case .yoga: return "Yoga"
        case .pilates: return "Pilates"
        case .other: return "Workout"
        default: return "Workout"
        }
    }

    private nonisolated func locationQualifiedName(indoorWorkout: Bool?, indoor: String, outdoor: String, fallback: String) -> String {
        switch indoorWorkout {
        case true: return indoor
        case false: return outdoor
        case nil: return fallback
        }
    }
}

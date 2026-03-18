import Foundation
import HealthKit
import SwiftData

@Model
final class HealthWorkout {
    #Index<HealthWorkout>([\.healthWorkoutUUID])

    var healthWorkoutUUID: UUID = UUID()
    var workoutSession: WorkoutSession?
    var startDate: Date = Date()
    var endDate: Date = Date()
    var duration: TimeInterval = 0
    var activityTypeRawValue: UInt = HKWorkoutActivityType.other.rawValue
    var isIndoorWorkout: Bool?
    var totalEnergyBurned: Double?
    var totalDistance: Double?
    var sourceName: String = ""
    var isAvailableInHealthKit: Bool = true
    var lastSyncedAt: Date = Date()

    var activityType: HKWorkoutActivityType {
        get { HKWorkoutActivityType(rawValue: activityTypeRawValue) ?? .other }
        set { activityTypeRawValue = newValue.rawValue }
    }

    init(workout: HKWorkout, workoutSession: WorkoutSession? = nil, lastSyncedAt: Date = .now) {
        let activeEnergyType = HKQuantityType(.activeEnergyBurned)
        healthWorkoutUUID = workout.uuid
        self.workoutSession = workoutSession
        startDate = workout.startDate
        endDate = workout.endDate
        duration = workout.duration
        activityType = workout.workoutActivityType
        isIndoorWorkout = workout.metadata?[HKMetadataKeyIndoorWorkout] as? Bool
        totalEnergyBurned = workout
            .statistics(for: activeEnergyType)?
            .sumQuantity()?
            .doubleValue(for: .kilocalorie())
        totalDistance = workout.totalDistance?.doubleValue(for: .meter())
        sourceName = workout.sourceRevision.source.name
        isAvailableInHealthKit = true
        self.lastSyncedAt = lastSyncedAt
    }

    func update(from workout: HKWorkout, lastSyncedAt: Date = .now) {
        let activeEnergyType = HKQuantityType(.activeEnergyBurned)
        startDate = workout.startDate
        endDate = workout.endDate
        duration = workout.duration
        activityType = workout.workoutActivityType
        isIndoorWorkout = workout.metadata?[HKMetadataKeyIndoorWorkout] as? Bool
        totalEnergyBurned = workout
            .statistics(for: activeEnergyType)?
            .sumQuantity()?
            .doubleValue(for: .kilocalorie())
        totalDistance = workout.totalDistance?.doubleValue(for: .meter())
        sourceName = workout.sourceRevision.source.name
        isAvailableInHealthKit = true
        self.lastSyncedAt = lastSyncedAt
    }
}

extension HealthWorkout {
    static func byHealthWorkoutUUID(_ id: UUID) -> FetchDescriptor<HealthWorkout> {
        let predicate = #Predicate<HealthWorkout> { $0.healthWorkoutUUID == id }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        return descriptor
    }

    static var history: FetchDescriptor<HealthWorkout> {
        FetchDescriptor(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
    }

    var activityTypeDisplayName: String {
        activityType.displayName(indoorWorkout: isIndoorWorkout)
    }
}

extension HKWorkoutActivityType {
    nonisolated var displayName: String {
        displayName(indoorWorkout: nil)
    }

    nonisolated func displayName(indoorWorkout: Bool?) -> String {
        switch self {
        case .traditionalStrengthTraining:
            return "Traditional Strength Training"
        case .functionalStrengthTraining:
            return "Functional Strength Training"
        case .highIntensityIntervalTraining:
            return "HIIT"
        case .running:
            return locationQualifiedName(indoorWorkout: indoorWorkout, indoor: "Indoor Run", outdoor: "Outdoor Run", fallback: "Running")
        case .walking:
            return locationQualifiedName(indoorWorkout: indoorWorkout, indoor: "Indoor Walk", outdoor: "Outdoor Walk", fallback: "Walking")
        case .cycling:
            return locationQualifiedName(indoorWorkout: indoorWorkout, indoor: "Indoor Ride", outdoor: "Outdoor Ride", fallback: "Cycling")
        case .hiking:
            return "Hiking"
        case .mixedCardio:
            return "Mixed Cardio"
        case .elliptical:
            return "Elliptical"
        case .rowing:
            return "Rowing"
        case .stairClimbing:
            return "Stair Climbing"
        case .cooldown:
            return "Cooldown"
        case .coreTraining:
            return "Core Training"
        case .yoga:
            return "Yoga"
        case .pilates:
            return "Pilates"
        case .other:
            return "Workout"
        default:
            return "Workout"
        }
    }

    private nonisolated func locationQualifiedName(indoorWorkout: Bool?, indoor: String, outdoor: String, fallback: String) -> String {
        switch indoorWorkout {
        case true:
            return indoor
        case false:
            return outdoor
        case nil:
            return fallback
        }
    }
}

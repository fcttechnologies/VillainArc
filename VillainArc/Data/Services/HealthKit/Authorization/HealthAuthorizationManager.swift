import Foundation
import HealthKit

nonisolated enum HealthAuthorizationState: Equatable {
    case unavailable
    case notDetermined
    case authorized
    case denied

    var statusText: String {
        switch self {
        case .unavailable: return "Unavailable"
        case .notDetermined: return "Not Connected"
        case .authorized: return "Connected"
        case .denied: return "Access Denied"
        }
    }

    var isAuthorized: Bool { self == .authorized }
}

nonisolated enum HealthAuthorizationAction: Equatable {
    case requestAccess
    case openSettings
    case manageInSettings
    case unavailable

    var buttonTitle: String {
        switch self {
        case .requestAccess: return "Connect Apple Health"
        case .openSettings: return "Open Settings"
        case .manageInSettings: return "Manage In Settings"
        case .unavailable: return "Unavailable"
        }
    }

    var systemImage: String {
        switch self {
        case .requestAccess: return "heart.text.square"
        case .openSettings, .manageInSettings: return "gearshape"
        case .unavailable: return "heart.slash"
        }
    }
}

nonisolated enum HealthAuthorizationManager {
    static let healthStore = HKHealthStore()

    static var isHealthDataAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    static var currentAuthorizationState: HealthAuthorizationState {
        guard isHealthDataAvailable else { return .unavailable }

        let statuses = healthShareTypes.map { healthStore.authorizationStatus(for: $0) }

        if statuses.allSatisfy({ $0 == .sharingAuthorized }) { return .authorized }

        if statuses.contains(.sharingDenied) { return .denied }

        return .notDetermined
    }

    static var canWriteWorkouts: Bool {
        guard isHealthDataAvailable else { return false }
        return healthStore.authorizationStatus(for: HealthKitCatalog.workoutType) == .sharingAuthorized
    }

    static var canWriteWorkoutEffortScore: Bool {
        guard isHealthDataAvailable else { return false }
        return healthStore.authorizationStatus(for: HealthKitCatalog.workoutEffortScoreType) == .sharingAuthorized
    }

    static var canWriteActiveEnergyBurned: Bool {
        guard isHealthDataAvailable else { return false }
        return healthStore.authorizationStatus(for: HealthKitCatalog.activeEnergyBurnedType) == .sharingAuthorized
    }

    static var canWriteRestingEnergyBurned: Bool {
        guard isHealthDataAvailable else { return false }
        return healthStore.authorizationStatus(for: HealthKitCatalog.restingEnergyBurnedType) == .sharingAuthorized
    }

    static var canWriteBodyMass: Bool {
        guard isHealthDataAvailable else { return false }
        return healthStore.authorizationStatus(for: HealthKitCatalog.bodyMassType) == .sharingAuthorized
    }

    static var hasRequestedWorkoutAuthorization: Bool {
        guard isHealthDataAvailable else { return false }
        return healthStore.authorizationStatus(for: HealthKitCatalog.workoutType) != .notDetermined
    }

    static var hasRequestedBodyMassAuthorization: Bool {
        guard isHealthDataAvailable else { return false }
        return healthStore.authorizationStatus(for: HealthKitCatalog.bodyMassType) != .notDetermined
    }

    static var hasRequestedStepCountAuthorization: Bool {
        guard isHealthDataAvailable else { return false }
        return healthStore.authorizationStatus(for: HealthKitCatalog.stepCountType) != .notDetermined
    }

    static var hasRequestedWalkingRunningDistanceAuthorization: Bool {
        guard isHealthDataAvailable else { return false }
        return healthStore.authorizationStatus(for: HealthKitCatalog.walkingRunningDistanceType) != .notDetermined
    }

    static var hasRequestedActiveEnergyBurnedAuthorization: Bool {
        guard isHealthDataAvailable else { return false }
        return healthStore.authorizationStatus(for: HealthKitCatalog.activeEnergyBurnedType) != .notDetermined
    }

    static var hasRequestedRestingEnergyBurnedAuthorization: Bool {
        guard isHealthDataAvailable else { return false }
        return healthStore.authorizationStatus(for: HealthKitCatalog.restingEnergyBurnedType) != .notDetermined
    }

    static var hasRequestedSleepAnalysisAuthorization: Bool {
        guard isHealthDataAvailable else { return false }
        return healthStore.authorizationStatus(for: HealthKitCatalog.sleepAnalysisType) != .notDetermined
    }

    static func authorizationAction() async -> HealthAuthorizationAction {
        let state = currentAuthorizationState
        guard state != .unavailable else { return .unavailable }

        do {
            let requestStatus = try await healthStore.statusForAuthorizationRequest(toShare: healthShareTypes, read: healthReadTypes)
            switch requestStatus {
            case .shouldRequest: return .requestAccess
            case .unnecessary, .unknown: return state == .authorized ? .manageInSettings : .openSettings
            @unknown default: return state == .authorized ? .manageInSettings : .openSettings
            }
        } catch {
            print("Failed to determine HealthKit authorization request status: \(error)")
            return state == .notDetermined ? .requestAccess : .openSettings
        }
    }

    static func requestAuthorization() async -> HealthAuthorizationState {
        guard isHealthDataAvailable else { return .unavailable }

        do {
            try await healthStore.requestAuthorization(toShare: healthShareTypes, read: healthReadTypes)
        } catch {
            print("HealthKit authorization request failed: \(error)")
        }

        return currentAuthorizationState
    }

    static func metadata(for session: WorkoutSession) -> [String: Any] {
        ["Workout Title": session.title, HKMetadataKeyIndoorWorkout: true, HealthMetadataKeys.workoutSessionID: session.id.uuidString]
    }

    static func metadata(for weightEntry: WeightEntry) -> [String: Any] {
        [HealthMetadataKeys.weightEntryID: weightEntry.id.uuidString, HKMetadataKeyWasUserEntered: true]
    }

    private static var healthShareTypes: Set<HKSampleType> {
        [
            HealthKitCatalog.workoutType,
            HealthKitCatalog.workoutEffortScoreType,
            HealthKitCatalog.activeEnergyBurnedType,
            HealthKitCatalog.restingEnergyBurnedType,
            HealthKitCatalog.bodyMassType
        ]
    }

    private static var healthReadTypes: Set<HKObjectType> {
        [
            HealthKitCatalog.workoutType,
            HealthKitCatalog.workoutRoute,
            HealthKitCatalog.dateOfBirthCharacteristic,
            HealthKitCatalog.biologicalSexCharacteristic,
            HealthKitCatalog.sleepAnalysisType,
            HealthKitCatalog.stepCountType,
            HealthKitCatalog.heartRateType,
            HealthKitCatalog.activeEnergyBurnedType,
            HealthKitCatalog.restingEnergyBurnedType,
            HealthKitCatalog.respiratoryRateType,
            HealthKitCatalog.flightsClimbedType,
            HealthKitCatalog.heightType,
            HealthKitCatalog.bodyMassType,
            HealthKitCatalog.walkingRunningDistanceType,
            HealthKitCatalog.distanceCyclingType,
            HealthKitCatalog.distanceSwimmingType,
            HealthKitCatalog.distanceWheelchairType,
            HealthKitCatalog.distanceRowingType,
            HealthKitCatalog.distancePaddleSportsType,
            HealthKitCatalog.distanceCrossCountrySkiingType,
            HealthKitCatalog.distanceDownhillSnowSportsType,
            HealthKitCatalog.swimmingStrokeCountType,
            HealthKitCatalog.runningSpeedType,
            HealthKitCatalog.runningPowerType,
            HealthKitCatalog.runningStrideLengthType,
            HealthKitCatalog.runningGroundContactTimeType,
            HealthKitCatalog.runningVerticalOscillationType,
            HealthKitCatalog.cyclingCadenceType,
            HealthKitCatalog.cyclingPowerType,
            HealthKitCatalog.cyclingSpeedType,
            HealthKitCatalog.physicalEffortType,
            HealthKitCatalog.workoutEffortScoreType,
            HealthKitCatalog.estimatedWorkoutEffortScoreType
        ]
    }
}

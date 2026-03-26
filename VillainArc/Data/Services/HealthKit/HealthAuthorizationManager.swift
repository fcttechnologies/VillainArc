import Foundation
import HealthKit

enum HealthAuthorizationState: Equatable {
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

enum HealthAuthorizationAction: Equatable {
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

final class HealthAuthorizationManager {
    static let shared = HealthAuthorizationManager()

    let healthStore = HKHealthStore()

    private let workoutType = HKObjectType.workoutType()
    private let workoutEffortScoreType = HKQuantityType(.workoutEffortScore)
    private let activeEnergyType = HKQuantityType(.activeEnergyBurned)
    private let restingEnergyType = HKQuantityType(.basalEnergyBurned)
    private let bodyMassType = HKQuantityType(.bodyMass)

    private init() {}

    var isHealthDataAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    var currentAuthorizationState: HealthAuthorizationState {
        guard isHealthDataAvailable else { return .unavailable }

        let statuses = healthShareTypes.map { healthStore.authorizationStatus(for: $0) }

        if statuses.allSatisfy({ $0 == .sharingAuthorized }) { return .authorized }

        if statuses.contains(.sharingDenied) { return .denied }

        return .notDetermined
    }

    var canWriteWorkouts: Bool {
        guard isHealthDataAvailable else { return false }
        return healthStore.authorizationStatus(for: workoutType) == .sharingAuthorized
    }

    var canWriteWorkoutEffortScore: Bool {
        guard isHealthDataAvailable else { return false }
        return healthStore.authorizationStatus(for: workoutEffortScoreType) == .sharingAuthorized
    }

    var canWriteActiveEnergyBurned: Bool {
        guard isHealthDataAvailable else { return false }
        return healthStore.authorizationStatus(for: activeEnergyType) == .sharingAuthorized
    }

    var canWriteRestingEnergyBurned: Bool {
        guard isHealthDataAvailable else { return false }
        return healthStore.authorizationStatus(for: restingEnergyType) == .sharingAuthorized
    }

    var canWriteBodyMass: Bool {
        guard isHealthDataAvailable else { return false }
        return healthStore.authorizationStatus(for: bodyMassType) == .sharingAuthorized
    }

    var hasRequestedWorkoutAuthorization: Bool {
        guard isHealthDataAvailable else { return false }
        return healthStore.authorizationStatus(for: workoutType) != .notDetermined
    }

    var hasRequestedBodyMassAuthorization: Bool {
        guard isHealthDataAvailable else { return false }
        return healthStore.authorizationStatus(for: bodyMassType) != .notDetermined
    }

    func authorizationAction() async -> HealthAuthorizationAction {
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

    func requestAuthorization() async -> HealthAuthorizationState {
        guard isHealthDataAvailable else { return .unavailable }

        do {
            try await healthStore.requestAuthorization(toShare: healthShareTypes, read: healthReadTypes)
        } catch {
            print("HealthKit authorization request failed: \(error)")
        }

        return currentAuthorizationState
    }

    func metadata(for session: WorkoutSession) -> [String: Any] {
        ["Workout Title": session.title, HKMetadataKeyIndoorWorkout: true, HealthMetadataKeys.workoutSessionID: session.id.uuidString]
    }

    func metadata(for weightEntry: WeightEntry) -> [String: Any] {
        [HealthMetadataKeys.weightEntryID: weightEntry.id.uuidString, HKMetadataKeyWasUserEntered: true]
    }

    private var healthShareTypes: Set<HKSampleType> {
        [
            workoutType,
            workoutEffortScoreType,
            activeEnergyType,
            restingEnergyType,
            bodyMassType
        ]
    }

    private var healthReadTypes: Set<HKObjectType> {
        [
            workoutType,
            HKSeriesType.workoutRoute(),
            HKCharacteristicType(.dateOfBirth),
            HKCharacteristicType(.biologicalSex),
            HKQuantityType(.heartRate),
            activeEnergyType,
            restingEnergyType,
            HKQuantityType(.respiratoryRate),
            HKQuantityType(.flightsClimbed),
            HKQuantityType(.height),
            bodyMassType,
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.distanceCycling),
            HKQuantityType(.distanceSwimming),
            HKQuantityType(.distanceWheelchair),
            HKQuantityType(.distanceRowing),
            HKQuantityType(.distancePaddleSports),
            HKQuantityType(.distanceCrossCountrySkiing),
            HKQuantityType(.distanceDownhillSnowSports),
            HKQuantityType(.swimmingStrokeCount),
            HKQuantityType(.runningSpeed),
            HKQuantityType(.runningPower),
            HKQuantityType(.runningStrideLength),
            HKQuantityType(.runningGroundContactTime),
            HKQuantityType(.runningVerticalOscillation),
            HKQuantityType(.cyclingCadence),
            HKQuantityType(.cyclingPower),
            HKQuantityType(.cyclingSpeed),
            HKQuantityType(.physicalEffort),
            workoutEffortScoreType,
            HKQuantityType(.estimatedWorkoutEffortScore)
        ]
    }
}

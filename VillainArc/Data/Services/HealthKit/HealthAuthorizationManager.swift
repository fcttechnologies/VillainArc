import Foundation
import HealthKit

enum HealthAuthorizationState: Equatable {
    case unavailable
    case notDetermined
    case authorized
    case denied

    var statusText: String {
        switch self {
        case .unavailable:
            return "Unavailable"
        case .notDetermined:
            return "Not Connected"
        case .authorized:
            return "Connected"
        case .denied:
            return "Access Denied"
        }
    }

    var isAuthorized: Bool {
        self == .authorized
    }
}

enum HealthAuthorizationAction: Equatable {
    case requestAccess
    case openSettings
    case manageInSettings
    case unavailable

    var buttonTitle: String {
        switch self {
        case .requestAccess:
            return "Connect Apple Health"
        case .openSettings:
            return "Open Settings"
        case .manageInSettings:
            return "Manage In Settings"
        case .unavailable:
            return "Unavailable"
        }
    }

    var systemImage: String {
        switch self {
        case .requestAccess:
            return "heart.text.square"
        case .openSettings, .manageInSettings:
            return "gearshape"
        case .unavailable:
            return "heart.slash"
        }
    }
}

final class HealthAuthorizationManager {
    static let shared = HealthAuthorizationManager()

    let healthStore = HKHealthStore()

    private init() {}

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    var currentAuthorizationState: HealthAuthorizationState {
        guard isHealthDataAvailable else { return .unavailable }

        let workoutType = HKObjectType.workoutType()
        switch healthStore.authorizationStatus(for: workoutType) {
        case .notDetermined:
            return .notDetermined
        case .sharingAuthorized:
            return .authorized
        case .sharingDenied:
            return .denied
        @unknown default:
            return .denied
        }
    }

    func authorizationAction() async -> HealthAuthorizationAction {
        let state = currentAuthorizationState
        guard state != .unavailable else { return .unavailable }
        guard state != .authorized else { return .manageInSettings }

        do {
            let requestStatus = try await healthStore.statusForAuthorizationRequest(toShare: healthShareTypes, read: healthReadTypes)
            switch requestStatus {
            case .shouldRequest:
                return .requestAccess
            case .unnecessary, .unknown:
                return .openSettings
            @unknown default:
                return .openSettings
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
        [
            "Workout Title": session.title,
            HKMetadataKeyIndoorWorkout: true
        ]
    }

    private var healthShareTypes: Set<HKSampleType> {
        [HKObjectType.workoutType()]
    }

    private var healthReadTypes: Set<HKObjectType> {
        [HKObjectType.workoutType()]
    }
}

import Foundation
import HealthKit

enum WatchWorkoutAuthorizationState: Equatable {
    case unavailable
    case notDetermined
    case authorized
    case denied

    var statusMessage: String {
        switch self {
        case .unavailable:
            "Apple Health is unavailable on this Apple Watch."
        case .notDetermined:
            "Allow Apple Health on Apple Watch to start live metrics."
        case .authorized:
            "Connected"
        case .denied:
            "Allow Apple Health on Apple Watch to start live metrics."
        }
    }
}

enum WatchHealthAuthorizationManager {
    static let healthStore = HKHealthStore()

    static var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    static var currentAuthorizationState: WatchWorkoutAuthorizationState {
        guard isHealthDataAvailable else { return .unavailable }

        let statuses = shareTypes.map { healthStore.authorizationStatus(for: $0) }

        if statuses.allSatisfy({ $0 == .sharingAuthorized }) {
            return .authorized
        }

        if statuses.contains(.sharingDenied) {
            return .denied
        }

        return .notDetermined
    }

    static func requestAuthorizationIfNeeded() async -> WatchWorkoutAuthorizationState {
        guard isHealthDataAvailable else { return .unavailable }

        let currentState = currentAuthorizationState
        guard currentState != .authorized else { return currentState }

        do {
            try await healthStore.requestAuthorization(toShare: shareTypes, read: readTypes)
        } catch {
            print("Watch HealthKit authorization request failed: \(error)")
        }

        return currentAuthorizationState
    }

    private static var shareTypes: Set<HKSampleType> {
        [
            HealthKitCatalog.workoutType,
            HealthKitCatalog.workoutEffortScoreType,
            HealthKitCatalog.activeEnergyBurnedType,
            HealthKitCatalog.restingEnergyBurnedType
        ]
    }

    private static var readTypes: Set<HKObjectType> {
        [
            HealthKitCatalog.heartRateType,
            HealthKitCatalog.activeEnergyBurnedType,
            HealthKitCatalog.restingEnergyBurnedType
        ]
    }
}

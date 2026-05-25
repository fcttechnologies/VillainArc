import Foundation
import HealthKit

final class HealthStoreUpdateCoordinator {
    private enum ObserverKind: Sendable {
        case workout
        case weight
        case step
        case walkingRunningDistance
        case activeEnergy
        case restingEnergy
        case sleep
        case heartRate
        case restingHeartRate
        case walkingHeartRate
        case heartRateVariability
        case respiratoryRate
        case wristTemperature
        case dietaryWater

        var logLabel: String {
            switch self {
            case .workout: return "workout"
            case .weight: return "weight"
            case .step: return "step"
            case .walkingRunningDistance: return "walking/running distance"
            case .activeEnergy: return "active energy"
            case .restingEnergy: return "resting energy"
            case .sleep: return "sleep"
            case .heartRate: return "heart rate"
            case .restingHeartRate: return "resting heart rate"
            case .walkingHeartRate: return "walking heart rate"
            case .heartRateVariability: return "heart rate variability"
            case .respiratoryRate: return "respiratory rate"
            case .wristTemperature: return "wrist temperature"
            case .dietaryWater: return "dietary water"
            }
        }
    }

    static let shared = HealthStoreUpdateCoordinator()

    private var workoutObserverQuery: HKObserverQuery?
    private var weightObserverQuery: HKObserverQuery?
    private var stepObserverQuery: HKObserverQuery?
    private var walkingRunningDistanceObserverQuery: HKObserverQuery?
    private var activeEnergyObserverQuery: HKObserverQuery?
    private var restingEnergyObserverQuery: HKObserverQuery?
    private var sleepObserverQuery: HKObserverQuery?
    private var heartRateObserverQuery: HKObserverQuery?
    private var restingHeartRateObserverQuery: HKObserverQuery?
    private var walkingHeartRateObserverQuery: HKObserverQuery?
    private var heartRateVariabilityObserverQuery: HKObserverQuery?
    private var respiratoryRateObserverQuery: HKObserverQuery?
    private var wristTemperatureObserverQuery: HKObserverQuery?
    private var dietaryWaterObserverQuery: HKObserverQuery?
    private var isRefreshingBackgroundDelivery = false
    private var inFlightRefreshTask: Task<Void, Never>?

    private init() {}

    func installObserversIfNeeded() {
        guard HealthAuthorizationManager.isHealthDataAvailable else { return }
        let initializedObservers = [
            startWorkoutObserverIfNeeded() ? ObserverKind.workout.logLabel : nil,
            startWeightObserverIfNeeded() ? ObserverKind.weight.logLabel : nil,
            startStepObserverIfNeeded() ? ObserverKind.step.logLabel : nil,
            startWalkingRunningDistanceObserverIfNeeded() ? ObserverKind.walkingRunningDistance.logLabel : nil,
            startActiveEnergyObserverIfNeeded() ? ObserverKind.activeEnergy.logLabel : nil,
            startRestingEnergyObserverIfNeeded() ? ObserverKind.restingEnergy.logLabel : nil,
            startSleepObserverIfNeeded() ? ObserverKind.sleep.logLabel : nil,
            startHeartRateObserverIfNeeded() ? ObserverKind.heartRate.logLabel : nil,
            startRestingHeartRateObserverIfNeeded() ? ObserverKind.restingHeartRate.logLabel : nil,
            startWalkingHeartRateObserverIfNeeded() ? ObserverKind.walkingHeartRate.logLabel : nil,
            startHeartRateVariabilityObserverIfNeeded() ? ObserverKind.heartRateVariability.logLabel : nil,
            startRespiratoryRateObserverIfNeeded() ? ObserverKind.respiratoryRate.logLabel : nil,
            startWristTemperatureObserverIfNeeded() ? ObserverKind.wristTemperature.logLabel : nil,
            startDietaryWaterObserverIfNeeded() ? ObserverKind.dietaryWater.logLabel : nil
        ].compactMap(\.self)

        guard !initializedObservers.isEmpty else { return }
        AppLog.info("Registered Health observer queries: \(initializedObservers.joined(separator: ", ")).")
    }

    @discardableResult
    private func startWorkoutObserverIfNeeded() -> Bool {
        guard workoutObserverQuery == nil else { return false }
        let query = HKObserverQuery(sampleType: HealthKitCatalog.workoutType, predicate: nil) { query, completionHandler, error in
            guard let error else {
                nonisolated(unsafe) let completionHandler = completionHandler
                Task {
                    defer { completionHandler() }
                    await HealthSyncCoordinator.shared.syncWorkouts()
                }
                return
            }

            AppLog.error("Health workout observer failed: \(error.localizedDescription)")

            nonisolated(unsafe) let completionHandler = completionHandler
            let shouldReinstallObserver = Self.shouldReinstallObserver(after: error)
            let failedQueryID = ObjectIdentifier(query)
            Task { @MainActor in
                defer { completionHandler() }
                if shouldReinstallObserver {
                    HealthStoreUpdateCoordinator.shared.clearObserverIfMatching(.workout, failedQueryID: failedQueryID)
                }
            }
        }

        workoutObserverQuery = query
        HealthAuthorizationManager.healthStore.execute(query)
        return true
    }

    @discardableResult
    private func startWeightObserverIfNeeded() -> Bool {
        guard weightObserverQuery == nil else { return false }

        let query = HKObserverQuery(sampleType: HealthKitCatalog.bodyMassType, predicate: nil) { query, completionHandler, error in
            guard let error else {
                nonisolated(unsafe) let completionHandler = completionHandler
                Task {
                    defer { completionHandler() }
                    await HealthSyncCoordinator.shared.syncWeightEntries()
                }
                return
            }

            AppLog.error("Health weight observer failed: \(error.localizedDescription)")

            nonisolated(unsafe) let completionHandler = completionHandler
            let shouldReinstallObserver = Self.shouldReinstallObserver(after: error)
            let failedQueryID = ObjectIdentifier(query)
            Task { @MainActor in
                defer { completionHandler() }
                if shouldReinstallObserver {
                    HealthStoreUpdateCoordinator.shared.clearObserverIfMatching(.weight, failedQueryID: failedQueryID)
                }
            }
        }

        weightObserverQuery = query
        HealthAuthorizationManager.healthStore.execute(query)
        return true
    }

    @discardableResult
    private func startStepObserverIfNeeded() -> Bool {
        guard stepObserverQuery == nil else { return false }

        let query = HKObserverQuery(sampleType: HealthKitCatalog.stepCountType, predicate: nil) { query, completionHandler, error in
            guard let error else {
                nonisolated(unsafe) let completionHandler = completionHandler
                Task {
                    defer { completionHandler() }
                    await HealthDailyMetricsSync.shared.syncSteps()
                }
                return
            }

            AppLog.error("Health step observer failed: \(error.localizedDescription)")

            nonisolated(unsafe) let completionHandler = completionHandler
            let shouldReinstallObserver = Self.shouldReinstallObserver(after: error)
            let failedQueryID = ObjectIdentifier(query)
            Task { @MainActor in
                defer { completionHandler() }
                if shouldReinstallObserver {
                    HealthStoreUpdateCoordinator.shared.clearObserverIfMatching(.step, failedQueryID: failedQueryID)
                }
            }
        }

        stepObserverQuery = query
        HealthAuthorizationManager.healthStore.execute(query)
        return true
    }

    @discardableResult
    private func startWalkingRunningDistanceObserverIfNeeded() -> Bool {
        guard walkingRunningDistanceObserverQuery == nil else { return false }

        let query = HKObserverQuery(sampleType: HealthKitCatalog.walkingRunningDistanceType, predicate: nil) { query, completionHandler, error in
            guard let error else {
                nonisolated(unsafe) let completionHandler = completionHandler
                Task {
                    defer { completionHandler() }
                    await HealthDailyMetricsSync.shared.syncWalkingRunningDistance()
                }
                return
            }

            AppLog.error("Health walking/running distance observer failed: \(error.localizedDescription)")

            nonisolated(unsafe) let completionHandler = completionHandler
            let shouldReinstallObserver = Self.shouldReinstallObserver(after: error)
            let failedQueryID = ObjectIdentifier(query)
            Task { @MainActor in
                defer { completionHandler() }
                if shouldReinstallObserver {
                    HealthStoreUpdateCoordinator.shared.clearObserverIfMatching(.walkingRunningDistance, failedQueryID: failedQueryID)
                }
            }
        }

        walkingRunningDistanceObserverQuery = query
        HealthAuthorizationManager.healthStore.execute(query)
        return true
    }

    @discardableResult
    private func startActiveEnergyObserverIfNeeded() -> Bool {
        guard activeEnergyObserverQuery == nil else { return false }

        let query = HKObserverQuery(sampleType: HealthKitCatalog.activeEnergyBurnedType, predicate: nil) { query, completionHandler, error in
            guard let error else {
                nonisolated(unsafe) let completionHandler = completionHandler
                Task {
                    defer { completionHandler() }
                    await HealthDailyMetricsSync.shared.syncActiveEnergyBurned()
                }
                return
            }

            AppLog.error("Health active energy observer failed: \(error.localizedDescription)")

            nonisolated(unsafe) let completionHandler = completionHandler
            let shouldReinstallObserver = Self.shouldReinstallObserver(after: error)
            let failedQueryID = ObjectIdentifier(query)
            Task { @MainActor in
                defer { completionHandler() }
                if shouldReinstallObserver {
                    HealthStoreUpdateCoordinator.shared.clearObserverIfMatching(.activeEnergy, failedQueryID: failedQueryID)
                }
            }
        }

        activeEnergyObserverQuery = query
        HealthAuthorizationManager.healthStore.execute(query)
        return true
    }

    @discardableResult
    private func startRestingEnergyObserverIfNeeded() -> Bool {
        guard restingEnergyObserverQuery == nil else { return false }

        let query = HKObserverQuery(sampleType: HealthKitCatalog.restingEnergyBurnedType, predicate: nil) { query, completionHandler, error in
            guard let error else {
                nonisolated(unsafe) let completionHandler = completionHandler
                Task {
                    defer { completionHandler() }
                    await HealthDailyMetricsSync.shared.syncRestingEnergyBurned()
                }
                return
            }

            AppLog.error("Health resting energy observer failed: \(error.localizedDescription)")

            nonisolated(unsafe) let completionHandler = completionHandler
            let shouldReinstallObserver = Self.shouldReinstallObserver(after: error)
            let failedQueryID = ObjectIdentifier(query)
            Task { @MainActor in
                defer { completionHandler() }
                if shouldReinstallObserver {
                    HealthStoreUpdateCoordinator.shared.clearObserverIfMatching(.restingEnergy, failedQueryID: failedQueryID)
                }
            }
        }

        restingEnergyObserverQuery = query
        HealthAuthorizationManager.healthStore.execute(query)
        return true
    }

    @discardableResult
    private func startSleepObserverIfNeeded() -> Bool {
        guard sleepObserverQuery == nil else { return false }

        let query = HKObserverQuery(sampleType: HealthKitCatalog.sleepAnalysisType, predicate: nil) { query, completionHandler, error in
            guard let error else {
                nonisolated(unsafe) let completionHandler = completionHandler
                Task {
                    defer { completionHandler() }
                    await HealthSleepSync.shared.syncSleepNights()
                }
                return
            }

            AppLog.error("Health sleep observer failed: \(error.localizedDescription)")

            nonisolated(unsafe) let completionHandler = completionHandler
            let shouldReinstallObserver = Self.shouldReinstallObserver(after: error)
            let failedQueryID = ObjectIdentifier(query)
            Task { @MainActor in
                defer { completionHandler() }
                if shouldReinstallObserver {
                    HealthStoreUpdateCoordinator.shared.clearObserverIfMatching(.sleep, failedQueryID: failedQueryID)
                }
            }
        }

        sleepObserverQuery = query
        HealthAuthorizationManager.healthStore.execute(query)
        return true
    }

    @discardableResult
    private func startHeartRateObserverIfNeeded() -> Bool {
        guard heartRateObserverQuery == nil else { return false }

        let query = HKObserverQuery(sampleType: HealthKitCatalog.heartRateType, predicate: nil) { query, completionHandler, error in
            guard let error else {
                nonisolated(unsafe) let completionHandler = completionHandler
                Task {
                    defer { completionHandler() }
                    await HealthDailyMetricsSync.shared.syncHeartRate()
                }
                return
            }

            AppLog.error("Health heart rate observer failed: \(error.localizedDescription)")

            nonisolated(unsafe) let completionHandler = completionHandler
            let shouldReinstallObserver = Self.shouldReinstallObserver(after: error)
            let failedQueryID = ObjectIdentifier(query)
            Task { @MainActor in
                defer { completionHandler() }
                if shouldReinstallObserver {
                    HealthStoreUpdateCoordinator.shared.clearObserverIfMatching(.heartRate, failedQueryID: failedQueryID)
                }
            }
        }

        heartRateObserverQuery = query
        HealthAuthorizationManager.healthStore.execute(query)
        return true
    }

    @discardableResult
    private func startRestingHeartRateObserverIfNeeded() -> Bool {
        guard restingHeartRateObserverQuery == nil else { return false }

        let query = HKObserverQuery(sampleType: HealthKitCatalog.restingHeartRateType, predicate: nil) { query, completionHandler, error in
            guard let error else {
                nonisolated(unsafe) let completionHandler = completionHandler
                Task {
                    defer { completionHandler() }
                    await HealthDailyMetricsSync.shared.syncRestingHeartRate()
                }
                return
            }

            AppLog.error("Health resting heart rate observer failed: \(error.localizedDescription)")

            nonisolated(unsafe) let completionHandler = completionHandler
            let shouldReinstallObserver = Self.shouldReinstallObserver(after: error)
            let failedQueryID = ObjectIdentifier(query)
            Task { @MainActor in
                defer { completionHandler() }
                if shouldReinstallObserver {
                    HealthStoreUpdateCoordinator.shared.clearObserverIfMatching(.restingHeartRate, failedQueryID: failedQueryID)
                }
            }
        }

        restingHeartRateObserverQuery = query
        HealthAuthorizationManager.healthStore.execute(query)
        return true
    }

    @discardableResult
    private func startWalkingHeartRateObserverIfNeeded() -> Bool {
        guard walkingHeartRateObserverQuery == nil else { return false }

        let query = HKObserverQuery(sampleType: HealthKitCatalog.walkingHeartRateAverageType, predicate: nil) { query, completionHandler, error in
            guard let error else {
                nonisolated(unsafe) let completionHandler = completionHandler
                Task {
                    defer { completionHandler() }
                    await HealthDailyMetricsSync.shared.syncWalkingHeartRate()
                }
                return
            }

            AppLog.error("Health walking heart rate observer failed: \(error.localizedDescription)")

            nonisolated(unsafe) let completionHandler = completionHandler
            let shouldReinstallObserver = Self.shouldReinstallObserver(after: error)
            let failedQueryID = ObjectIdentifier(query)
            Task { @MainActor in
                defer { completionHandler() }
                if shouldReinstallObserver {
                    HealthStoreUpdateCoordinator.shared.clearObserverIfMatching(.walkingHeartRate, failedQueryID: failedQueryID)
                }
            }
        }

        walkingHeartRateObserverQuery = query
        HealthAuthorizationManager.healthStore.execute(query)
        return true
    }

    @discardableResult
    private func startHeartRateVariabilityObserverIfNeeded() -> Bool {
        guard heartRateVariabilityObserverQuery == nil else { return false }

        let query = HKObserverQuery(sampleType: HealthKitCatalog.heartRateVariabilitySDNNType, predicate: nil) { query, completionHandler, error in
            guard let error else {
                nonisolated(unsafe) let completionHandler = completionHandler
                Task {
                    defer { completionHandler() }
                    await HealthDailyMetricsSync.shared.syncHeartRateVariability()
                }
                return
            }

            AppLog.error("Health heart rate variability observer failed: \(error.localizedDescription)")

            nonisolated(unsafe) let completionHandler = completionHandler
            let shouldReinstallObserver = Self.shouldReinstallObserver(after: error)
            let failedQueryID = ObjectIdentifier(query)
            Task { @MainActor in
                defer { completionHandler() }
                if shouldReinstallObserver {
                    HealthStoreUpdateCoordinator.shared.clearObserverIfMatching(.heartRateVariability, failedQueryID: failedQueryID)
                }
            }
        }

        heartRateVariabilityObserverQuery = query
        HealthAuthorizationManager.healthStore.execute(query)
        return true
    }

    @discardableResult
    private func startRespiratoryRateObserverIfNeeded() -> Bool {
        guard respiratoryRateObserverQuery == nil else { return false }

        let query = HKObserverQuery(sampleType: HealthKitCatalog.respiratoryRateType, predicate: nil) { query, completionHandler, error in
            guard let error else {
                nonisolated(unsafe) let completionHandler = completionHandler
                Task {
                    defer { completionHandler() }
                    await HealthDailyMetricsSync.shared.syncRespiratoryRate()
                }
                return
            }

            AppLog.error("Health respiratory rate observer failed: \(error.localizedDescription)")

            nonisolated(unsafe) let completionHandler = completionHandler
            let shouldReinstallObserver = Self.shouldReinstallObserver(after: error)
            let failedQueryID = ObjectIdentifier(query)
            Task { @MainActor in
                defer { completionHandler() }
                if shouldReinstallObserver {
                    HealthStoreUpdateCoordinator.shared.clearObserverIfMatching(.respiratoryRate, failedQueryID: failedQueryID)
                }
            }
        }

        respiratoryRateObserverQuery = query
        HealthAuthorizationManager.healthStore.execute(query)
        return true
    }

    @discardableResult
    private func startWristTemperatureObserverIfNeeded() -> Bool {
        guard wristTemperatureObserverQuery == nil else { return false }

        let query = HKObserverQuery(sampleType: HealthKitCatalog.appleSleepingWristTemperatureType, predicate: nil) { query, completionHandler, error in
            guard let error else {
                nonisolated(unsafe) let completionHandler = completionHandler
                Task {
                    defer { completionHandler() }
                    await HealthDailyMetricsSync.shared.syncWristTemperature()
                }
                return
            }

            AppLog.error("Health wrist temperature observer failed: \(error.localizedDescription)")

            nonisolated(unsafe) let completionHandler = completionHandler
            let shouldReinstallObserver = Self.shouldReinstallObserver(after: error)
            let failedQueryID = ObjectIdentifier(query)
            Task { @MainActor in
                defer { completionHandler() }
                if shouldReinstallObserver {
                    HealthStoreUpdateCoordinator.shared.clearObserverIfMatching(.wristTemperature, failedQueryID: failedQueryID)
                }
            }
        }

        wristTemperatureObserverQuery = query
        HealthAuthorizationManager.healthStore.execute(query)
        return true
    }

    @discardableResult
    private func startDietaryWaterObserverIfNeeded() -> Bool {
        guard dietaryWaterObserverQuery == nil else { return false }

        let query = HKObserverQuery(sampleType: HealthKitCatalog.dietaryWaterType, predicate: nil) { query, completionHandler, error in
            guard let error else {
                nonisolated(unsafe) let completionHandler = completionHandler
                Task {
                    defer { completionHandler() }
                    await HealthSyncCoordinator.shared.syncHydrationEntries()
                }
                return
            }

            AppLog.error("Health dietary water observer failed: \(error.localizedDescription)")

            nonisolated(unsafe) let completionHandler = completionHandler
            let shouldReinstallObserver = Self.shouldReinstallObserver(after: error)
            let failedQueryID = ObjectIdentifier(query)
            Task { @MainActor in
                defer { completionHandler() }
                if shouldReinstallObserver {
                    HealthStoreUpdateCoordinator.shared.clearObserverIfMatching(.dietaryWater, failedQueryID: failedQueryID)
                }
            }
        }

        dietaryWaterObserverQuery = query
        HealthAuthorizationManager.healthStore.execute(query)
        return true
    }

    nonisolated private static func shouldReinstallObserver(after error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == HKErrorDomain,
              let code = HKError.Code(rawValue: nsError.code)
        else { return false }

        switch code {
        case .errorAuthorizationNotDetermined, .errorAuthorizationDenied:
            return true
        default:
            return false
        }
    }

    private func clearObserverIfMatching(_ kind: ObserverKind, failedQueryID: ObjectIdentifier) {
        switch kind {
        case .workout:
            clearObserverIfMatching(&workoutObserverQuery, kind: kind, failedQueryID: failedQueryID)
        case .weight:
            clearObserverIfMatching(&weightObserverQuery, kind: kind, failedQueryID: failedQueryID)
        case .step:
            clearObserverIfMatching(&stepObserverQuery, kind: kind, failedQueryID: failedQueryID)
        case .walkingRunningDistance:
            clearObserverIfMatching(&walkingRunningDistanceObserverQuery, kind: kind, failedQueryID: failedQueryID)
        case .activeEnergy:
            clearObserverIfMatching(&activeEnergyObserverQuery, kind: kind, failedQueryID: failedQueryID)
        case .restingEnergy:
            clearObserverIfMatching(&restingEnergyObserverQuery, kind: kind, failedQueryID: failedQueryID)
        case .sleep:
            clearObserverIfMatching(&sleepObserverQuery, kind: kind, failedQueryID: failedQueryID)
        case .heartRate:
            clearObserverIfMatching(&heartRateObserverQuery, kind: kind, failedQueryID: failedQueryID)
        case .restingHeartRate:
            clearObserverIfMatching(&restingHeartRateObserverQuery, kind: kind, failedQueryID: failedQueryID)
        case .walkingHeartRate:
            clearObserverIfMatching(&walkingHeartRateObserverQuery, kind: kind, failedQueryID: failedQueryID)
        case .heartRateVariability:
            clearObserverIfMatching(&heartRateVariabilityObserverQuery, kind: kind, failedQueryID: failedQueryID)
        case .respiratoryRate:
            clearObserverIfMatching(&respiratoryRateObserverQuery, kind: kind, failedQueryID: failedQueryID)
        case .wristTemperature:
            clearObserverIfMatching(&wristTemperatureObserverQuery, kind: kind, failedQueryID: failedQueryID)
        case .dietaryWater:
            clearObserverIfMatching(&dietaryWaterObserverQuery, kind: kind, failedQueryID: failedQueryID)
        }
    }

    private func clearObserverIfMatching(_ storedQuery: inout HKObserverQuery?, kind _: ObserverKind, failedQueryID: ObjectIdentifier) {
        guard let existingQuery = storedQuery, ObjectIdentifier(existingQuery) == failedQueryID else { return }
        HealthAuthorizationManager.healthStore.stop(existingQuery)
        storedQuery = nil
    }

    func refreshBackgroundDeliveryRegistration() async {
        guard !isRefreshingBackgroundDelivery else { return }

        isRefreshingBackgroundDelivery = true
        defer { isRefreshingBackgroundDelivery = false }

        if HealthAuthorizationManager.hasRequestedWorkoutAuthorization {
            do {
                try await HealthAuthorizationManager.healthStore.enableBackgroundDelivery(for: HealthKitCatalog.workoutType, frequency: .immediate)
            } catch { AppLog.error("Failed to enable HealthKit background delivery for workouts", error: error) }
        }

        if HealthAuthorizationManager.hasRequestedBodyMassAuthorization {
            do {
                try await HealthAuthorizationManager.healthStore.enableBackgroundDelivery(for: HealthKitCatalog.bodyMassType, frequency: .immediate)
            } catch { AppLog.error("Failed to enable HealthKit background delivery for body mass", error: error) }
        }

        if HealthAuthorizationManager.hasRequestedStepCountAuthorization {
            do {
                try await HealthAuthorizationManager.healthStore.enableBackgroundDelivery(for: HealthKitCatalog.stepCountType, frequency: .immediate)
            } catch { AppLog.error("Failed to enable HealthKit background delivery for steps", error: error) }
        }

        if HealthAuthorizationManager.hasRequestedWalkingRunningDistanceAuthorization {
            do {
                try await HealthAuthorizationManager.healthStore.enableBackgroundDelivery(for: HealthKitCatalog.walkingRunningDistanceType, frequency: .immediate)
            } catch { AppLog.error("Failed to enable HealthKit background delivery for walking/running distance", error: error) }
        }

        if HealthAuthorizationManager.hasRequestedActiveEnergyBurnedAuthorization {
            do {
                try await HealthAuthorizationManager.healthStore.enableBackgroundDelivery(for: HealthKitCatalog.activeEnergyBurnedType, frequency: .immediate)
            } catch { AppLog.error("Failed to enable HealthKit background delivery for active energy", error: error) }
        }

        if HealthAuthorizationManager.hasRequestedRestingEnergyBurnedAuthorization {
            do {
                try await HealthAuthorizationManager.healthStore.enableBackgroundDelivery(for: HealthKitCatalog.restingEnergyBurnedType, frequency: .immediate)
            } catch { AppLog.error("Failed to enable HealthKit background delivery for resting energy", error: error) }
        }

        if HealthAuthorizationManager.hasRequestedSleepAnalysisAuthorization {
            do {
                try await HealthAuthorizationManager.healthStore.enableBackgroundDelivery(for: HealthKitCatalog.sleepAnalysisType, frequency: .immediate)
            } catch { AppLog.error("Failed to enable HealthKit background delivery for sleep analysis", error: error) }
        }

        if HealthAuthorizationManager.hasRequestedHeartRateAuthorization {
            do {
                try await HealthAuthorizationManager.healthStore.enableBackgroundDelivery(for: HealthKitCatalog.heartRateType, frequency: .immediate)
            } catch { AppLog.error("Failed to enable HealthKit background delivery for heart rate", error: error) }
        }

        if HealthAuthorizationManager.hasRequestedRestingHeartRateAuthorization {
            do {
                try await HealthAuthorizationManager.healthStore.enableBackgroundDelivery(for: HealthKitCatalog.restingHeartRateType, frequency: .immediate)
            } catch { AppLog.error("Failed to enable HealthKit background delivery for resting heart rate", error: error) }
        }

        if HealthAuthorizationManager.hasRequestedWalkingHeartRateAuthorization {
            do {
                try await HealthAuthorizationManager.healthStore.enableBackgroundDelivery(for: HealthKitCatalog.walkingHeartRateAverageType, frequency: .immediate)
            } catch { AppLog.error("Failed to enable HealthKit background delivery for walking heart rate", error: error) }
        }

        if HealthAuthorizationManager.hasRequestedHeartRateVariabilityAuthorization {
            do {
                try await HealthAuthorizationManager.healthStore.enableBackgroundDelivery(for: HealthKitCatalog.heartRateVariabilitySDNNType, frequency: .immediate)
            } catch { AppLog.error("Failed to enable HealthKit background delivery for heart rate variability", error: error) }
        }

        if HealthAuthorizationManager.hasRequestedRespiratoryRateAuthorization {
            do {
                try await HealthAuthorizationManager.healthStore.enableBackgroundDelivery(for: HealthKitCatalog.respiratoryRateType, frequency: .immediate)
            } catch { AppLog.error("Failed to enable HealthKit background delivery for respiratory rate", error: error) }
        }

        if HealthAuthorizationManager.hasRequestedWristTemperatureAuthorization {
            do {
                try await HealthAuthorizationManager.healthStore.enableBackgroundDelivery(for: HealthKitCatalog.appleSleepingWristTemperatureType, frequency: .immediate)
            } catch { AppLog.error("Failed to enable HealthKit background delivery for wrist temperature", error: error) }
        }

        if HealthAuthorizationManager.hasRequestedDietaryWaterAuthorization {
            do {
                try await HealthAuthorizationManager.healthStore.enableBackgroundDelivery(for: HealthKitCatalog.dietaryWaterType, frequency: .immediate)
            } catch { AppLog.error("Failed to enable HealthKit background delivery for dietary water", error: error) }
        }
    }

    func syncNow() async {
        if let inFlightRefreshTask {
            await inFlightRefreshTask.value
            return
        }

        let task = Task {
            await HealthSyncCoordinator.shared.syncAll()
            await HealthExportCoordinator.shared.reconcilePendingExports()
        }

        inFlightRefreshTask = task
        defer { inFlightRefreshTask = nil }
        await task.value
    }
}

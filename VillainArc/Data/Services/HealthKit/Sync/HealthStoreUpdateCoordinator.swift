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

        var logLabel: String {
            switch self {
            case .workout: return "workout"
            case .weight: return "weight"
            case .step: return "step"
            case .walkingRunningDistance: return "walking/running distance"
            case .activeEnergy: return "active energy"
            case .restingEnergy: return "resting energy"
            case .sleep: return "sleep"
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
            startSleepObserverIfNeeded() ? ObserverKind.sleep.logLabel : nil
        ].compactMap(\.self)

        guard !initializedObservers.isEmpty else { return }
        print("Registered Health observer queries: \(initializedObservers.joined(separator: ", ")).")
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

            print("Health workout observer failed: \(error.localizedDescription)")

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

            print("Health weight observer failed: \(error.localizedDescription)")

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

            print("Health step observer failed: \(error.localizedDescription)")

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

            print("Health walking/running distance observer failed: \(error.localizedDescription)")

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

            print("Health active energy observer failed: \(error.localizedDescription)")

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

            print("Health resting energy observer failed: \(error.localizedDescription)")

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

            print("Health sleep observer failed: \(error.localizedDescription)")

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
            } catch { print("Failed to enable HealthKit background delivery for workouts: \(error)") }
        }

        if HealthAuthorizationManager.hasRequestedBodyMassAuthorization {
            do {
                try await HealthAuthorizationManager.healthStore.enableBackgroundDelivery(for: HealthKitCatalog.bodyMassType, frequency: .immediate)
            } catch { print("Failed to enable HealthKit background delivery for body mass: \(error)") }
        }

        if HealthAuthorizationManager.hasRequestedStepCountAuthorization {
            do {
                try await HealthAuthorizationManager.healthStore.enableBackgroundDelivery(for: HealthKitCatalog.stepCountType, frequency: .immediate)
            } catch { print("Failed to enable HealthKit background delivery for steps: \(error)") }
        }

        if HealthAuthorizationManager.hasRequestedWalkingRunningDistanceAuthorization {
            do {
                try await HealthAuthorizationManager.healthStore.enableBackgroundDelivery(for: HealthKitCatalog.walkingRunningDistanceType, frequency: .immediate)
            } catch { print("Failed to enable HealthKit background delivery for walking/running distance: \(error)") }
        }

        if HealthAuthorizationManager.hasRequestedActiveEnergyBurnedAuthorization {
            do {
                try await HealthAuthorizationManager.healthStore.enableBackgroundDelivery(for: HealthKitCatalog.activeEnergyBurnedType, frequency: .immediate)
            } catch { print("Failed to enable HealthKit background delivery for active energy: \(error)") }
        }

        if HealthAuthorizationManager.hasRequestedRestingEnergyBurnedAuthorization {
            do {
                try await HealthAuthorizationManager.healthStore.enableBackgroundDelivery(for: HealthKitCatalog.restingEnergyBurnedType, frequency: .immediate)
            } catch { print("Failed to enable HealthKit background delivery for resting energy: \(error)") }
        }

        if HealthAuthorizationManager.hasRequestedSleepAnalysisAuthorization {
            do {
                try await HealthAuthorizationManager.healthStore.enableBackgroundDelivery(for: HealthKitCatalog.sleepAnalysisType, frequency: .immediate)
            } catch { print("Failed to enable HealthKit background delivery for sleep analysis: \(error)") }
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
        HealthMetricWidgetReloader.reloadAllHealthMetrics()
    }
}

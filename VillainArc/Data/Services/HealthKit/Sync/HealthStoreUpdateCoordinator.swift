import Foundation
import HealthKit

final class HealthStoreUpdateCoordinator {
    static let shared = HealthStoreUpdateCoordinator()
    private let observedWorkoutType = HKObjectType.workoutType()
    private let observedWeightType = HKQuantityType(.bodyMass)
    private let observedStepType = HKQuantityType(.stepCount)
    private let observedWalkingRunningDistanceType = HKQuantityType(.distanceWalkingRunning)
    private let observedActiveEnergyType = HKQuantityType(.activeEnergyBurned)
    private let observedRestingEnergyType = HKQuantityType(.basalEnergyBurned)

    private var workoutObserverQuery: HKObserverQuery?
    private var weightObserverQuery: HKObserverQuery?
    private var stepObserverQuery: HKObserverQuery?
    private var walkingRunningDistanceObserverQuery: HKObserverQuery?
    private var activeEnergyObserverQuery: HKObserverQuery?
    private var restingEnergyObserverQuery: HKObserverQuery?
    private var isRefreshingBackgroundDelivery = false
    private var inFlightRefreshTask: Task<Void, Never>?

    private init() {}

    func installObserversIfNeeded() {
        guard HealthAuthorizationManager.isHealthDataAvailable else { return }
        startWorkoutObserverIfNeeded()
        startWeightObserverIfNeeded()
        startStepObserverIfNeeded()
        startWalkingRunningDistanceObserverIfNeeded()
        startActiveEnergyObserverIfNeeded()
        startRestingEnergyObserverIfNeeded()
    }

    private func startWorkoutObserverIfNeeded() {
        guard workoutObserverQuery == nil else { return }
        let query = HKObserverQuery(sampleType: observedWorkoutType, predicate: nil) { _, completionHandler, error in
            guard error == nil else {
                print("Health workout observer received an error: \(error!.localizedDescription)")
                completionHandler()
                return
            }

            nonisolated(unsafe) let completionHandler = completionHandler
            Task {
                defer { completionHandler() }
                await HealthSyncCoordinator.shared.syncWorkouts()
            }
        }

        workoutObserverQuery = query
        HealthAuthorizationManager.healthStore.execute(query)
    }

    private func startWeightObserverIfNeeded() {
        guard weightObserverQuery == nil else { return }

        let query = HKObserverQuery(sampleType: observedWeightType, predicate: nil) { _, completionHandler, error in
            guard error == nil else {
                print("Health weight observer received an error: \(error!.localizedDescription)")
                completionHandler()
                return
            }

            nonisolated(unsafe) let completionHandler = completionHandler
            Task {
                defer { completionHandler() }
                await HealthSyncCoordinator.shared.syncWeightEntries()
            }
        }

        weightObserverQuery = query
        HealthAuthorizationManager.healthStore.execute(query)
    }

    private func startStepObserverIfNeeded() {
        guard stepObserverQuery == nil else { return }

        let query = HKObserverQuery(sampleType: observedStepType, predicate: nil) { _, completionHandler, error in
            guard error == nil else {
                print("Health step observer received an error: \(error!.localizedDescription)")
                completionHandler()
                return
            }

            nonisolated(unsafe) let completionHandler = completionHandler
            Task {
                defer { completionHandler() }
                await HealthDailyMetricsSync.shared.syncSteps()
            }
        }

        stepObserverQuery = query
        HealthAuthorizationManager.healthStore.execute(query)
    }

    private func startWalkingRunningDistanceObserverIfNeeded() {
        guard walkingRunningDistanceObserverQuery == nil else { return }

        let query = HKObserverQuery(sampleType: observedWalkingRunningDistanceType, predicate: nil) { _, completionHandler, error in
            guard error == nil else {
                print("Health walking/running distance observer received an error: \(error!.localizedDescription)")
                completionHandler()
                return
            }

            nonisolated(unsafe) let completionHandler = completionHandler
            Task {
                defer { completionHandler() }
                await HealthDailyMetricsSync.shared.syncWalkingRunningDistance()
            }
        }

        walkingRunningDistanceObserverQuery = query
        HealthAuthorizationManager.healthStore.execute(query)
    }

    private func startActiveEnergyObserverIfNeeded() {
        guard activeEnergyObserverQuery == nil else { return }

        let query = HKObserverQuery(sampleType: observedActiveEnergyType, predicate: nil) { _, completionHandler, error in
            guard error == nil else {
                print("Health active energy observer received an error: \(error!.localizedDescription)")
                completionHandler()
                return
            }

            nonisolated(unsafe) let completionHandler = completionHandler
            Task {
                defer { completionHandler() }
                await HealthDailyMetricsSync.shared.syncActiveEnergyBurned()
            }
        }

        activeEnergyObserverQuery = query
        HealthAuthorizationManager.healthStore.execute(query)
    }

    private func startRestingEnergyObserverIfNeeded() {
        guard restingEnergyObserverQuery == nil else { return }

        let query = HKObserverQuery(sampleType: observedRestingEnergyType, predicate: nil) { _, completionHandler, error in
            guard error == nil else {
                print("Health resting energy observer received an error: \(error!.localizedDescription)")
                completionHandler()
                return
            }

            nonisolated(unsafe) let completionHandler = completionHandler
            Task {
                defer { completionHandler() }
                await HealthDailyMetricsSync.shared.syncRestingEnergyBurned()
            }
        }

        restingEnergyObserverQuery = query
        HealthAuthorizationManager.healthStore.execute(query)
    }

    func refreshBackgroundDeliveryRegistration() async {
        guard !isRefreshingBackgroundDelivery else { return }

        isRefreshingBackgroundDelivery = true
        defer { isRefreshingBackgroundDelivery = false }

        if HealthAuthorizationManager.hasRequestedWorkoutAuthorization {
            do {
                try await HealthAuthorizationManager.healthStore.enableBackgroundDelivery(for: observedWorkoutType, frequency: .immediate)
            } catch { print("Failed to enable HealthKit background delivery for workouts: \(error)") }
        }

        if HealthAuthorizationManager.hasRequestedBodyMassAuthorization {
            do {
                try await HealthAuthorizationManager.healthStore.enableBackgroundDelivery(for: observedWeightType, frequency: .immediate)
            } catch { print("Failed to enable HealthKit background delivery for body mass: \(error)") }
        }

        if HealthAuthorizationManager.hasRequestedStepCountAuthorization {
            do {
                try await HealthAuthorizationManager.healthStore.enableBackgroundDelivery(for: observedStepType, frequency: .immediate)
            } catch { print("Failed to enable HealthKit background delivery for steps: \(error)") }
        }

        if HealthAuthorizationManager.hasRequestedWalkingRunningDistanceAuthorization {
            do {
                try await HealthAuthorizationManager.healthStore.enableBackgroundDelivery(for: observedWalkingRunningDistanceType, frequency: .immediate)
            } catch { print("Failed to enable HealthKit background delivery for walking/running distance: \(error)") }
        }

        if HealthAuthorizationManager.hasRequestedActiveEnergyBurnedAuthorization {
            do {
                try await HealthAuthorizationManager.healthStore.enableBackgroundDelivery(for: observedActiveEnergyType, frequency: .immediate)
            } catch { print("Failed to enable HealthKit background delivery for active energy: \(error)") }
        }

        if HealthAuthorizationManager.hasRequestedRestingEnergyBurnedAuthorization {
            do {
                try await HealthAuthorizationManager.healthStore.enableBackgroundDelivery(for: observedRestingEnergyType, frequency: .immediate)
            } catch { print("Failed to enable HealthKit background delivery for resting energy: \(error)") }
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

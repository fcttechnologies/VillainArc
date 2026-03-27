import Foundation
import HealthKit

@MainActor final class HealthStoreUpdateCoordinator {
    static let shared = HealthStoreUpdateCoordinator()

    private let authorizationManager = HealthAuthorizationManager.shared
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
    private var inFlightSyncTask: Task<Void, Never>?

    private init() {}

    func start() {
        guard authorizationManager.isHealthDataAvailable else { return }
        startWorkoutObserverIfNeeded()
        startWeightObserverIfNeeded()
        startStepObserverIfNeeded()
        startWalkingRunningDistanceObserverIfNeeded()
        startActiveEnergyObserverIfNeeded()
        startRestingEnergyObserverIfNeeded()
    }

    private func startWorkoutObserverIfNeeded() {
        guard workoutObserverQuery == nil else { return }
        let query = HKObserverQuery(sampleType: observedWorkoutType, predicate: nil) { [weak self] _, completionHandler, error in
            guard error == nil else {
                print("Health workout observer received an error: \(error!.localizedDescription)")
                completionHandler()
                return
            }

            nonisolated(unsafe) let completionHandler = completionHandler
            Task { @MainActor in
                defer { completionHandler() }
                await self?.syncNow(reason: "HealthKit workout observer")
            }
        }

        workoutObserverQuery = query
        authorizationManager.healthStore.execute(query)
    }

    private func startWeightObserverIfNeeded() {
        guard weightObserverQuery == nil else { return }

        let query = HKObserverQuery(sampleType: observedWeightType, predicate: nil) { [weak self] _, completionHandler, error in
            guard error == nil else {
                print("Health weight observer received an error: \(error!.localizedDescription)")
                completionHandler()
                return
            }

            nonisolated(unsafe) let completionHandler = completionHandler
            Task { @MainActor in
                defer { completionHandler() }
                await self?.syncNow(reason: "HealthKit body mass observer")
            }
        }

        weightObserverQuery = query
        authorizationManager.healthStore.execute(query)
    }

    private func startStepObserverIfNeeded() {
        guard stepObserverQuery == nil else { return }

        let query = HKObserverQuery(sampleType: observedStepType, predicate: nil) { [weak self] _, completionHandler, error in
            guard error == nil else {
                print("Health step observer received an error: \(error!.localizedDescription)")
                completionHandler()
                return
            }

            nonisolated(unsafe) let completionHandler = completionHandler
            Task { @MainActor in
                defer { completionHandler() }
                await self?.syncNow(reason: "HealthKit step observer")
            }
        }

        stepObserverQuery = query
        authorizationManager.healthStore.execute(query)
    }

    private func startWalkingRunningDistanceObserverIfNeeded() {
        guard walkingRunningDistanceObserverQuery == nil else { return }

        let query = HKObserverQuery(sampleType: observedWalkingRunningDistanceType, predicate: nil) { [weak self] _, completionHandler, error in
            guard error == nil else {
                print("Health walking/running distance observer received an error: \(error!.localizedDescription)")
                completionHandler()
                return
            }

            nonisolated(unsafe) let completionHandler = completionHandler
            Task { @MainActor in
                defer { completionHandler() }
                await self?.syncNow(reason: "HealthKit walking/running distance observer")
            }
        }

        walkingRunningDistanceObserverQuery = query
        authorizationManager.healthStore.execute(query)
    }

    private func startActiveEnergyObserverIfNeeded() {
        guard activeEnergyObserverQuery == nil else { return }

        let query = HKObserverQuery(sampleType: observedActiveEnergyType, predicate: nil) { [weak self] _, completionHandler, error in
            guard error == nil else {
                print("Health active energy observer received an error: \(error!.localizedDescription)")
                completionHandler()
                return
            }

            nonisolated(unsafe) let completionHandler = completionHandler
            Task { @MainActor in
                defer { completionHandler() }
                await self?.syncNow(reason: "HealthKit active energy observer")
            }
        }

        activeEnergyObserverQuery = query
        authorizationManager.healthStore.execute(query)
    }

    private func startRestingEnergyObserverIfNeeded() {
        guard restingEnergyObserverQuery == nil else { return }

        let query = HKObserverQuery(sampleType: observedRestingEnergyType, predicate: nil) { [weak self] _, completionHandler, error in
            guard error == nil else {
                print("Health resting energy observer received an error: \(error!.localizedDescription)")
                completionHandler()
                return
            }

            nonisolated(unsafe) let completionHandler = completionHandler
            Task { @MainActor in
                defer { completionHandler() }
                await self?.syncNow(reason: "HealthKit resting energy observer")
            }
        }

        restingEnergyObserverQuery = query
        authorizationManager.healthStore.execute(query)
    }

    func refreshBackgroundDeliveryRegistration() async {
        start()

        guard !isRefreshingBackgroundDelivery else { return }

        isRefreshingBackgroundDelivery = true
        defer { isRefreshingBackgroundDelivery = false }

        if authorizationManager.hasRequestedWorkoutAuthorization {
            do {
                try await authorizationManager.healthStore.enableBackgroundDelivery(for: observedWorkoutType, frequency: .immediate)
                print("Enabled HealthKit background delivery for workouts.")
            } catch { print("Failed to enable HealthKit background delivery for workouts: \(error)") }
        }

        if authorizationManager.hasRequestedBodyMassAuthorization {
            do {
                try await authorizationManager.healthStore.enableBackgroundDelivery(for: observedWeightType, frequency: .immediate)
                print("Enabled HealthKit background delivery for body mass.")
            } catch { print("Failed to enable HealthKit background delivery for body mass: \(error)") }
        }

        if authorizationManager.hasRequestedStepCountAuthorization {
            do {
                try await authorizationManager.healthStore.enableBackgroundDelivery(for: observedStepType, frequency: .immediate)
                print("Enabled HealthKit background delivery for steps.")
            } catch { print("Failed to enable HealthKit background delivery for steps: \(error)") }
        }

        if authorizationManager.hasRequestedWalkingRunningDistanceAuthorization {
            do {
                try await authorizationManager.healthStore.enableBackgroundDelivery(for: observedWalkingRunningDistanceType, frequency: .immediate)
                print("Enabled HealthKit background delivery for walking/running distance.")
            } catch { print("Failed to enable HealthKit background delivery for walking/running distance: \(error)") }
        }

        if authorizationManager.hasRequestedActiveEnergyBurnedAuthorization {
            do {
                try await authorizationManager.healthStore.enableBackgroundDelivery(for: observedActiveEnergyType, frequency: .immediate)
                print("Enabled HealthKit background delivery for active energy.")
            } catch { print("Failed to enable HealthKit background delivery for active energy: \(error)") }
        }

        if authorizationManager.hasRequestedRestingEnergyBurnedAuthorization {
            do {
                try await authorizationManager.healthStore.enableBackgroundDelivery(for: observedRestingEnergyType, frequency: .immediate)
                print("Enabled HealthKit background delivery for resting energy.")
            } catch { print("Failed to enable HealthKit background delivery for resting energy: \(error)") }
        }
    }

    func syncNow() async {
        await syncNow(reason: "manual refresh")
        await HealthExportCoordinator.shared.reconcilePendingExports()
    }

    private func syncNow(reason: String) async {
        if let inFlightSyncTask {
            await inFlightSyncTask.value
            return
        }

        let task = Task { @MainActor in
            print("Starting HealthKit sync (\(reason)).")
            await HealthSyncCoordinator.shared.syncAll()
            print("Finished HealthKit sync (\(reason)).")
        }

        inFlightSyncTask = task
        defer { inFlightSyncTask = nil }
        await task.value
    }
}

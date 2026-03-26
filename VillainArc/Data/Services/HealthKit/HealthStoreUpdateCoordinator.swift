import Foundation
import HealthKit

@MainActor final class HealthStoreUpdateCoordinator {
    static let shared = HealthStoreUpdateCoordinator()

    private let authorizationManager = HealthAuthorizationManager.shared
    private let observedWorkoutType = HKObjectType.workoutType()
    private let observedWeightType = HKQuantityType(.bodyMass)

    private var workoutObserverQuery: HKObserverQuery?
    private var weightObserverQuery: HKObserverQuery?
    private var isRefreshingBackgroundDelivery = false
    private var inFlightSyncTask: Task<Void, Never>?

    private init() {}

    func start() {
        guard authorizationManager.isHealthDataAvailable else { return }
        startWorkoutObserverIfNeeded()
        startWeightObserverIfNeeded()
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

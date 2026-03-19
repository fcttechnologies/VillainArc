import Foundation
import HealthKit

@MainActor
final class HealthStoreUpdateCoordinator {
    static let shared = HealthStoreUpdateCoordinator()

    private let authorizationManager = HealthAuthorizationManager.shared
    private let observedWorkoutType = HKObjectType.workoutType()

    private var workoutObserverQuery: HKObserverQuery?
    private var isRefreshingBackgroundDelivery = false
    private var inFlightSyncTask: Task<Void, Never>?

    private init() {}

    func start() {
        guard authorizationManager.isHealthDataAvailable else { return }
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

    func refreshBackgroundDeliveryRegistration() async {
        start()

        guard authorizationManager.hasRequestedWorkoutAuthorization else { return }
        guard !isRefreshingBackgroundDelivery else { return }

        isRefreshingBackgroundDelivery = true
        defer { isRefreshingBackgroundDelivery = false }

        do {
            try await authorizationManager.healthStore.enableBackgroundDelivery(for: observedWorkoutType, frequency: .immediate)
            print("Enabled HealthKit background delivery for workouts.")
        } catch {
            print("Failed to enable HealthKit background delivery for workouts: \(error)")
        }
    }

    func syncNow() async {
        await syncNow(reason: "manual refresh")
        await HealthExportCoordinator.shared.reconcileCompletedSessions()
    }

    private func syncNow(reason: String) async {
        if let inFlightSyncTask {
            await inFlightSyncTask.value
            return
        }

        let task = Task { @MainActor in
            print("Starting HealthKit workout sync (\(reason)).")
            await HealthWorkoutSyncCoordinator.shared.syncWorkouts()
            print("Finished HealthKit workout sync (\(reason)).")
        }

        inFlightSyncTask = task
        defer { inFlightSyncTask = nil }
        await task.value
    }
}

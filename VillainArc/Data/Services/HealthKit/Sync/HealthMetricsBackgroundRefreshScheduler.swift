import BackgroundTasks
import Foundation

final class HealthMetricsBackgroundRefreshScheduler {
    static let shared = HealthMetricsBackgroundRefreshScheduler()
    static let taskIdentifier = "com.villainarc.health-metrics-refresh"

    private let refreshInterval: TimeInterval = 60 * 30

    private init() {}

    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskIdentifier, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }

            self.handle(task)
        }
    }

    func schedule() {
        guard HealthAuthorizationManager.isHealthDataAvailable else { return }

        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.taskIdentifier)

        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: refreshInterval)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule Health metric background refresh: \(error)")
        }
    }

    private func handle(_ task: BGAppRefreshTask) {
        schedule()

        let completionLock = NSLock()
        var didComplete = false

        func complete(_ success: Bool) {
            completionLock.lock()
            defer { completionLock.unlock() }
            guard didComplete == false else { return }
            didComplete = true
            task.setTaskCompleted(success: success)
        }

        var refreshTask: Task<Void, Never>?
        task.expirationHandler = {
            refreshTask?.cancel()
            complete(false)
        }

        refreshTask = Task {
            HealthStoreUpdateCoordinator.shared.installObserversIfNeeded()
            await HealthSyncCoordinator.shared.syncAll()
            complete(!Task.isCancelled)
        }
    }
}

import CoreData
import Foundation

enum CloudKitImportStatus: Equatable {
    case idle
    case waiting
    case importing
    case completed
    case failed(String)
}

final class CloudKitImportMonitor {
    static let shared = CloudKitImportMonitor()

    private(set) var status: CloudKitImportStatus = .idle

    private var observationTask: Task<Void, Never>?
    private var waiters: [CheckedContinuation<CloudKitImportStatus, Never>] = []

    private init() {}

    func start() {
        guard observationTask == nil else { return }

        if status == .idle { status = .waiting }

        observationTask = Task { @MainActor [weak self] in
            guard let self else { return }

            for await notification in NotificationCenter.default.notifications(named: NSPersistentCloudKitContainer.eventChangedNotification) { handle(notification) }
        }
    }

    func prepareForBootstrapWait() {
        start()

        if case .failed = status { status = .waiting }
    }

    func waitForImportCompletion() async -> CloudKitImportStatus {
        prepareForBootstrapWait()

        switch status {
        case .completed, .failed: return status
        case .idle, .waiting, .importing: return await withCheckedContinuation { continuation in waiters.append(continuation) }
        }
    }

    private func handle(_ notification: Notification) {
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else { return }

        guard event.type == .import else { return }

        if event.endDate == nil {
            status = .importing
            return
        }

        if let error = event.error {
            print("⚠️ CloudKit import completed with error: \(error)")
            finish(with: .failed(error.localizedDescription))
        } else {
            print("✅ CloudKit import complete - safe to seed exercises")
            finish(with: .completed)
        }
    }

    private func finish(with status: CloudKitImportStatus) {
        self.status = status

        let pendingWaiters = waiters
        waiters.removeAll()

        for waiter in pendingWaiters { waiter.resume(returning: status) }
    }
}

import Foundation
import Observation
import WatchConnectivity
import WatchKit

// The watch side of the companion sync. The iPhone app is the source of truth —
// this store receives `WatchSyncPayload` snapshots over the application context,
// exposes them to the views, and sends `WatchSyncCommand`s back (receiving a fresh
// payload in each reply). It also plays the wrist haptic when a running rest timer
// completes while the watch app is frontmost.
@Observable final class WatchSessionStore: NSObject {
    private(set) var payload: WatchSyncPayload?
    private(set) var isPhoneReachable = false
    private(set) var hasReceivedData = false

    @ObservationIgnored private var hasActivated = false
    @ObservationIgnored private var restHapticTask: Task<Void, Never>?

    func activate() {
        guard WCSession.isSupported() else { return }
        guard !hasActivated else { return }
        hasActivated = true
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func requestSync() {
        send(.requestSync)
    }

    func send(_ command: WatchSyncCommand) {
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        guard let dictionary = WatchSync.encodeCommand(command) else { return }
        // Both handlers run on a WatchConnectivity background queue — they must be
        // @Sendable (NOT implicitly MainActor under the MainActor-default isolation)
        // or the runtime's executor assertion traps on delivery.
        session.sendMessage(dictionary, replyHandler: { @Sendable [weak self] reply in
            guard let payload = WatchSync.decodePayload(from: reply) else { return }
            Task { @MainActor in
                self?.apply(payload)
            }
        }, errorHandler: { @Sendable _ in
            // The phone is unreachable right now; the next application-context
            // push reconciles state. Reachability is surfaced in the UI.
        })
    }

    fileprivate func apply(_ payload: WatchSyncPayload) {
        let previousEndDate = self.payload?.restTimer?.endDate
        self.payload = payload
        hasReceivedData = true
        if payload.restTimer?.endDate != previousEndDate {
            rescheduleRestCompletionHaptic()
        }
    }

    fileprivate func updateReachability(_ reachable: Bool) {
        isPhoneReachable = reachable
    }

    // MARK: - Rest-timer completion haptic

    private func rescheduleRestCompletionHaptic() {
        restHapticTask?.cancel()
        guard let endDate = payload?.restTimer?.endDate, endDate > .now else {
            restHapticTask = nil
            return
        }
        restHapticTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(endDate.timeIntervalSinceNow))
            guard !Task.isCancelled else { return }
            guard self?.payload?.restTimer?.endDate == endDate else { return }
            WKInterfaceDevice.current().play(.notification)
        }
    }
}

extension WatchSessionStore: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        guard activationState == .activated else { return }
        // The last-pushed context is persisted across launches — apply it so the UI
        // has state immediately, then ask the phone for a fresh snapshot.
        let storedPayload = WatchSync.decodePayload(from: session.receivedApplicationContext)
        let reachable = session.isReachable
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let storedPayload {
                self.apply(storedPayload)
            }
            self.updateReachability(reachable)
            self.requestSync()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let payload = WatchSync.decodePayload(from: applicationContext) else { return }
        Task { @MainActor [weak self] in
            self?.apply(payload)
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor [weak self] in
            self?.updateReachability(reachable)
        }
    }
}

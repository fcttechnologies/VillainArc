import FCTServerSync
import FCTServerSyncTesting
import Foundation
import Testing

@testable import VillainArc

/// A transport that holds each pull open long enough for a second trigger to land on top of it,
/// and records whether the cycle it belonged to was cancelled out from under it.
///
/// `Task.sleep` throwing `CancellationError` is the detector: a pull that is merely slow finishes,
/// and a pull whose enclosing cycle was cancelled does not. That is exactly the distinction the
/// production symptom shows as `NSURLErrorCancelled (-999)` on `rest/v1/rpc/sync_pull`.
private nonisolated final class SlowTransport: SyncTransport, @unchecked Sendable {
    private let inner: FakeTransport
    private let lock = NSLock()
    private var _pullsStarted = 0
    private var _pullsCancelled = 0

    var pullsStarted: Int { lock.withLock { _pullsStarted } }
    var pullsCancelled: Int { lock.withLock { _pullsCancelled } }

    init(server: FakeSyncServer) {
        inner = FakeTransport(server: server)
    }

    func push(schemaVersion: String, records: [PushRecord]) async throws -> [PushVerdict] {
        try await inner.push(schemaVersion: schemaVersion, records: records)
    }

    func pull(schemaVersion: String, table: String, cursor: Int64, pageLimit: Int) async throws -> PullEnvelope {
        lock.withLock { _pullsStarted += 1 }
        do {
            try await Task.sleep(for: .milliseconds(120))
        } catch {
            lock.withLock { _pullsCancelled += 1 }
            throw error
        }
        return try await inner.pull(
            schemaVersion: schemaVersion, table: table, cursor: cursor, pageLimit: pageLimit
        )
    }
}

/// The debounce's one hard rule.
///
/// Coalescing a burst of triggers into one cycle is right; **cancelling a cycle that has already
/// started is not**, and the two are one line apart. Arming the debounce cancels the wait a
/// previous trigger armed, and if that wait had already stopped sleeping and begun syncing, the
/// cancellation tears down the HTTP request inside it.
///
/// That matters most exactly where it is least visible: the account's first pull after a sign-in.
/// The applier's own save fires `LocalSaveTrigger`, so **every page of a restore schedules a
/// debounce that kills the restore that produced it** — the cycle restarts, applies a little more,
/// saves, and cancels itself again. It converges only because each attempt makes some progress,
/// and on a slower link or a larger account it can outlive `restoreAccountData`'s own timeout and
/// report "couldn't reach your account" for an account that answered every time.
///
/// The harness's other suites configure no triggers at all, which is why this path had no
/// coverage.
@Suite("Sync — the debounce must not cancel a running cycle", .serialized)
struct VASyncDebounceTests {
    @Test @MainActor
    func aTriggerArrivingMidCycleDoesNotCancelTheCycleInFlight() async throws {
        let trigger = ManualTrigger()
        let server = FakeSyncServer()
        let transport = SlowTransport(server: server)
        let harness = try VASyncFaultHarness(triggers: [trigger], transport: transport)

        await harness.enroll()

        // A burst, spaced so each one lands while the cycle the previous one started is still in
        // its pull. This is the shape a restore produces on its own: one save per applied page.
        for _ in 0..<6 {
            trigger.fire()
            try await Task.sleep(for: .milliseconds(300))
        }
        try await Task.sleep(for: .milliseconds(800))

        #expect(transport.pullsStarted > 0, "the harness never reached the transport")
        #expect(
            transport.pullsCancelled == 0,
            """
            \(transport.pullsCancelled) of \(transport.pullsStarted) pulls were cancelled \
            mid-flight. A later trigger must coalesce into the running cycle, never tear it down.
            """
        )

        // VA's schema is 25 tables, so a cycle outlives the burst that started it. Let the last
        // one drain rather than pulling the harness's store out from under it.
        try await settle(transport)
    }

    /// Wait until no pull has started for 400ms — the engine has stopped on its own.
    private func settle(_ transport: SlowTransport) async throws {
        var quiet = 0
        var previous = -1
        var polls = 0
        while quiet < 2, polls < 60 {
            try await Task.sleep(for: .milliseconds(200))
            let started = transport.pullsStarted
            quiet = started == previous ? quiet + 1 : 0
            previous = started
            polls += 1
        }
    }
}

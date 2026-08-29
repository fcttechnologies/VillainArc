import FCTServerSync
import FCTServerSyncTesting
import Foundation
import Testing

@testable import VillainArc

/// A wire that fails one pull — arming the backoff — then answers slowly, and asks for one more
/// pass from inside the recovering cycle, the way an applier's own save does when a pull lands
/// rows.
///
/// `Task.sleep` throwing `CancellationError` is the detector, the same one the debounce suite
/// uses: a pull that is merely slow finishes, and a pull whose enclosing cycle was cancelled does
/// not.
private nonisolated final class RetryTransport: SyncTransport, @unchecked Sendable {
    private let inner: FakeTransport
    private let trigger: ManualTrigger
    private let lock = NSLock()
    private var _pullsStarted = 0
    private var _pullsCancelled = 0
    private var _failuresRemaining: Int
    private var _triggerFired = false

    /// Pulls that reached the wire. The failed one throws before it gets this far, so a non-zero
    /// count is itself the proof that the retry fired.
    var pullsStarted: Int { lock.withLock { _pullsStarted } }
    var pullsCancelled: Int { lock.withLock { _pullsCancelled } }

    init(server: FakeSyncServer, trigger: ManualTrigger, failuresBeforeSuccess: Int = 1) {
        inner = FakeTransport(server: server)
        self.trigger = trigger
        _failuresRemaining = failuresBeforeSuccess
    }

    func push(schemaVersion: String, records: [PushRecord]) async throws -> [PushVerdict] {
        try await inner.push(schemaVersion: schemaVersion, records: records)
    }

    func pull(schemaVersion: String, table: String, cursor: Int64, pageLimit: Int) async throws -> PullEnvelope {
        if consumeFailure() {
            throw SyncTransportError.connectivity("injected: no route to host")
        }
        lock.withLock { _pullsStarted += 1 }
        requestAnotherPassOnce()
        do {
            try await Task.sleep(for: .milliseconds(120))
        } catch {
            lock.withLock { _pullsCancelled += 1 }
            // The raw `CancellationError` is deliberate. Dressing it as `.connectivity` — which is
            // what `NSURLErrorCancelled` becomes through `PostgRESTTransport`, and so the obvious
            // "more faithful" edit — would put the engine back in `.offline(retryingIn:)` and arm
            // a fresh 1 s · 2ⁿ backoff inside the quiet window `settled()` reads as the end.
            throw error
        }
        return try await inner.pull(
            schemaVersion: schemaVersion, table: table, cursor: cursor, pageLimit: pageLimit
        )
    }

    private func consumeFailure() -> Bool {
        lock.withLock {
            guard _failuresRemaining > 0 else { return false }
            _failuresRemaining -= 1
            return true
        }
    }

    /// Ask for one more pass, once, from inside the first healthy cycle. Firing it off the wire
    /// rather than on a timer is what makes the second pass certain: the request lands while the
    /// cycle is provably still in a pull, which is the state the defect needs.
    private func requestAnotherPassOnce() {
        let shouldFire = lock.withLock {
            guard !_triggerFired else { return false }
            _triggerFired = true
            return true
        }
        if shouldFire { trigger.fire() }
    }

    /// Wait for the retry to reach the wire, and then for the cycles to stop — polled in two
    /// phases rather than slept through.
    ///
    /// The phases are not interchangeable. Between the failed cycle and the retry the wire is
    /// quiet for the whole backoff, so a stability poll started there would read that gap as the
    /// end and sample the counters before the cycle under test had run at all. A fixed wait is
    /// worse than useless: calibrated on the broken run it expires mid-pull on the green one,
    /// where the cycles survive to start more pulls, and pulls the harness's store out from under
    /// a live cycle.
    func settled() async -> Bool {
        let deadline = ContinuousClock.now + .seconds(30)
        while ContinuousClock.now < deadline, pullsStarted == 0 {
            try? await Task.sleep(for: .milliseconds(50))
        }
        guard pullsStarted > 0 else { return false }

        var stable = 0
        var previous = -1
        while ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(150))
            let current = pullsStarted
            stable = current == previous ? stable + 1 : 0
            previous = current
            if stable >= 4 { return true }
        }
        return false
    }
}

/// The backoff retry's one hard rule — the debounce's rule, one layer up.
///
/// `scheduleRetry` is the last statement of `syncNow()`'s `repeat … while syncAgain` body, so when
/// the task running that loop *is* the retry task, the `retryTask?.cancel()` at the top cancels
/// the task currently executing. And it sits before the `.offline` guard, so it fires on every
/// result, a success included. What then runs cancelled is the second pass: the staging sweep, the
/// blob drain and `engine.sync()`, torn down mid-flight.
///
/// That is the coming-back-into-signal path. A device that failed a cycle offline waits out the
/// backoff, wakes, syncs — and the moment that recovering cycle needs a second pass (a pull that
/// landed rows asks for one, which is the ordinary shape of a restore) it cancels itself. It is
/// the cycle a recovering device most needs to finish, and the one a retry ran.
@Suite("Sync — the backoff retry must release its handle before it syncs")
struct VASyncRetryTests {
    @Test @MainActor
    func aRetryCycleDoesNotCancelItselfWhenItNeedsASecondPass() async throws {
        let trigger = ManualTrigger()
        let transport = RetryTransport(server: FakeSyncServer(), trigger: trigger)
        let harness = try VASyncFaultHarness(triggers: [trigger], transport: transport)

        // Enrolling runs a cycle, and this one fails on the wire: the engine goes
        // `.offline(retryingIn:)` and `scheduleRetry` arms the retry task. One failure is a 2⁰
        // backoff, so the retry wakes about a second later — with the wire healthy.
        await harness.enroll()

        try #require(
            await transport.settled(),
            "the retry never reached the wire, or the cycles never stopped starting pulls"
        )

        #expect(transport.pullsStarted > 0, "the retry path never reached the transport")
        #expect(
            transport.pullsCancelled == 0,
            """
            \(transport.pullsCancelled) of \(transport.pullsStarted) pulls were cancelled \
            mid-flight. The retry task must release its handle once past its wait, so the \
            `scheduleRetry` at the end of its own cycle finds nothing to tear down.
            """
        )
    }
}

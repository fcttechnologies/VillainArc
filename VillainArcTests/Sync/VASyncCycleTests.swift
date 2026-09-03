import FCTServerSync
import FCTServerSyncTesting
import Foundation
import Testing

@testable import VillainArc

/// A socket that answers the join and then hands over whatever the test queued behind it, in
/// order. Everything the nudge rung's own state machine does with a refusal, a drop or the
/// reconnect ladder is proven in `FCTServerSync`; what is proven here is only that Villain Arc
/// wires the stream to a cycle.
private nonisolated final class StubSocket: SyncSocket, @unchecked Sendable {
    private let lock = NSLock()
    private var inbound: [String]
    private var waiter: CheckedContinuation<String?, Never>?
    private var closed = false
    private var _cancelled = false

    var wasCancelled: Bool { lock.withLock { _cancelled } }

    init(frames: [String]) { inbound = frames }

    func send(_ text: String) async throws {
        try lock.withLock { if closed { throw CancellationError() } }
    }

    func receive() async throws -> String {
        let next: String? = await withCheckedContinuation { continuation in
            let ready: String?? = lock.withLock {
                if closed { return .some(nil) }
                if !inbound.isEmpty { return .some(inbound.removeFirst()) }
                waiter = continuation
                return nil
            }
            if let ready { continuation.resume(returning: ready) }
        }
        guard let next else { throw SyncNudgeError.socketLost("stub closed") }
        return next
    }

    func cancel() {
        let waiter: CheckedContinuation<String?, Never>? = lock.withLock {
            _cancelled = true
            closed = true
            let held = self.waiter
            self.waiter = nil
            return held
        }
        waiter?.resume(returning: nil)
    }
}

private nonisolated final class StubSocketFactory: SyncSocketFactory, @unchecked Sendable {
    private let lock = NSLock()
    private var made: [StubSocket] = []

    var sockets: [StubSocket] { lock.withLock { made } }

    func connect(to url: URL) -> any SyncSocket {
        let socket = StubSocket(frames: [Self.joinReply, Self.nudge])
        lock.withLock { made.append(socket) }
        return socket
    }

    static let joinReply =
        #"{"topic":"realtime:t","event":"phx_reply","ref":"1","payload":{"status":"ok","response":{}}}"#
    static let nudge =
        #"{"topic":"realtime:t","event":"broadcast","payload":{"type":"broadcast","event":"sync","payload":{"max_updated_seq":7}}}"#
}

/// An admission door that always grants. What a refusal, a poll grant or a lost renewal does is
/// the channel's own property and is proven in `FCTServerSync`; what this suite needs is only for
/// the join to be reached at all, which the live door — unreachable from a test process — would
/// answer by polling instead.
private nonisolated struct GrantingLeasing: SyncChannelLeasing {
    func leaseChannelSlot(device: UUID) async throws -> SyncChannelLease {
        .realtime(leaseSeconds: 600, pollSeconds: 30)
    }

    func releaseChannelSlot(device: UUID) async {}
}

/// The rungs into a cycle: what each one costs and what it asks for.
///
/// The engine's own `push`/`full` split is `FCTServerSync`'s property. What belongs to this app is
/// which rung spends which kind, and how many cycles one event is worth — the half that is
/// invisible from inside the package and shows up as an app that syncs three times per
/// foregrounding.
@Suite("Sync — the rungs into a cycle", .serialized)
struct VASyncCycleTests {

    /// Wait for the server to have answered `count` read calls, or give up.
    private func pullAll(reaches count: Int, on server: FakeSyncServer) async -> Int {
        let deadline = ContinuousClock.now + .seconds(5)
        var seen = await server.pullAllCallCount
        while seen < count, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(50))
            seen = await server.pullAllCallCount
        }
        return seen
    }

    /// **One foregrounding is one cycle, and one cycle is one round trip.**
    ///
    /// Both halves are cheap to lose and silent when lost. A foreground that also pulsed a trigger
    /// ran the debounced cycle *and* the direct one, and a read path that paged per table spent a
    /// call per declared table — twenty-five of them here — on an account that had nothing to say.
    /// Neither is visible from the app: it simply syncs, correctly, more often than it needs to.
    @Test @MainActor
    func aForegroundingIsOneCycleAndOneRoundTrip() async throws {
        let harness = try VASyncFaultHarness()
        await harness.enroll()

        #expect(
            await harness.server.pullAllCallCount == 1,
            "the enrolling cycle read the whole declaration in one call"
        )

        harness.sync.foregrounded()
        // Comfortably past the 250 ms debounce, so a second cycle armed by this foregrounding
        // would have run and been counted by now.
        try await Task.sleep(for: .milliseconds(900))

        let reads = await harness.server.pullAllCallCount
        #expect(reads == 2, "a foregrounding is one cycle: \(reads) reads for two cycles")
    }

    /// A nudge is rung 2, and it asks for a **full** cycle: the whole content of the message is
    /// "something changed", so the pull is the only thing that can act on it.
    @Test @MainActor
    func aNudgeSpendsAFullCycle() async throws {
        let sockets = StubSocketFactory()
        let stateFile = SyncStateFile(
            url: FileManager.default.temporaryDirectory
                .appendingPathComponent("VANudge-\(UUID().uuidString).json")
        )
        let channel = SyncNudgeChannel(
            baseURL: URL(string: "https://project.supabase.co")!,
            publishableKey: "pk",
            account: FakeAccount(accountID: UUID()),
            stateFile: stateFile,
            sockets: sockets,
            leasing: GrantingLeasing()
        )
        let harness = try VASyncFaultHarness(nudges: channel)
        await harness.enroll()

        #expect(
            await pullAll(reaches: 2, on: harness.server) == 2,
            "the broadcast never reached a cycle"
        )

        // Backgrounding releases the socket rather than leaving it to the system.
        harness.sync.backgrounded()
        try await Task.sleep(for: .milliseconds(200))
        #expect(sockets.sockets.first?.wasCancelled == true, "backgrounding must release the socket")
    }
}

import Foundation
import Testing
import os

@testable import VillainArc

/// The invariant the HealthKit observers rest on, checked where it actually lives.
///
/// Fourteen observers hand HealthKit's completion block to a `HealthObserverCompletion` and call
/// `finish()` from a `defer`. HealthKit's contract has no slack in either direction — an observer
/// that never completes stops receiving notifications, and one that completes twice calls a block
/// HealthKit already released — and none of it is observable on a simulator, where real observers
/// never fire. So the guarantee is proven here, on the type, rather than inferred from the
/// installers reading correctly.
struct HealthObserverCompletionTests {

    @Test
    func finishCallsTheHandler() {
        let calls = OSAllocatedUnfairLock(initialState: 0)
        let completion = HealthObserverCompletion { calls.withLock { $0 += 1 } }

        completion.finish()

        #expect(calls.withLock { $0 } == 1)
    }

    /// A block called twice is a block called after HealthKit released it. The wrapper has to
    /// swallow the second call rather than trust every caller to make exactly one.
    @Test
    func repeatedFinishesCallTheHandlerOnlyOnce() {
        let calls = OSAllocatedUnfairLock(initialState: 0)
        let completion = HealthObserverCompletion { calls.withLock { $0 += 1 } }

        for _ in 0 ..< 10 { completion.finish() }

        #expect(calls.withLock { $0 } == 1)
    }

    /// The case the type exists for: the error path and the success path both end in a `defer`, on
    /// two different executors, and nothing in the language stops a future edit from letting both
    /// run. Serial calls would pass on a plain `Bool` that a race walks straight through.
    @Test
    func concurrentFinishesCallTheHandlerExactlyOnce() async {
        let calls = OSAllocatedUnfairLock(initialState: 0)
        let completion = HealthObserverCompletion { calls.withLock { $0 += 1 } }

        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 64 {
                group.addTask { completion.finish() }
            }
        }

        #expect(calls.withLock { $0 } == 1)
    }

    /// Once is implemented by giving the block up, not by guarding a block it keeps: a wrapper that
    /// held HealthKit's block after firing would retain whatever the block captured for as long as
    /// the observer lives, once per notification.
    @Test
    func finishReleasesTheHandler() {
        final class Captured { var wasCalled = false }
        weak var weakCaptured: Captured?

        let completion: HealthObserverCompletion = {
            let captured = Captured()
            weakCaptured = captured
            return HealthObserverCompletion { captured.wasCalled = true }
        }()

        #expect(weakCaptured != nil, "the block was released before it was ever called")

        completion.finish()

        #expect(weakCaptured == nil, "the wrapper still holds HealthKit's block after calling it")
    }

    /// The crossing itself, which is the whole reason the type exists: built where HealthKit hands
    /// the block over, carried into a `Task`, fired from the `defer` there — the installers' exact
    /// shape.
    @Test
    func itCarriesTheHandlerIntoATaskAndFiresFromADefer() async {
        let calls = OSAllocatedUnfairLock(initialState: 0)
        let completion = HealthObserverCompletion { calls.withLock { $0 += 1 } }

        await Task.detached {
            defer { completion.finish() }
            try? await Task.sleep(for: .milliseconds(1))
        }.value

        #expect(calls.withLock { $0 } == 1)
    }
}

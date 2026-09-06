import HealthKit
import os

/// The one place a HealthKit observer's completion handler crosses into a `Task`.
///
/// `HKObserverQuery`'s update handler is `@Sendable`, but the completion handler it is passed is a
/// bare `@convention(block) () -> Void` carrying no `Sendable` conformance — while every sync it
/// gates has to run in a `Task`. Wrapping the block here is what buys the crossing: it is reachable
/// only through this lock, so no two threads can be inside it, and `finish()` takes it out of the
/// lock before calling it, so however many times and from however many threads `finish()` is
/// called, HealthKit's block runs exactly once.
///
/// Exactly once is HealthKit's own requirement, in both directions: an observer that never
/// completes stops receiving notifications, and one that completes twice is calling a block
/// HealthKit has already released.
nonisolated struct HealthObserverCompletion: Sendable {
    private let pendingHandler: OSAllocatedUnfairLock<HKObserverQueryCompletionHandler?>

    init(_ handler: @escaping HKObserverQueryCompletionHandler) {
        pendingHandler = OSAllocatedUnfairLock(uncheckedState: handler)
    }

    /// Tells HealthKit the notification has been handled. The first call delivers it; every later
    /// one does nothing.
    ///
    /// The block is claimed under the lock and called outside it: HealthKit's block is not ours,
    /// and calling code we don't own while holding a lock is how a deadlock gets built.
    func finish() {
        let handler = pendingHandler.withLockUnchecked { stored -> HKObserverQueryCompletionHandler? in
            let claimed = stored
            stored = nil
            return claimed
        }
        handler?()
    }
}

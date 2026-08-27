import Foundation
import SwiftData
import Testing

@testable import VillainArc

/// Exercises the debounce/trigger seam of `RemoteChangeRefreshCoordinator` with an injected
/// refresh closure, so no live `HistoryObserver` remote notification is required.
///
/// The `@Test`/`@Suite` macros can't sit on an `@available`-annotated declaration, so each test
/// gates the iOS-27-only coordinator behind a runtime `#available` check (always true on the
/// iOS 27 simulator these run on).
@MainActor
@Suite(.serialized)
struct RemoteChangeRefreshCoordinatorTests {
    /// Mutable MainActor-isolated fire counter for the injected refresh closure.
    @MainActor final class RefreshCounter {
        private(set) var count = 0
        func increment() { count += 1 }
    }

    private func makeCoordinator(debounce: Duration, counter: RefreshCounter) throws -> RemoteChangeRefreshCoordinator {
        let container = try TestModelContainer.make()
        return RemoteChangeRefreshCoordinator(container: container, debounce: debounce) {
            counter.increment()
        }
    }

    @Test func rapidSignalsCollapseToSingleRefresh() async throws {
        let counter = RefreshCounter()
        let coordinator = try makeCoordinator(debounce: .milliseconds(100), counter: counter)

        coordinator.signalChange()
        coordinator.signalChange()
        coordinator.signalChange()

        try await Task.sleep(for: .milliseconds(400))
        #expect(counter.count == 1)
    }

    @Test func signalsSpacedBeyondDebounceFireSeparately() async throws {
        let counter = RefreshCounter()
        let coordinator = try makeCoordinator(debounce: .milliseconds(100), counter: counter)

        coordinator.signalChange()
        try await Task.sleep(for: .milliseconds(250))
        coordinator.signalChange()
        try await Task.sleep(for: .milliseconds(250))

        #expect(counter.count == 2)
    }

    @Test func stopCancelsPendingRefresh() async throws {
        let counter = RefreshCounter()
        let coordinator = try makeCoordinator(debounce: .milliseconds(150), counter: counter)

        coordinator.signalChange()
        coordinator.stop()

        try await Task.sleep(for: .milliseconds(300))
        #expect(counter.count == 0)
    }

    @Test func observedModelsCoverSpotlightSurfacedTypes() {
        let names = RemoteChangeRefreshCoordinator.spotlightModels.map { String(describing: $0) }
        #expect(names.contains("WorkoutSession"))
        #expect(names.contains("WorkoutPlan"))
        #expect(names.contains("WorkoutSplit"))
        #expect(names.contains("Exercise"))
        #expect(names.contains("ExerciseHistory"))
        // Completed cardio sessions are Spotlight-indexed too (CardioSessionEntity).
        #expect(names.contains("CardioSession"))
    }
}

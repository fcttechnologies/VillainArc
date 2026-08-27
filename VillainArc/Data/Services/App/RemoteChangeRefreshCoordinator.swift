import Foundation
import SwiftData
import WidgetKit

/// Keeps Spotlight and widgets fresh when the persistent store changes from *another process* —
/// a write from the widget or intents extension landing in the shared App Group store.
/// `HistoryObserver` listens for `ModelContainer.remoteChange` notifications only; in-process
/// writes never fire it, so the existing manual `SpotlightIndexer.index(...)`/`reindexAll` calls
/// on local edits stay the single source of truth for same-process changes and are intentionally
/// left untouched. Rows the platform sync engine applies are in-process writes too: those are
/// covered by the engine's own `didApplyRemoteChanges` hook, not by this coordinator.
@MainActor
final class RemoteChangeRefreshCoordinator {
    /// The user-content model types Spotlight actually surfaces (see
    /// `SpotlightIndexer.reindexAll`). A remote transaction touching any of these triggers a
    /// full Spotlight rebuild.
    static let spotlightModels: [any PersistentModel.Type] = [
        WorkoutSession.self,
        WorkoutPlan.self,
        WorkoutSplit.self,
        WorkoutSplitDay.self,
        Exercise.self,
        ExerciseHistory.self,
        CardioSession.self
    ]

    private let container: ModelContainer
    private let debounce: Duration
    private let performRefresh: @MainActor () -> Void

    private var observer: HistoryObserver?
    private var observationTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?

    /// - Parameters:
    ///   - container: the store to observe (production: `SharedModelContainer.container`).
    ///   - debounce: quiet-period before a refresh runs; cross-process writes can arrive as a
    ///     burst of transactions, so we collapse the burst into a single reindex.
    ///   - performRefresh: the side effect to run after the debounce. Defaults to a full Spotlight
    ///     rebuild plus a widget-timeline reload; injectable so the debounce seam is unit-testable
    ///     without a live remote-change notification.
    init(
        container: ModelContainer,
        debounce: Duration = .seconds(2.5),
        performRefresh: (@MainActor () -> Void)? = nil
    ) {
        self.container = container
        self.debounce = debounce
        self.performRefresh = performRefresh ?? { RemoteChangeRefreshCoordinator.reindexAndReloadWidgets(container: container) }
    }

    /// Builds the `HistoryObserver` and starts reacting to `eventCounter` changes. Idempotent.
    /// The observer's `isolation` defaults to `#isolation` (MainActor here, since the whole app
    /// builds under `SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor`), so its updates land on MainActor.
    func start() {
        guard observationTask == nil else { return }
        do {
            let observer = try HistoryObserver(observedModels: Self.spotlightModels, modelContainer: container)
            self.observer = observer
            observationTask = Task { @MainActor [weak self] in
                await self?.observeChanges(observer)
            }
        } catch {
            AppLog.error("Failed to start remote-change HistoryObserver", error: error)
        }
    }

    func stop() {
        observationTask?.cancel()
        observationTask = nil
        debounceTask?.cancel()
        debounceTask = nil
        observer = nil
    }

    /// Observation-based loop: await each `eventCounter` change, then debounce a refresh.
    private func observeChanges(_ observer: HistoryObserver) async {
        while !Task.isCancelled {
            await withCheckedContinuation { continuation in
                withObservationTracking {
                    _ = observer.eventCounter
                } onChange: {
                    continuation.resume()
                }
            }
            guard !Task.isCancelled else { return }
            signalChange()
        }
    }

    /// Debounce seam — collapses a burst of change signals into one refresh after `debounce` of
    /// quiet. Exposed at `internal` visibility so tests can drive it directly with an injected
    /// `performRefresh`, bypassing the live `HistoryObserver` (which only fires on real remote
    /// notifications).
    func signalChange() {
        debounceTask?.cancel()
        let debounce = self.debounce
        debounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled, let self else { return }
            self.performRefresh()
        }
    }

    private static func reindexAndReloadWidgets(container: ModelContainer) {
        SpotlightIndexer.reindexAll(context: container.mainContext)
        // Coarse but correct: there is no per-kind mapping from a workout-content change to a
        // widget kind (the only timeline widgets are HealthKit-driven), and remote changes are
        // infrequent, so a full reload is a cheap, future-proof safety net.
        WidgetCenter.shared.reloadAllTimelines()
        AppLog.info("Remote store change: Spotlight reindex + widget reload.")
    }
}

extension RemoteChangeRefreshCoordinator {
    private static var shared: RemoteChangeRefreshCoordinator?

    /// Starts the app-wide coordinator once, on `SharedModelContainer.container`.
    static func startSharedIfNeeded() {
        guard shared == nil else { return }
        let coordinator = RemoteChangeRefreshCoordinator(container: SharedModelContainer.container)
        shared = coordinator
        coordinator.start()
    }
}

# Watch Companion

This document explains VillainArc's Apple Watch companion app: what it shows, how state flows between the iPhone and the watch, how commands from the wrist run, and where the platform boundaries matter.

## Main Files

- `VillainArc/Data/Watch/WatchSyncContract.swift`
- `VillainArc/Data/Services/Watch/PhoneWatchSyncManager.swift`
- `VillainArcWatchApp/VillainArcWatchApp.swift`
- `VillainArcWatchApp/WatchSessionStore.swift`
- `VillainArcWatchApp/Views/WatchRootView.swift`
- `VillainArcWatchApp/Views/WatchRestTimerView.swift`
- `VillainArcWatchApp/Views/WatchLiveSessionView.swift`
- `VillainArcWatchApp/Views/WatchStatsView.swift`

## Core Idea

The iPhone app is the source of truth; the watch is a glanceable mirror with a small set of remote controls. There is no SwiftData, HealthKit, or workout logic on the watch — it renders snapshots the phone pushes and sends commands the phone executes through the same code paths the app's own UI and App Intents use.

The watch app has three vertically-paged surfaces:

- **Rest Timer** — the anchor feature. Countdown dial with pause/resume, ±15s, and skip while a rest is active; duration presets to start one from the wrist. Plays a wrist haptic when a running rest completes while the watch app is frontmost.
- **Live Session** — mirrors the active strength workout (current exercise, set position, target, set progress, Complete Set button) or cardio session (distance, pace, energy), with live heart rate and zone where available.
- **Stats** — latest/resting heart rate, the user's estimated heart-rate zone ranges, and a last-workout summary.

The root `TabView` auto-selects the page that just became relevant: starting a rest timer jumps to the timer, a session starting (with no rest running) jumps to the live glance.

## The Sync Contract

`WatchSyncContract.swift` is the single wire-format file, compiled into **both** targets (the main app's synchronized group owns it; the watch target allowlists it through a `PBXFileSystemSynchronizedBuildFileExceptionSet` in `project.pbxproj` — the same mechanism as the widget's allowlist). Everything in it must stay pure Foundation, `Codable`, and `nonisolated`.

- `WatchSyncPayload` — the phone → watch snapshot: rest-timer state, live-session state, quick stats, and the estimated max heart rate for zone math.
- `WatchSyncCommand` — the watch → phone commands: `requestSync`, rest-timer control (start/pause/resume/stop/adjust), and `completeActiveSet`.
- `WatchHeartRateZoneConfig` — the estimated 5-zone model (percent of estimated max HR). The thresholds intentionally mirror `HealthWorkoutDetailLoader`'s estimated-zone math so the wrist agrees with the workout detail's zone cards.

Display strings that depend on units or locale (weight, distance, pace, energy) are formatted **on the phone** with the app's existing formatting helpers and sent as text. The watch never converts units — that keeps the kg-storage/display-unit rules in one place.

## Phone Side (`PhoneWatchSyncManager`)

Activated once from the app delegate's launch path. Two responsibilities:

### Pushing state

State flows through `updateApplicationContext` — latest-state-wins semantics, delivered opportunistically and persisted on the watch across launches, which is exactly what a glance needs (no queues to drain, no stale backlog).

Change detection is a re-arming `withObservationTracking` pass over `buildPayload()`. Every observable thing the payload reads — `RestTimerState.shared`, `AppRouter.shared.activeWorkoutSession` / `activeCardioSession`, both live Health coordinators' metrics, and the SwiftData session models' properties — re-triggers a debounced (200 ms) rebuild-and-push. No existing call sites needed edits; new state added to `buildPayload()` is automatically observed.

Pushes are deduplicated by payload equality and gated on `isPaired && isWatchAppInstalled`.

### Executing commands

`session(_:didReceiveMessage:replyHandler:)` decodes a `WatchSyncCommand`, hops to the main actor, executes, and replies with a fresh payload (for immediate watch UI feedback; the application context still syncs separately so a cold watch launch reads current state).

- Rest-timer commands call `RestTimerState.shared` directly — the same shared state the in-app timer sheet, Live Activity, and rest-timer intents use.
- `completeActiveSet` mirrors `CompleteActiveSetIntent.perform()` (active exercise/set lookup, settings-aware completion, auto rest-timer start, `WorkoutActivityManager.update`). Watch taps, like widget and Live Activity intent paths, do not donate to Siri.

The delegate methods are `nonisolated` and hop to the main actor — under the project's MainActor-default isolation, WatchConnectivity delivers on a background queue.

## Watch Side (`WatchSessionStore`)

One `@Observable` store owns the watch's `WCSession`:

- On activation it applies `receivedApplicationContext` (persisted from the last push) so the UI has state immediately, then sends `requestSync` for a fresh snapshot. The root view also re-requests on `scenePhase == .active`.
- `send(_:)` transmits a command via `sendMessage` and applies the reply payload. **The reply/error handlers must stay `@Sendable`** — a closure literal formed in a MainActor context is otherwise implicitly MainActor-isolated, and WatchConnectivity invoking it on its background queue traps the executor assertion (this crashed on first run; the fix is the explicit `@Sendable` + `Task { @MainActor }` hop).
- The store schedules the rest-completion wrist haptic (`WKInterfaceDevice.play(.notification)`) against the payload's `endDate`, cancelling/rescheduling as pushes change it. The haptic only fires while the watch app is frontmost; the phone's rest-timer notification covers the rest.

## Platform Boundaries / Device-Only Behavior

- **No watch-side `HKWorkoutSession`.** The watch displays the heart rate the phone's live coordinators already collect. Running a second workout session on the watch would double-save workouts to Health (see the cardio dedup guard learnings). If higher-rate wrist HR is ever wanted, that's a deliberate future feature with the double-count problem solved first, not a default.
- **Simulator limits:** paired simulators exercise the full WatchConnectivity round-trip (commands, context pushes), but real heart rate, true background delivery timing, watch-app install-from-phone, and haptics need hardware.
- The watch app is a **dependent companion** (`WKCompanionAppBundleIdentifier` set, no independent-run key): it installs with the iOS app and does nothing useful without it.

## Localization

The watch target has its own `VillainArcWatchApp/Localizable.xcstrings` (de/es/fr/pt-BR, fully translated). Keys were added with `"extractionState" : "manual"` — the standard workaround until an Xcode extraction build reconciles them. New user-facing watch strings follow the same rule as the main app: extraction build, then translate via the byte-exact splice with format-spec parity.

## Adding to the Payload

1. Add the field to the payload struct in `WatchSyncContract.swift` (keep it `Codable`/`Equatable`; preformat unit-dependent text on the phone).
2. Populate it in `PhoneWatchSyncManager.buildPayload()` — reading it there is what subscribes the observation loop to its changes.
3. Render it in the watch view; strings go through the watch string catalog.

# Watch Companion Flow

This document describes the shipped Apple Watch companion behavior for VillainArc. It replaces the earlier implementation-planning document and focuses on stable product and architecture rules.

## Main Files

- `Data/Services/HealthKit/Live/WorkoutMirroringCoordinator.swift`
- `Data/Services/HealthKit/Live/HealthLiveWorkoutSessionCoordinator.swift`
- `Data/Services/App/AppRouter.swift`
- `Views/Workout/WorkoutView.swift`
- `Data/LiveActivity/WorkoutActivityManager.swift`
- `VillainArcWatch Watch App/ContentView.swift`
- `VillainArcWatch Watch App/WatchSetupGuard.swift`
- `VillainArcWatch Watch App/WatchWorkoutRuntimeCoordinator.swift`
- `VillainArcWatch Watch App/WatchLiveWorkoutView.swift`
- `VillainArcWatch Watch App/WatchHealthAuthorizationManager.swift`
- `Shared/WatchCommunication/*`

## Product Boundaries

VillainArc's Apple Watch app is a companion, not a standalone workout app.

The watch can:

- start a workout only from an existing completed workout plan
- show the current workout title, current exercise, current set, and mirrored rest timer state
- show live heart rate and energy when watch-side HealthKit runtime is active
- complete and uncomplete sets
- request finish on iPhone
- cancel the workout

The watch cannot:

- create an empty workout
- add, remove, or reorder exercises
- add or remove sets
- edit reps or weight
- review pending suggestions
- run the workout summary flow
- author or edit plans

The iPhone remains the main app for authoring, suggestions, summary, and history.

## Canonical Model Rules

- `WorkoutSession` remains the canonical workout record.
- `HealthWorkout` remains a saved Apple Health mirror and cache of a real `HKWorkout`.
- Apple Health is still an integration layer, not the app's source of truth.
- One persisted field controls the live-runtime mode:

```swift
enum HealthCollectionMode: String, Codable, Sendable {
    case exportOnFinish
    case watchMirrored
}
```

`HealthCollectionMode` means:

- `.exportOnFinish`
  - the original iPhone-owned live workout path
  - iPhone starts and owns `HKWorkoutSession` and `HKLiveWorkoutBuilder`
  - the workout finishes through the original iPhone save-and-export path
- `.watchMirrored`
  - Apple Watch owns the primary `HKWorkoutSession` and `HKLiveWorkoutBuilder`
  - HealthKit mirrors that runtime to iPhone
  - iPhone still owns SwiftData mutations, finish flow, summary flow, and export reconciliation

## Runtime Ownership

VillainArc supports two live HealthKit runtime modes without changing the app-owned workout model.

### iPhone-Owned Runtime

For the original iPhone-only path:

- `WorkoutView` calls `HealthLiveWorkoutSessionCoordinator.ensureRunning(for:)`
- Health collection starts only during `.active`
- finish and cancel still route through `HealthLiveWorkoutSessionCoordinator`
- this path must continue working even when no watch exists, the watch app is not installed, or watch-side authorization is unavailable

### Watch-Owned Mirrored Runtime

For companion-assisted workouts:

- Apple Watch starts the primary `HKWorkoutSession`
- watch calls `startMirroringToCompanionDevice()`
- iPhone receives the mirrored session via `WorkoutMirroringCoordinator`
- iPhone reads live metrics from the mirrored builder
- iPhone continues to own all canonical workout-model writes

The app never allows competing SwiftData writers for the active workout. The watch sends commands; the iPhone validates, mutates, saves, and returns updated runtime state.

## Sync Layers

### SwiftData + CloudKit

Use for:

- durable model storage
- watch Home data
- watch readiness checks
- eventual cross-device consistency

Do not use for:

- active workout commands
- instant runtime state updates
- live metric transport

### WatchConnectivity

Use for:

- watch start requests
- active workout command and response loop
- runtime snapshots
- mirrored rest timer display state
- finish and cancel requests

### HealthKit Workout Mirroring

Use for:

- watch-owned workout runtime
- mirrored iPhone session attachment
- live metric delivery from the mirrored builder

HealthKit mirroring is the workout-runtime transport. It is not the general app-state or authoring channel.

## Watch Readiness

The watch must derive readiness from its own synced store. It must not seed data, create singleton records, or reuse the iPhone `SetupGuard`.

The watch is ready only when its local store contains:

- `AppSettings.single`
- `UserProfile.single`
- `UserProfile.firstMissingStep == nil`
- at least one catalog `Exercise`

If not ready, the watch shows one of:

- `Syncing from iPhone...`
- `Complete setup on iPhone first`

Watch Health authorization is separate from watch readiness. The watch can show Home and synced history data before workout Health permission is granted.

## Start Flows

### iPhone Start

When a workout starts on iPhone:

1. iPhone creates the canonical `WorkoutSession`.
2. The session begins in `.pending` or `.active` using the same rules as the iPhone-only app.
3. If the session is `.active`, iPhone may attempt to upgrade runtime ownership by launching the watch app and requesting mirrored runtime startup.
4. If that upgrade succeeds, `healthCollectionMode` flips to `.watchMirrored` and any local iPhone HK runtime is discarded.
5. If the upgrade does not happen, the original iPhone live HealthKit path continues under `.exportOnFinish`.

This preserves the old iPhone flow while allowing a paired watch to enhance runtime collection.

### Watch Start

When a workout starts from the watch:

1. Watch sends a start request to iPhone.
2. iPhone validates readiness, one-active-flow rules, and plan availability.
3. iPhone creates the canonical `WorkoutSession`.
4. If the plan has pending or deferred suggestions, the session starts in `.pending`, the watch tells the user to continue on iPhone, and no live Health runtime starts.
5. If the session is `.active`, the watch requests watch-side Health authorization and starts the mirrored workout runtime.

If the iPhone is unreachable, watch start is blocked. VillainArc does not support standalone workout creation on watch.

## Active Workout Behavior

The watch live workout screen is intentionally closer to the expanded Live Activity than to the full iPhone workout screen.

It shows:

- workout title
- current incomplete exercise and its sets
- target reps, weight, and RPE when available
- mirrored rest timer state
- live heart rate and energy
- `Finish on iPhone`
- `Cancel Workout`

Important behavior:

- the watch follows the workout's current incomplete exercise and set, not the iPhone pager focus
- if all sets are complete, the watch switches to an `All sets complete` state and prompts the user to continue on iPhone
- if the iPhone changes structure and the current watch target disappears, the watch falls back to `Continue on iPhone`

## Rest Timer

The rest timer remains phone-owned through `RestTimerState`.

The watch only displays mirrored timer state:

- `endDate`
- `isPaused`
- `pausedRemainingSeconds`
- `startedSeconds`

Each side can render the countdown locally from timestamps once the current timer state is received.

## Finish and Cancel

### Finish

Finish always routes back to iPhone.

When the watch requests finish:

- iPhone presents the same finish flow used by the app and finish intent
- unfinished set handling stays on iPhone
- post-workout effort prompting stays on iPhone
- summary stays on iPhone

The watch does not directly finalize the workout summary.

### Cancel

Cancel can be initiated from the watch, but the iPhone still deletes the canonical `WorkoutSession`.

For a mirrored workout:

- iPhone deletes the canonical workout
- iPhone notifies the watch
- the watch discards its local HealthKit workout session

## Recovery and Resume

Resume still follows the normal iPhone-first rules:

- `RootView` waits for iPhone onboarding readiness
- `AppRouter.checkForUnfinishedData()` resumes the incomplete `WorkoutSession` before any incomplete plan draft

The watch also has its own runtime recovery:

- on watch `scenePhase == .active`, it rechecks readiness
- it attempts to recover an already-running watch workout session
- it rehydrates the live workout view from the current runtime snapshot or recovered session

## Health Export and Reconciliation

`HealthExportCoordinator` keeps the original relink-first repair path.

For `.exportOnFinish`:

- the existing iPhone behavior remains in place

For `.watchMirrored`:

- iPhone tries to relink the watch-saved workout first
- iPhone does not fallback-create a duplicate `HKWorkout` while waiting for that relink
- effort-score relation still happens after relink when possible

This prevents duplicate Apple Health workouts while preserving the old iPhone export path for non-mirrored sessions.

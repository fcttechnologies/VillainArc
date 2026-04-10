# Watch Companion Implementation Plan

This document captures the current implementation plan for adding a companion Apple Watch app to Villain Arc. It is intended to preserve the full design context so future work can resume without depending on prior chat history.

This plan is specifically for:

- `iPhone only`
- `iPhone + Apple Watch companion`

This plan is explicitly not for:

- standalone watch onboarding
- standalone watch workout creation
- full watch-side workout editing

## Goals

- Keep the iPhone app fully functional for `iPhone only`.
- Add a companion watch app for `iPhone + Apple Watch`.
- Keep one canonical `WorkoutSession` record and one active workout flow at a time.
- Move live Health workout collection to Apple Watch.
- Preserve the current post-workout Health export and reconciliation path for iPhone-only workouts.
- Let the watch act as a constrained workout companion, not a second full editor.

## Locked Product Decisions

- Watch app is a companion, not a second full editor.
- Watch can start only from an existing workout plan.
- Watch can complete and uncomplete sets.
- Watch can request finish and cancel.
- Watch cannot:
  - create a fresh empty workout
  - add or remove exercises
  - add or remove sets
  - edit reps or weight
  - review suggestions
  - run the full summary flow
  - author plans
- iPhone can still do everything during a mirrored workout.
- If a watch finish request requires interactive cleanup or prompts, return `Finish on iPhone`.
- Watch home data and watch readiness come from the watch's own local SwiftData + CloudKit-synced store, not from messaging.
- Messaging between phone and watch is only for active and live workout runtime.

## Existing Architectural Rules To Preserve

The watch plan must preserve these existing app rules:

- `WorkoutSession` is the canonical app-owned workout record.
- `HealthWorkout` is a saved Apple Health mirror and cache, not the app's primary workout model.
- Villain Arc allows only one active authoring flow at a time.
- Incomplete workouts are persisted and resumable.
- Plan-backed sessions may begin in `.pending` if suggestion review is required.
- HealthKit is an integration layer, not the app's source of truth.

Relevant source docs:

- `Documentation/PROJECT_GUIDE.md`
- `Documentation/ONBOARDING_FLOW.md`
- `Documentation/HEALTHKIT_INTEGRATION.md`
- `Documentation/SESSION_LIFECYCLE_FLOW.md`

## Canonical Model Rules

- `WorkoutSession` remains the only canonical workout record.
- `HealthWorkout` remains a mirror and cache of a real saved `HKWorkout`.
- `HealthWorkout` is never used as an in-progress placeholder.
- Add only one new persisted field to `WorkoutSession`: `healthCollectionMode`.

```swift
enum HealthCollectionMode: String, Codable, Sendable {
    case exportOnFinish
    case watchMirrored
}
```

### Why Only One New Field

We are intentionally not adding:

- `createdDevice`
- activity type
- location type
- fake active Health workout rows
- extra runtime bookkeeping fields that are only useful in memory

Current strength workouts are always `traditionalStrengthTraining` and `indoor`, so persisting extra Health config fields now would add migration and maintenance cost without changing behavior.

## Runtime Ownership

- Apple Watch owns `HKWorkoutSession` and `HKLiveWorkoutBuilder` for live collection.
- iPhone owns canonical SwiftData writes, summary flow, suggestion flow, and Health export reconciliation.
- Watch never directly mutates active-workout SwiftData records in v1.
- Watch sends commands.
- iPhone validates, writes, saves, and returns updated runtime state.

This gives us:

- no competing writers for active workout model data
- no need for placeholder in-progress `HealthWorkout` records
- continued support for the current iPhone-only workout flow

## Sync Layer Responsibilities

### SwiftData + CloudKit

Use for:

- durable model storage
- watch home data
- watch readiness checks
- eventual cross-device consistency

Do not use for:

- active workout command loop
- live metric transport
- instant routing while CloudKit is still catching up

### WatchConnectivity

Use for:

- watch start requests
- active workout runtime snapshots
- active workout command and response loop
- rest timer runtime state for display
- command acknowledgements

Do not use for:

- watch home data
- general onboarding state replication

### HealthKit Workout Mirroring

Use for:

- watch primary workout session
- iPhone mirrored workout session
- live workout metrics and session state mirroring

Do not treat as the app command channel. HealthKit mirroring is for workout runtime, not arbitrary app state mutations.

## Watch Readiness

The watch must not create onboarding or singleton records. It should derive readiness only from its own synced store.

### Watch Readiness Rules

The watch is considered ready only when its local store contains:

- `AppSettings.single`
- `UserProfile.single`
- `UserProfile.firstMissingStep == nil`
- at least one catalog `Exercise` record

### Watch States

If not ready:

- show `Syncing from iPhone...` if the store appears partially populated
- otherwise show `Complete setup on iPhone first`

### Important Note

Do not reuse the iPhone `SetupGuard` directly on watch because iPhone readiness currently depends on `DataManager.hasCompletedInitialBootstrap()`, which uses phone App Group defaults. That App Group storage is not shared to watch.

Instead, add a watch-specific readiness guard that:

- never calls any `ensure...` function
- never seeds data
- never creates singleton records
- only queries the local watch store

Suggested shape:

```swift
static func isReady(context: ModelContext) -> Bool {
    guard (try? context.fetch(AppSettings.single).first) != nil else { return false }
    guard let profile = try? context.fetch(UserProfile.single).first else { return false }
    guard profile.firstMissingStep == nil else { return false }
    let exerciseCount = (try? context.fetchCount(Exercise.catalogExercises)) ?? 0
    return exerciseCount > 0
}
```

`HealthSyncState` should not be part of the watch readiness check. It is an iPhone Health sync tracking model, and its delayed arrival in CloudKit should not block the watch UI if the rest of the user-visible data is already present.

### Watch Launch Monitoring

On watch launch and `scenePhase == .active`:

- rerun the watch readiness check
- rerun active workout discovery
- passively observe CloudKit import progress

The watch version of this should be observation only. It should never perform the iPhone bootstrap logic.

### Health Authorization Is Not Part Of Readiness

Watch readiness is separate from Health authorization.

The watch should still be usable for:

- syncing from iPhone
- showing Home
- browsing plans
- browsing workouts

even if watch-side Health authorization has not yet been granted.

Health authorization on watch should be checked at workout start time, not as part of the watch readiness guard.

## Watch Home

Watch Home should query local SwiftData directly.

Show:

- Today's Plan
- All Plans
- All Workouts

### Empty State

If there are zero plans:

`Create a plan on iPhone to start workouts from Apple Watch.`

### Active Workout Routing

If an active workout exists locally or is discovered by runtime state:

- route directly into `Live Workout`
- do not require an explicit `Resume` button

## Watch Live Workout

Show:

- workout title
- current exercise
- current set
- target reps
- target weight
- target RPE if available
- complete and uncomplete set
- cancel
- finish request
- live heart rate
- live energy
- mirrored rest timer display

### Sets With No Target

If a set has no target values:

- still allow toggle complete if the iPhone session already has that set
- render as `No target set`
- do not render as `0 x 0`

### Structural Changes Mid-Workout

If the iPhone edits structure during a mirrored workout and the watch's current exercise or set disappears:

- move to the next valid item if possible
- otherwise show `Continue on iPhone`

## Start Flow

### iPhone Start

- keep current `AppRouter` gating
- create canonical `WorkoutSession`
- if watch is available and session is `.active`, ask watch to start the primary workout session
- if watch confirms start, set `healthCollectionMode = .watchMirrored`
- otherwise keep `.exportOnFinish`

### Watch Start

- allowed only for plan-backed workouts
- watch sends a start request to iPhone
- iPhone runs readiness and one-active-flow checks
- iPhone creates canonical `WorkoutSession`
- if session is `.pending`, watch shows `Continue on iPhone to review suggestions`
- if session is `.active`, watch checks local Health authorization for the watch workout type subset before starting the primary workout session and mirroring

### Unreachable iPhone Policy For v1

If the iPhone is unreachable:

- block start
- show `Open Villain Arc on iPhone to start from Apple Watch`

This is the safest v1 choice because the system remains iPhone-authoritative for workout record creation.

### Watch Health Authorization Gate

Before watch starts `HKWorkoutSession` or `HKLiveWorkoutBuilder`, it must:

- check `HKHealthStore.isHealthDataAvailable()`
- check local authorization status for workout write access
- request authorization if needed

This is a local watch-side HealthKit check.

Do not assume that iPhone onboarding alone is enough for watch runtime startup.

If watch authorization is:

- granted:
  - start the primary workout session
  - start mirroring
  - use live Health metrics
- denied or unavailable:
  - do not start the watch Health workout session
  - keep the canonical app workout alive on iPhone
  - keep `healthCollectionMode = .exportOnFinish`
  - let the watch continue as a limited companion without live Health metrics if that product behavior is acceptable

The watch Health request should be for a smaller subset than the iPhone app's full Health request set.

Suggested watch subset:

- write:
  - workouts
  - workout effort score
  - active energy burned
  - resting energy burned
- read:
  - heart rate
  - active energy burned
  - resting energy burned

If Apple Watch already has the needed authorization, `requestAuthorization` should return without prompting. The guard still belongs on the device that is about to access HealthKit.

## Finish And Cancel

### Watch Finish

Watch finish is non-interactive.

The iPhone validates:

- `unfinishedSetSummary.caseType == .none`
- `promptForPostWorkoutEffort == false`
- any context-dependent finish blockers are absent
- session status is `.active`

If blocked:

- return `Finish on iPhone`

If allowed:

- watch ends the primary workout session and builder
- iPhone advances the app workout to `.summary`
- watch shows a tiny completion confirmation
- main summary remains on iPhone

### Watch Cancel

- watch sends cancel request
- iPhone deletes canonical `WorkoutSession`
- watch discards the primary Health workout session

## Rest Timer

Keep rest timer ownership on iPhone.

The current timer implementation in `RestTimerState` uses phone App Group defaults and is not available on watch.

### Watch Rest Timer Behavior

Watch only displays mirrored timer state:

- `endDate`
- `isPaused`
- `pausedRemainingSeconds`
- `startedSeconds`

### Runtime Sync

Sync timer transitions, not every second:

- start
- pause
- resume
- stop
- adjusted duration

Each device can count down locally from timestamps once it receives the runtime state.

## Export And Reconciliation

Keep the current iPhone-only export path intact.

### For `.exportOnFinish`

- existing behavior stays the same

### For `.watchMirrored`

Export reconciliation must:

- attempt relink and import first
- not fallback-create a duplicate `HKWorkout` if the watch-saved workout is temporarily not yet linked

This is the key change needed to avoid duplicate Health workouts.

### Watch-Mirrored Effort Score Gap

There is one known follow-up gap to document:

- watch-saved `HKWorkout` objects are relinked later on iPhone
- `postEffort` is usually set during the iPhone-side summary flow
- because `.watchMirrored` sessions use relink-only reconciliation, the existing effort-score relation logic from the retired iPhone live path and the export path does not automatically run for the relinked watch-saved workout

This means a `.watchMirrored` workout may not get its effort score related into HealthKit even if the user later supplies `postEffort` on iPhone.

This is acceptable for v1, but it should be tracked as a follow-up:

- after relinking a `.watchMirrored` `HKWorkout`, if `postEffort > 0`, build the effort sample and relate it to the relinked workout at that point

## Runtime Payloads

These payloads are for active workout runtime only.

```swift
struct ActiveWorkoutSnapshot: Codable, Sendable {
    let sessionID: UUID
    let title: String
    let status: SessionStatus
    let startedAt: Date
    let activeExerciseID: UUID?
    let exercises: [WatchExerciseSnapshot]
    let restTimer: WatchRestTimerSnapshot?
    let healthCollectionMode: HealthCollectionMode
    let canFinishOnWatch: Bool
    let latestHeartRate: Double?
    let activeEnergyBurned: Double?
    let restingEnergyBurned: Double?
}

struct WatchExerciseSnapshot: Codable, Sendable {
    let exerciseID: UUID
    let name: String
    let sets: [WatchSetSnapshot]
}

struct WatchSetSnapshot: Codable, Sendable {
    let setID: UUID
    let index: Int
    let complete: Bool
    let reps: Int
    let weight: Double
    let targetRPE: Int?
    let hasTarget: Bool
}

struct WatchRestTimerSnapshot: Codable, Sendable {
    let endDate: Date?
    let pausedRemainingSeconds: Int
    let isPaused: Bool
    let startedSeconds: Int
}

enum WatchWorkoutCommand: Codable, Sendable {
    case startPlannedWorkout(planID: UUID)
    case toggleSet(sessionID: UUID, setID: UUID, desiredComplete: Bool, commandID: UUID)
    case finish(sessionID: UUID, commandID: UUID)
    case cancel(sessionID: UUID, commandID: UUID)
}

enum WatchWorkoutCommandResult: Codable, Sendable {
    case started(ActiveWorkoutSnapshot)
    case updated(ActiveWorkoutSnapshot)
    case finishOnPhone(reason: String)
    case blocked(reason: String)
    case cancelled
    case failed(reason: String)
}
```

The optional live metric fields exist as a fallback path. The preferred live metric source on iPhone is the mirrored `HKLiveWorkoutBuilder` statistics callbacks. If those callbacks prove unreliable in practice, the active workout snapshot channel can carry the latest watch-collected metric values without redesigning the rest of the transport.

## Command Handling Rules

### Encoding

`WCSession.sendMessage` uses `[String: Any]`, so wrap Codable payloads in `Data`.

### Idempotency

Use `commandID` for:

- `toggleSet`
- `finish`
- `cancel`

On iPhone, keep an in-memory recent-command cache so duplicate command IDs return the last known result or snapshot without reapplying the mutation.

### Snapshot Build Rules

`canFinishOnWatch` must be computed at snapshot generation time, not cached.

Suggested logic:

```swift
var canFinishOnWatch: Bool {
    workout.unfinishedSetSummary.caseType == .none
        && !settings.promptForPostWorkoutEffort
        && workout.statusValue == .active
}
```

## iPhone Editing During Mirrored Workout

iPhone remains fully capable during `.watchMirrored`.

That means:

- iPhone can still edit workout structure
- iPhone can still edit notes, title, and session content
- iPhone remains the only canonical writer
- after every meaningful active-workout save, iPhone pushes a fresh `ActiveWorkoutSnapshot`

If a watch command or watch screen is now stale because the phone edited structure:

- watch re-renders from the latest snapshot
- watch falls forward to the next valid exercise or set if needed

### Snapshot Push Must Be Centralized

The active workout can be mutated outside `WorkoutView`. These callsites also save the workout and must push a fresh `ActiveWorkoutSnapshot` when `healthCollectionMode == .watchMirrored`:

| File | Mutation |
|------|----------|
| `Intents/Workout/CompleteActiveSetIntent.swift` | Marks set complete, starts rest timer, saves, updates Live Activity |
| `Intents/LiveActivity/LiveActivityCompleteSetIntent.swift` | Same pattern — marks set complete, starts rest timer, saves |

If snapshot push is only wired into `WorkoutView` saves, the watch will drift after Siri, Shortcut, or Live Activity button actions.

The simplest approach is a centralized static helper on `WatchWorkoutCommandCoordinator`:

```swift
static func pushSnapshotIfMirrored(for workout: WorkoutSession) {
    guard workout.healthCollectionMode == .watchMirrored else { return }
    // build and send ActiveWorkoutSnapshot
}
```

Add one call after each intent or service save that mutates the active workout. Any future intent or service that writes to the active workout must also call this helper.

### Rest Timer Runtime Push Must Also Be Centralized

The watch displays rest timer state, but timer mutations do not always coincide with a workout-model save.

That means a second centralized helper is needed for runtime-only state:

```swift
static func pushRuntimeStateIfMirrored(for workout: WorkoutSession) {
    guard workout.healthCollectionMode == .watchMirrored else { return }
    // build and send ActiveWorkoutSnapshot including WatchRestTimerSnapshot
}
```

This helper should be called after timer-only mutations that affect the watch runtime display, even when the workout model itself was not changed.

Important current callsites include:

| File | Mutation |
|------|----------|
| `Intents/RestTimer/StartRestTimerIntent.swift` | Starts the timer without mutating the workout model |
| `Intents/RestTimer/PauseRestTimerIntent.swift` | Pauses the timer without mutating the workout model |
| `Intents/RestTimer/ResumeRestTimerIntent.swift` | Resumes the timer without mutating the workout model |
| `Intents/RestTimer/StopRestTimerIntent.swift` | Stops the timer without mutating the workout model |
| `Intents/LiveActivity/LiveActivityPauseRestTimerIntent.swift` | Pauses timer from the Live Activity |
| `Intents/LiveActivity/LiveActivityResumeRestTimerIntent.swift` | Resumes timer from the Live Activity |

Any future rest-timer control surface that changes runtime timer state must also trigger this runtime push helper during `.watchMirrored`.

### iPhone Cancel During Mirrored Workout

If the iPhone cancels a `.watchMirrored` workout while the watch is active:

- iPhone must immediately notify the watch through the live runtime channel
- watch must discard its local `HKWorkoutSession`
- watch must exit the live workout screen

If that explicit notification is missed for any reason, a later watch command for the deleted session should receive `failed(reason: "session not found")`, and the watch should treat that as an implicit cancel and tear down its local session state.

This is the main truly unrecoverable state to guard against during active mirrored workouts.

## Crash And Relaunch Recovery

Crash and relaunch recovery must be treated as a first-class requirement.

### Watch Recovery

If the watch app crashes or is terminated during an active workout:

- the HealthKit workout session may survive beyond the process lifetime
- on watch relaunch, the app must attempt to recover the already-running workout session
- after recovery, the watch must route directly back into the live workout screen

The watch should implement a recovery path analogous to the current iPhone `recoverIfPossible` logic in `HealthLiveWorkoutSessionCoordinator`, which uses `recoverActiveWorkoutSession()` and reattaches to the associated builder.

### iPhone Recovery

If the iPhone app is launched or relaunched while the watch-owned mirrored workout is active:

- `workoutSessionMirroringStartHandler` must be registered as early as launch
- the app must tolerate multiple mirroring handler calls for the same underlying workout due to reconnect behavior
- the mirrored runtime coordinator must reattach to the newest mirrored session object and rebuild the latest live runtime state

### Recovery Principle

The canonical app workout remains the persisted `WorkoutSession`. HealthKit runtime recovery is only for rebuilding the active live session bridge after interruption.

## File And Service Changes

### Edit Existing

- `Data/Models/Sessions/WorkoutSession.swift`
  - add `HealthCollectionMode`
- `Data/Services/HealthKit/Export/HealthExportCoordinator.swift`
  - add `.watchMirrored` relink-only guard
- `Views/Workout/WorkoutView.swift`
  - remove the current iPhone-side `ensureRunning(for:)` startup call (line 193)
  - update finish behavior for `.watchMirrored` so iPhone coordinates with the watch-owned Health session instead of trying to finish a local iPhone Health session (line 449)
  - update cancel and discard behavior for `.watchMirrored` so iPhone notifies watch to discard its Health session (lines 456, 462)
- `Views/Workout/WorkoutLiveStatsView.swift`
  - stop reading directly from `HealthLiveWorkoutSessionCoordinator.shared` (lines 6, 38, 52)
  - read from the new mirrored runtime coordinator for `.watchMirrored`
  - retain fallback behavior for `.exportOnFinish`
- `Data/Services/App/AppRouter.swift`
  - `cancelWorkoutSession` (line 237) calls `HealthLiveWorkoutSessionCoordinator.shared.discardIfRunning(for:)` directly; route through `healthCollectionMode` so `.watchMirrored` notifies the watch instead
- `Intents/Workout/FinishWorkoutIntent.swift`
  - finish path (line 62) calls `HealthLiveWorkoutSessionCoordinator.shared.finishIfRunning(for:context:)`; route through `healthCollectionMode`
  - deleted-workout path (line 67) calls `HealthLiveWorkoutSessionCoordinator.shared.discardIfRunning(for:)`; route through `healthCollectionMode`
- `Intents/Workout/CancelWorkoutIntent.swift`
  - routes through `AppRouter.shared.cancelWorkoutSession`, so covered by the `AppRouter` fix above
- `Data/LiveActivity/WorkoutActivityManager.swift`
  - `canPresentRestTimerCompletionAlert` (line 109) reads `HealthLiveWorkoutSessionCoordinator.shared.isRunningLiveWorkoutCollection`; read from `WorkoutMirroringCoordinator` instead
  - `activeContentState` (line 142) reads `.latestHeartRate` and `.activeEnergyBurned` from the coordinator; read from `WorkoutMirroringCoordinator` instead
  - `summaryContentState` (line 180) reads `.totalEnergyBurned` from the coordinator; read from `WorkoutMirroringCoordinator` instead
- `Root/VillainArcApp.swift`
  - register iPhone HealthKit workout mirroring start handler at launch

### Replace Or Retire Existing iPhone Live Health Runtime

- `Data/Services/HealthKit/Live/HealthLiveWorkoutSessionCoordinator.swift`
  - this file must no longer create an iPhone-side `HKWorkoutSession` for strength workouts
  - the current responsibilities do not match the mirrored-runtime design
  - preferred approach:
    - replace it with a new `WorkoutMirroringCoordinator`
    - retire or delete the old file once `.exportOnFinish` no longer depends on it
  - avoid preserving the old "create local iPhone live workout session" behavior for the rejected strength-workout path

### Add New iPhone Services

- `WorkoutMirroringCoordinator`
  - iPhone-side mirrored workout runtime
- `WatchWorkoutCommandCoordinator`
  - decode, validate, apply, and respond to watch runtime commands

### Full Callsite Inventory

Every location that currently references `HealthLiveWorkoutSessionCoordinator` must be migrated. The complete list:

Callsites that create, finish, or discard an iPhone Health session:

| File | Line | Call | Migration |
|------|------|------|-----------|
| `WorkoutView.swift` | 193 | `ensureRunning(for:)` | Remove — iPhone no longer creates HK sessions |
| `WorkoutView.swift` | 449 | `finishIfRunning(for:context:)` | Route through mode: `.watchMirrored` notifies watch, `.exportOnFinish` is a no-op |
| `WorkoutView.swift` | 456 | `discardIfRunning(for:)` | Route through mode: `.watchMirrored` notifies watch, `.exportOnFinish` is a no-op |
| `WorkoutView.swift` | 462 | `discardIfRunning(for:)` | Same as above |
| `AppRouter.swift` | 237 | `discardIfRunning(for:)` | Route through mode — this is the Siri and intent cancel path |
| `FinishWorkoutIntent.swift` | 62 | `finishIfRunning(for:context:)` | Route through mode |
| `FinishWorkoutIntent.swift` | 67 | `discardIfRunning(for:)` | Route through mode |

Callsites that read live metrics from the coordinator:

| File | Line | Read | Migration |
|------|------|------|-----------|
| `WorkoutActivityManager.swift` | 109 | `isRunningLiveWorkoutCollection` | Read from `WorkoutMirroringCoordinator` |
| `WorkoutActivityManager.swift` | 142 | `.latestHeartRate`, `.activeEnergyBurned` | Read from `WorkoutMirroringCoordinator` |
| `WorkoutActivityManager.swift` | 180, 206 | `.totalEnergyBurned` | Read from `WorkoutMirroringCoordinator` |
| `WorkoutLiveStatsView.swift` | 6, 38, 52 | Coordinator singleton for HR and energy display | Read from `WorkoutMirroringCoordinator` |

### Watch Target

Add a new watch companion target with:

- watch readiness guard
- passive CloudKit import observation
- watch home querying SwiftData
- watch live workout view driven by runtime snapshots
- watch-local Health authorization manager or equivalent watch-side Health authorization checks

### Watch Local Store

The watch target must use its own local SwiftData store path on the watch filesystem.

It must not use the iPhone App Group container path.

### Schema Requirement

The watch target should use the same full `SharedModelContainer.schema` model graph against the same CloudKit database identifier.

The watch does not need to query most of those models, but the full schema should be compiled into the watch target so CloudKit record materialization and relationship resolution remain correct.

## Watch Capabilities

Watch target should have:

- HealthKit capability
- watch-side Health usage descriptions
- workout processing background mode
- iCloud capability with CloudKit
- CloudKit container: `iCloud.com.fcttechnologies.VillainArcCont`

Do not rely on the iPhone App Group for watch runtime or readiness.

## Implementation Order

1. Add `HealthCollectionMode` to `WorkoutSession`
2. Add iPhone `WorkoutMirroringCoordinator`
3. Register HealthKit mirroring start handler at iPhone launch
4. Add watch target and capabilities
5. Add watch readiness guard and passive CloudKit import observation
6. Build watch Home from SwiftData queries
7. Add iPhone `push active workout snapshot after save`
8. Build watch Live Workout from snapshots only
9. Implement watch start request flow
10. Add watch-local Health authorization guard for workout startup
11. Implement watch primary `HKWorkoutSession` + `HKLiveWorkoutBuilder` + mirroring
12. Verify mirrored builder and statistics behavior on iPhone early
13. Add watch commands: toggle set, finish, cancel
14. Add `.watchMirrored` relink-only export guard
15. Add `scenePhase` reconciliation on both apps

## Testing And Edge Cases

Review and test these before shipping:

- watch start when iPhone is unreachable
- active workout discovered on watch before full CloudKit sync finishes
- watch Health permission denied
- watch Health permission not yet requested, then requested at workout start
- iPhone edits workout structure while watch live screen is open
- iPhone cancels workout while watch is active
- duplicate watch commands and retry handling
- timer-only mutations on iPhone or Live Activity update the watch runtime even when no workout save occurs
- finish request when there are unfinished sets
- finish request when effort or context prompts are required
- mirrored session reconnects and start handler fires multiple times
- watch app crashes or is terminated during active workout, then relaunches
- iPhone-only fallback still exports correctly
- no plans on watch Home
- watch launch while iPhone onboarding is incomplete
- Siri or Lock Screen Live Activity button completes a set during a `.watchMirrored` workout and the watch receives the updated snapshot
- `WorkoutSummaryView` health stats are empty immediately after `.watchMirrored` finish because `workout.healthWorkout` is not yet linked

### Known v1 UX Gap: Summary Health Stats After Watch-Mirrored Finish

`WorkoutSummaryView.loadWorkoutHealthSummaryItems()` only renders Avg Heart Rate and Total Energy when `workout.healthWorkout` is already linked. For `.watchMirrored` finishes, the app enters `.summary` before the watch-saved `HKWorkout` is visible and imported on iPhone, so these cards will be empty on first entry.

This is survivable for v1. The stats will appear once the Health workout is synced, imported, and linked on a later reconciliation pass, or if the user re-enters summary.

A future improvement could use the last-known mirrored metrics from `WorkoutMirroringCoordinator` as a temporary fallback while the relink is pending.

## Final Review Questions

These are the questions to review before implementation starts:

1. Is the watch readiness check sufficient if it is derived entirely from local SwiftData + CloudKit state?
2. Is the `.watchMirrored` relink-only export rule the right place to prevent duplicate `HKWorkout` creation?
3. Does the mirrored `associatedWorkoutBuilder()` on iPhone reliably deliver live statistics callbacks for heart rate and energy, or should those metrics also be sent through the runtime payload channel?
4. Does the watch target need the full relevant synced model graph for CloudKit correctness, or is the planned watch-query subset safe?
5. Are there any cases where allowing full iPhone editing during `.watchMirrored` creates a runtime inconsistency the watch UI cannot recover from cleanly?
6. Is the watch-side Health authorization guard scoped correctly so that Health is only requested when live workout collection is actually about to begin?

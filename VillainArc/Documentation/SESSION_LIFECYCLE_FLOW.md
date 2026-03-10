# Workout Session Lifecycle

This document describes the actual implementation of the workout session lifecycle in VillainArc, from creation through completion, including all status transitions, finish logic, and edge cases.

It is based on the current code in:

- `Data/Models/Sessions/WorkoutSession.swift`
- `Data/Models/Sessions/ExercisePerformance.swift`
- `Data/Models/Sessions/SetPerformance.swift`
- `Data/Models/Sessions/PreWorkoutContext.swift`
- `Data/Services/AppRouter.swift`
- `Views/Workout/WorkoutSessionContainer.swift`
- `Views/Workout/WorkoutView.swift`
- `Views/Workout/WorkoutSummaryView.swift`
- `Data/Models/Enums/Sessions/SessionStatus.swift`
- `Data/Models/Enums/Sessions/Origin.swift`
- `Data/LiveActivity/WorkoutActivityManager.swift`

## Core Model

`WorkoutSession` is the root model for a workout in progress or completed. It stores:

- `id`, `title`, `notes` — user-facing metadata
- `status` — raw string backing `SessionStatus` (pending/active/summary/done)
- `startedAt`, `endedAt` — timestamps
- `origin` — provenance for the session (`.user`, `.plan`, `.session`, or `.ai`; current workout creation paths use `.user` and `.plan`)
- `preWorkoutContext` — optional mood/notes captured before the workout (cascade delete)
- `workoutPlan` — optional link to the source plan (nullify on plan delete)
- `exercises` — array of `ExercisePerformance` (cascade delete)
- `activeExercise` — the currently focused exercise (nullify)
- `postEffort` — 1-10 effort rating set during summary
- `createdPrescriptionChanges` — suggestions generated from this session
- `evaluatedPrescriptionChanges` — suggestions evaluated against this session

Each `ExercisePerformance` owns an array of `SetPerformance` rows. Sets track weight, reps, set type, completion state, actual RPE, rest time, and optional back-references to their originating prescription/set prescription.

## Session Status Lifecycle

```
pending → active → summary → done
```

- **pending**: Session has deferred/pending suggestions to review before the workout begins. Only happens for plan-based sessions.
- **active**: User is logging sets. This is where the bulk of the workout happens.
- **summary**: Workout is finished. User reviews stats, PRs, effort rating, and generated suggestions.
- **done**: Locked. Summary has been dismissed, exercise histories rebuilt, all data finalized.

`WorkoutSessionContainer` routes the UI based on `statusValue`:

- `.pending` → `DeferredSuggestionsView`
- `.active` → `WorkoutView`
- `.summary` / `.done` → `WorkoutSummaryView`

Transitions between these states are animated with a trailing-edge slide.

## Starting a Workout

There are two paths.

### Freeform

`AppRouter.startWorkoutSession()`:

1. Guards `hasActiveFlow()` — returns immediately if any workout or plan editing is active
2. Creates a new `WorkoutSession()` with default title "New Workout", `.active` status, and `.user` origin
3. A `PreWorkoutContext` is auto-created in the initializer
4. Inserts into SwiftData context and saves
5. Sets `activeWorkoutSession`, which triggers `ContentView`'s full-screen cover

### Plan-Based

`AppRouter.startWorkoutSession(from plan:)`:

1. Same `hasActiveFlow()` guard
2. Creates `WorkoutSession(from: plan)` which:
   - Copies `title` and `notes` from the plan
   - Sets `origin = .plan`
   - Links `workoutPlan = plan`
   - Maps `plan.sortedExercises` into `ExercisePerformance` rows (each linked back to its `ExercisePrescription`)
   - Updates `plan.lastUsed`
3. Checks `pendingSuggestions(for: plan, in: context)` — if any pending/deferred suggestions exist, sets status to `.pending` instead of `.active`
4. Inserts, saves, and presents

When performance rows are created from prescriptions, each `ExercisePerformance` gets its sets pre-populated from the plan's `SetPrescription` rows. The prescription back-references are maintained so the suggestion system can later link source evidence to targets.

During a plan-based workout, if the user deletes a prescribed session set and later adds a set back, `ExercisePerformance.addSet()` only restores a prescription link when the deleted prescription was a **tail** slot — i.e., no remaining set is linked to a prescription with a higher index. This handles the common "delete last set, change my mind, add it back" case. If the deleted prescription would create a hole in the middle (e.g., deleting set 1 of 3 while sets 2 and 3 still carry their links), adding a set creates a new unlinked set at the end instead, since the user likely wants an extra set rather than the one they removed.

## Resuming Unfinished Work

`AppRouter.checkForUnfinishedData()` runs on app launch from `ContentView`'s task:

1. Guards `hasPresentedFlow` to avoid double-presenting
2. First checks `WorkoutSession.incomplete` (any session not `.done`, limit 1)
3. If found, calls `resumeWorkoutSession(workoutSession)` — sets `activeWorkoutSession` without creating a new session
4. If no incomplete workout, checks `WorkoutPlan.resumableIncomplete` (any plan that's `!completed && !isEditing`, limit 1)
5. If found, calls `resumeWorkoutPlanCreation(plan)`

Priority is always: **resume workout first**, then resume plan. This means if the user was editing a plan and started a workout, the workout takes precedence on relaunch.

## Active Flow Guards

`hasActiveFlow()` prevents concurrent flows. It checks three conditions:

1. `hasPresentedFlow` — is a workout or plan already being presented in the UI?
2. `hasPersistedIncompleteWorkoutSession()` — does an incomplete session exist in the database?
3. `hasPersistedActivePlanWork()` — does an incomplete plan exist in the database?

This guard is checked before starting a new workout, creating a new plan, handling Spotlight results, or handling Siri workout commands. If any condition is true, the action is silently ignored.

## During the Workout

`WorkoutView` is the primary active-workout screen. Key behaviors:

- **Exercise pager**: TabView showing one exercise at a time, with swipe navigation
- **Add exercise**: Opens `AddExerciseView` modal to select from the catalog
- **Set logging**: Each set row (`ExerciseSetRowView`) handles weight/reps input, completion toggling, set type changes, and RPE recording
- **Rest timer**: Auto-starts on set completion via `RestTimerState.shared.start()`, shown in `RestTimerView` sheet
- **Live Activity**: Started with `WorkoutActivityManager.start()` when the workout begins, updated on set completion and exercise changes, ended on finish/cancel

If the workout is linked to a plan, completing the final remaining incomplete set also prewarms a generic Foundation Models `LanguageModelSession` in the background. That warm-up happens from:
- `ExerciseSetRowView`
- `RestTimerView`'s "Complete set" action
- `CompleteActiveSetIntent`
- `LiveActivityCompleteSetIntent`

The workout auto-tracks `activeExercise` for the live activity and intent system to know which exercise and set are currently in focus.

## Finishing a Workout

The finish flow has two stages: resolving incomplete sets, then transitioning to summary.

### Stage 1: Incomplete Set Resolution

When the user taps "Finish", `WorkoutView` checks `unfinishedSetSummary`:

`UnfinishedSetSummary` classifies incomplete sets into two buckets:
- **Empty sets**: `reps == 0 && weight == 0` (never logged anything)
- **Logged sets**: Have some data but were never marked complete

Based on these, the view presents different confirmation options:

| Case | Options |
|------|---------|
| `.none` | Finish directly (`.finish`) |
| `.emptyOnly` | Delete empty sets (`.deleteEmpty`) |
| `.loggedOnly` | Mark logged as complete (`.markLoggedComplete`) or delete them (`.deleteUnfinished`) |
| `.emptyAndLogged` | Mark logged as complete + delete empty (`.markLoggedComplete`) or delete all unfinished (`.deleteUnfinished`) |

### Stage 2: WorkoutSession.finish()

`finish(action:context:)` executes the chosen action:

- `.markLoggedComplete`: Marks logged sets as complete with timestamps. Deletes empty sets. Prunes empty exercises.
- `.deleteUnfinished`: Deletes all incomplete sets (both logged and empty). Prunes empty exercises.
- `.deleteEmpty`: Deletes only empty sets. Prunes empty exercises.
- `.finish`: No set modifications (used when there are no unfinished sets).

After the action, it:
1. Sets status to `.summary`
2. Sets `endedAt` to now
3. Clears `activeExercise`

If the workout is plan-backed and is finished through `FinishWorkoutIntent`, the app also prewarms a generic Foundation Models `LanguageModelSession` before handing off to the summary screen. That intent path can bypass the normal "final remaining set completed" trigger.

### Pruning

`pruneEmptyExercises(context:)` runs after set deletion. It removes any `ExercisePerformance` that has zero sets remaining. If ALL exercises are pruned (the entire workout becomes empty), the workout itself is deleted from context and the method returns `.workoutDeleted`.

This is a critical edge case: if the user started a workout, added exercises, never logged anything, and then finishes with "delete all", the workout is silently removed rather than saved as an empty record. The UI detects the `.workoutDeleted` result and dismisses without showing summary.

## Summary and Done

`WorkoutSummaryView` is shown for both `.summary` and `.done` status.

### On Appear (`.summary`)

A `.task(id: workout.id)` runs:
1. `loadPRs()` — batch-fetches `ExerciseHistory` for all exercises in the workout, compares current performance against cached PRs
2. `generateSuggestionsIfNeeded()` — only for plan-based workouts, see WORKOUT_PLAN_SUGGESTION_FLOW.md

If the workout is still freeform (`workout.workoutPlan == nil`), the summary also prewarms a generic Foundation Models `LanguageModelSession` in the background. This makes the later "Save as Workout Plan" path more responsive if the user chooses to create a plan from the finished workout.

### PR Detection

PRs are detected by comparing the just-finished workout's metrics against cached `ExerciseHistory`:

- **Estimated 1RM PR**: Current exercise `bestEstimated1RM` exceeds `history.bestEstimated1RM`
- **Weight PR**: Current exercise `bestWeight` exceeds `history.bestWeight`
- **Volume PR**: Current exercise `totalVolume` exceeds `history.bestVolume`

First-time exercises (no history yet) automatically get PRs for any non-zero metrics.

### Finishing Summary

`finishSummary()` is called when the user dismisses the summary:

1. Guards against double-finish with `isSaving` flag
2. Calls `deferRemainingSuggestions()` — converts any still-`pending` suggestions to `.deferred`
3. Calls `ExerciseHistoryUpdater.updateHistoriesForCompletedWorkout()` — rebuilds exercise history including this session
4. Sets status to `.done`
5. Saves context
6. Dismisses the full-screen cover

The suggestion deferral ensures undecided suggestions appear before the next plan-based workout in `DeferredSuggestionsView`.

## Canceling a Workout

Cancel paths:

**From WorkoutView**: Shows confirmation alert, then:
1. Stops rest timer
2. Clears `activeExercise`
3. Deletes the session from context
4. Clears `activeWorkoutSession`
5. Ends live activity

**From Siri** (`handleSiriCancelWorkout`): Same cleanup but triggered from `VillainArcApp`'s user activity handler.

**From CancelWorkoutIntent**: Similar flow through the intent system.

In all cases, the session and all its exercises/sets are cascade-deleted from SwiftData.

## Live Activity Integration

The live activity shows workout state on the lock screen and Dynamic Island.

- **Start**: `WorkoutActivityManager.start()` is called when `WorkoutView` appears, creating an `Activity<WorkoutActivityAttributes>`
- **Update**: Called on set completion, exercise changes, rest timer state changes. Updates the content state with current exercise name, set info, timer state
- **End**: Called on workout finish, cancel, or app termination cleanup. Uses `.default` dismissal policy

The activity manager also handles restoration — if the app relaunches with an incomplete workout, it checks for an existing activity and reconnects.

## Edge Cases

### Force-quit during workout

The session persists in SwiftData. On next launch, `checkForUnfinishedData()` finds it and resumes. The live activity may have expired, but is re-created when `WorkoutView` appears.

### All exercises pruned on finish

If every exercise ends up with zero sets after the finish action, the workout is deleted entirely. The UI dismisses without showing summary. No exercise history is updated. No suggestions are generated.

### Workout with only empty sets

If the user added exercises but never logged any data, finishing with any delete action will prune all exercises, triggering the workout deletion path.

### Summary screen for `.done` workouts

`WorkoutSummaryView` handles both `.summary` (fresh) and `.done` (already finalized). The `.done` case just shows the stats — the finish button and suggestion actions are guarded by `isSaving` and status checks.

### Concurrent flow prevention

Multiple entry points (UI buttons, Siri, Shortcuts, Spotlight, Live Activity) all funnel through `AppRouter` which enforces `hasActiveFlow()`. If any flow is active, new starts are silently rejected.

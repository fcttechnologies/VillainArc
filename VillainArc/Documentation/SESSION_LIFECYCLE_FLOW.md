# Workout Session Lifecycle

This document explains how workouts are created, resumed, logged, finalized, and canceled in VillainArc. It covers both empty workouts and plan-backed workouts.

## Main Files

- `Data/Services/App/AppRouter.swift`
- `Data/Models/Sessions/WorkoutSession.swift`
- `Data/Models/Sessions/ExercisePerformance.swift`
- `Data/Models/Sessions/SetPerformance.swift`
- `Views/Workout/WorkoutSessionContainer.swift`
- `Views/Workout/WorkoutView.swift`
- `Views/Workout/WorkoutSummaryView.swift`
- `Views/Suggestions/DeferredSuggestionsView.swift`
- `Data/Services/Workout/RestTimerState.swift`
- `Data/LiveActivity/WorkoutActivityManager.swift`
- `Data/Services/HealthKit/Live/HealthLiveWorkoutSessionCoordinator.swift`

## Session Model

`WorkoutSession` is the root workout record. It stores:

- workout metadata
- lifecycle status
- optional source `WorkoutPlan`
- optional `PreWorkoutContext`
- performed exercises and sets
- active exercise focus
- post-workout effort
- suggestion events generated from that workout
- optional linked `HealthWorkout`

Plan-based sessions are created from `WorkoutPlan`. Empty workouts use a brand-new `WorkoutSession()`.

## Session States

Workouts move through:

`pending -> active -> summary -> done`

- `pending`
  - plan-backed workout blocked on unresolved suggestions
- `active`
  - user is logging the workout
- `summary`
  - logging is finished, but the workout is not yet finalized
- `done`
  - workout is the stable completed record

`WorkoutSessionContainer` routes the UI by this status.

## Session Creation

### Empty Workout

Entry points:

- home plus menu
- `StartWorkoutIntent`
- Siri/shortcut routes

All route into `AppRouter.startWorkoutSession()`.

That method:

- blocks if any other workout/plan flow is active
- creates a persisted `WorkoutSession`
- saves it
- presents it through `activeWorkoutSession`

### Workout From a Plan

Entry points:

- `WorkoutPlanDetailView`
- `StartWorkoutWithPlanIntent`
- `StartTodaysWorkoutIntent`

All route into `AppRouter.startWorkoutSession(from:)`.

That method:

- blocks if any other workout/plan flow is active
- creates a persisted `WorkoutSession(from: plan)`
- converts set weights from canonical kg into the user’s display unit
- checks the source plan for pending or deferred suggestions
- starts the session in `.pending` or `.active`
- saves and presents it

## Resume Behavior

After onboarding reaches `.ready`, `RootView` calls `AppRouter.checkForUnfinishedData()`.

Resume order is:

1. incomplete `WorkoutSession`
2. resumable incomplete `WorkoutPlan`

Important rule:

- any `WorkoutSession` whose status is not `.done` is resumable
- editing copies of plans are never resumed

Launch cleanup deletes abandoned editing copies before resume runs.

## Pending Suggestion Gate

Plan-backed sessions can start in `.pending` when the source plan still has unresolved suggestions.

`DeferredSuggestionsView` blocks entry to active logging until those suggestions are resolved.

Available actions:

- accept one
- reject one
- accept all
- skip all

Important behavior:

- accept mutates the live plan and hydrates the already-created pending session copy
- reject only changes suggestion decision state
- skip all marks remaining pending/deferred suggestions as rejected and lets the workout proceed

The workout only moves to `.active` once the pending/deferred set is empty.

## Active Logging

`WorkoutView` is the main logging screen. It owns:

- exercise paging
- add/edit exercise flows
- finish and cancel
- title and notes editing
- pre-workout context
- workout settings
- rest timer
- live Apple Health sheet
- intent/live-activity-driven sheet presentation

Main collaborators:

- `RestTimerState`
- `WorkoutActivityManager`
- `HealthLiveWorkoutSessionCoordinator`

Important runtime rules:

- `activeExercise` tracks pager focus
- rest timer state is shared app-wide
- pre-workout context prompting is settings-driven
- live activities mirror the active incomplete workout

## Finishing a Workout

Finish is intentionally split into two phases.

### Phase 1: Leave Active Logging

`WorkoutView.finishWorkout(...)`:

- checks unfinished sets
- lets the user resolve incomplete or empty set state
- optionally captures post-workout effort
- calls `WorkoutSession.finish(...)`
- converts set weights back to canonical kg
- saves the workout
- ends the live Health workout session if running
- stops the rest timer
- ends the Live Activity

`WorkoutSession.finish(...)` itself:

- applies unfinished-set cleanup
- prunes empty exercises
- deletes the whole workout if it becomes empty
- updates exercise dates where needed
- sets `status = .summary`
- sets `endedAt`
- clears `activeExercise`

If every exercise is pruned, the workout never reaches summary.

### Phase 2: Finalize Summary

`WorkoutSummaryView` handles:

- summary stats and notes
- PR detection
- outcome resolution for older suggestions
- generation of new suggestions
- review of current-session suggestions
- save-as-plan
- historical prescription-link cleanup
- `ExerciseHistory` rebuild

The true completion point is `finishSummary()`. That method:

- converts any still-pending current-session suggestions to `deferred`
- cleans up active-only prescription links
- rebuilds `ExerciseHistory`
- marks the workout `.done`
- saves
- Spotlight-indexes the completed workout
- dismisses the flow

## Save As Plan

There are two different “save as plan” flows:

- from `WorkoutSummaryView`
  - convert the finished workout into a completed plan immediately
- from completed workout detail
  - `AppRouter.createWorkoutPlan(from:)` opens an editable plan draft

Those flows are related, but not the same feature.

## Apple Health During Workout Runtime

If workout write authorization exists, `HealthLiveWorkoutSessionCoordinator` can start and recover a live Health workout session during the local `.active` phase.

Rules:

- Health collection starts only for active logging, not for the pending suggestion gate
- the Health workout ends when local logging moves to `.summary`
- canceling the workout discards the in-flight Health workout
- if a saved `HKWorkout` comes back, the app imports it through the shared Health workout mirror path

## Canceling a Workout

Canceling an incomplete workout:

- stops the rest timer
- discards any in-flight Health workout session
- ends the Live Activity
- deletes the `WorkoutSession`
- dismisses the flow

Canceled sessions never reach summary and never become completed history records.

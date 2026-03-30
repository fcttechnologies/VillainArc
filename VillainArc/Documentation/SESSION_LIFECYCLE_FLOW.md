# Workout Session Lifecycle

This document explains how workout sessions move through the app: where they start, how conflicting flows are blocked, how unfinished work resumes, what happens during live logging, and what changes when a session reaches summary.

## Main Files

- `Data/Services/App/AppRouter.swift`
- `Data/Models/Sessions/WorkoutSession.swift`
- `Data/Models/Sessions/ExercisePerformance.swift`
- `Data/Models/Sessions/SetPerformance.swift`
- `Views/Workout/WorkoutSessionContainer.swift`
- `Views/Workout/WorkoutView.swift`
- `Views/Workout/WorkoutSummaryView.swift`
- `Views/Suggestions/DeferredSuggestionsView.swift`
- `Views/Suggestions/SuggestionReviewView.swift`
- `Data/Services/Workout/RestTimerState.swift`
- `Data/LiveActivity/WorkoutActivityManager.swift`
- `Data/Services/HealthKit/Live/HealthLiveWorkoutSessionCoordinator.swift`

## Session Model

`WorkoutSession` is the root record for an in-progress or completed workout. It owns:

- workout metadata such as title, notes, start/end dates, and hidden state
- lifecycle state through `status`
- optional source `WorkoutPlan`
- optional `PreWorkoutContext`
- child `ExercisePerformance` rows and their `SetPerformance` rows
- `activeExercise` for pager focus and Live Activity state
- `postEffort`
- suggestion events created from that workout
- optional linked `HealthWorkout`

Plan-based sessions are created with `WorkoutSession(from: plan)`. Empty workouts use the default initializer.

## Session States

Sessions move through four states:

`pending -> active -> summary -> done`

- `pending`: blocked on unresolved plan suggestions before logging starts
- `active`: the user is logging the workout
- `summary`: logging is finished and the summary screen is active
- `done`: the summary has been finalized and the workout is now a stable completed record

`WorkoutSessionContainer` is the UI router for those states:

- `.pending` -> `DeferredSuggestionsView`
- `.active` -> `WorkoutView`
- `.summary` and `.done` -> `WorkoutSummaryView`

## Where Sessions Start

### Empty Workout

Normal entry points:

- the home plus menu
- `StartWorkoutIntent`
- Siri / shortcut routes that forward into workout start

All of them end up in `AppRouter.startWorkoutSession()`, which:

- checks that no other active flow exists
- creates a new `WorkoutSession()`
- inserts and saves it
- presents it through `activeWorkoutSession`

### Workout From a Plan

Normal entry points:

- `WorkoutPlanDetailView`
- `StartWorkoutWithPlanIntent`
- `StartTodaysWorkoutIntent`

Those route into `AppRouter.startWorkoutSession(from:)`, which:

- checks that no other active flow exists
- creates `WorkoutSession(from: plan)`
- converts the live session copy from canonical kg into the current display unit
- checks whether the source plan still has pending or deferred suggestion events
- starts the session in `.pending` if unresolved suggestion work exists, otherwise `.active`
- inserts, saves, and presents the session

## Resume Behavior

After onboarding reaches `.ready`, `RootView` calls `AppRouter.checkForUnfinishedData()`.

Resume order is:

1. incomplete `WorkoutSession`
2. resumable incomplete `WorkoutPlan`

The key detail is what "incomplete" means:

- `WorkoutSession.incomplete` is any session whose `status != .done`
- so the app can resume `.pending`, `.active`, or `.summary`

Editing copies of plans are never resumed. `RootView` deletes them during launch cleanup.

## The Pending Suggestion Gate

Plan-based sessions can stop in `DeferredSuggestionsView` before active logging begins.

That happens when the source plan still has suggestion events whose decision is:

- `pending`
- `deferred`

Available actions in `DeferredSuggestionsView`:

- accept one change
- reject one change
- accept all
- skip all

Important detail:

- accepting a suggestion mutates the live plan and hydrates the already-created pending session copy through `hydratePendingSessionCopy(...)`
- rejecting a suggestion only changes decision state
- `Skip All` is not a neutral pause action; it marks remaining pending/deferred suggestions as `rejected` and then lets the workout proceed

The workout only transitions to `.active` once there are no pending or deferred events left.

## Active Workout Phase

`WorkoutView` is the main active-workout screen. It owns:

- the exercise pager
- add/edit exercise flows
- finish and cancel
- rest timer sheet
- workout settings sheet
- pre-workout context sheet
- title and notes editing
- intent/live-activity driven sheet presentation
- the live Apple Health stats sheet when workout write access exists

Main collaborators are:

- `ExerciseView`
- `ExerciseSetRowView`
- `RestTimerState`
- `WorkoutActivityManager`
- `PreWorkoutContextView`
- `WorkoutSettingsView`

Important runtime behavior:

- `activeExercise` tracks which exercise is in focus
- set completion updates the set row plus active runtime state
- the pre-workout sheet auto-opens only when the related app setting is enabled and the feeling is still `.notSet`
- the rest timer is shared app-wide through `RestTimerState`
- the Live Activity mirrors the active incomplete workout

Plan-based sessions also keep historical matching context for later suggestion work:

- `ExercisePerformance.originalTargetSnapshot`
- `SetPerformance.originalTargetSetID`

Those let later flows keep matching logical targets even after plan edits or set reindexing.

## Finishing Active Logging

The finish UI starts in `WorkoutView`, but the model cleanup lives in `WorkoutSession.finish(...)`.

Before a workout can leave the active phase, VillainArc checks `unfinishedSetSummary`, which separates:

- empty sets: no reps and no weight
- logged-but-incomplete sets: data entered, not marked complete

Depending on the situation, the user can:

- mark logged sets complete
- delete unfinished sets
- delete only empty sets
- finish directly when nothing is unfinished

If the chosen cleanup path still leaves a real workout to save, `WorkoutView` can ask for post-workout effort before moving on. That prompt is controlled by `AppSettings.promptForPostWorkoutEffort`.

Pre-workout context prompting is also controlled by settings. If the user never records a feeling, the context remains optional and `.notSet`.

### What `WorkoutSession.finish(...)` Does

`WorkoutSession.finish(...)`:

- applies the chosen unfinished-set cleanup
- prunes empty exercises
- deletes the whole workout if every exercise is removed
- syncs exercise dates to the latest completed set where possible
- sets `status = .summary`
- sets `endedAt`
- clears `activeExercise`

If every exercise is pruned, the workout never reaches summary.

## The Two Summary Stages

Summary work is intentionally split across two moments.

### Stage 1: Leaving Active Logging

After finish cleanup and any effort prompt, `WorkoutView.finishWorkout(...)`:

- runs `WorkoutSession.finish(...)`
- converts set weights back to canonical kg
- saves the workout
- ends the live Apple Health workout session if one is running
- stops the rest timer
- ends the Live Activity

At that point the session is already in `.summary`, but it is not yet finalized as a completed history record.

### Stage 2: Finalizing Summary

`WorkoutSummaryView` is the final orchestration point. It handles:

- summary stats and notes
- display of already-captured post-workout effort
- PR detection
- older suggestion outcome resolution
- new suggestion generation
- current-session suggestion review
- save-as-plan
- `ExerciseHistory` rebuild

For plan-backed sessions, suggestion work runs in this order:

1. `OutcomeResolver.resolveOutcomes(...)`
2. `SuggestionGenerator.generateSuggestions(...)`

The current workout only generates suggestions if it does not already have generated `SuggestionEvent`s.

## Historical Link Cleanup

Plan-backed historical records should stop relying on live plan links once summary work is complete.

`WorkoutSummaryView` calls `cleanupHistoricalPrescriptionLinksIfNeeded()`:

- after suggestion generation finishes
- again during final summary save as a defensive cleanup

That means active-only prescription links may be cleared before the user taps Done, not only at the last save moment.

## What Final Save Means

The true completion point is `WorkoutSummaryView.finishSummary()`. It:

- converts still-`pending` current-session suggestions to `deferred`
- clears active-only prescription links for historical use
- rebuilds `ExerciseHistory`
- sets `workout.status = .done`
- saves
- Spotlight-indexes the completed workout
- dismisses the full-screen flow

That is the point where the workout becomes the stable completed record used by history-driven surfaces.

## Apple Health During Workout Runtime

VillainArc uses a live Apple Health workout session during the local `.active` phase whenever workout write authorization exists.

The live-session rules are:

- the HealthKit session starts when the local workout is active
- if the app resumes an already-active workout, the coordinator first tries to recover the existing HealthKit session
- pending suggestion review does not start Health collection
- the HealthKit session ends when local logging ends and the workout moves to `.summary`
- canceling the workout discards the in-flight Health workout
- if HealthKit returns the saved workout, VillainArc forwards it through the shared mirrored-workout importer and then links it back to the local `HealthWorkout`

The Health workout currently uses:

- activity type `traditionalStrengthTraining`
- indoor workout metadata
- a custom metadata key carrying the local `WorkoutSession.id`
- optional workout effort score linking when that write permission exists

## Save As Workout Plan

`WorkoutSummaryView` can convert a finished workout into a plan.

For a freeform workout, that path:

- creates `WorkoutPlan(from: workout, completed: true)`
- inserts it
- backfills `ExercisePerformance.originalTargetSnapshot` from the performed workout
- links `workout.workoutPlan` to the new plan
- saves and Spotlight-indexes the plan
- reruns suggestion generation because the workout is now plan-backed

This is different from the completed-workout detail path, which opens an editable draft plan instead.

## Canceling a Session

Canceling removes the incomplete session entirely.

Cleanup includes:

- stop the rest timer
- discard any in-flight Apple Health workout session
- end the Live Activity
- delete the `WorkoutSession`
- dismiss the full-screen flow

Canceled sessions never reach summary, never rebuild `ExerciseHistory`, and never become completed workout records.

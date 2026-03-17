# Workout Session Lifecycle

This document explains how workout sessions move through the app: where they start, how VillainArc prevents conflicting flows, how unfinished sessions resume, what happens during logging, and what changes when a session reaches summary.

## Main Files

- `Data/Services/AppRouter.swift`
- `Data/Models/Sessions/WorkoutSession.swift`
- `Data/Models/Sessions/ExercisePerformance.swift`
- `Data/Models/Sessions/SetPerformance.swift`
- `Views/Workout/WorkoutSessionContainer.swift`
- `Views/Workout/WorkoutView.swift`
- `Views/Workout/WorkoutSummaryView.swift`
- `Views/Suggestions/DeferredSuggestionsView.swift`
- `Views/Suggestions/SuggestionReviewView.swift`
- `Data/LiveActivity/WorkoutActivityManager.swift`
- `Data/Services/RestTimerState.swift`

## Session Model

`WorkoutSession` is the root record for a workout in progress or a completed workout. It owns:
- workout metadata such as title, notes, start/end dates, and hidden state
- lifecycle state through `status`
- optional source `WorkoutPlan`
- `PreWorkoutContext`
- child `ExercisePerformance` rows and their `SetPerformance` rows
- `activeExercise` for UI and live-activity state
- `postEffort`
- suggestion events created from that session

Plan-based sessions are created with `WorkoutSession(from: plan)`. Empty workouts use the default initializer.

## Session States

Workout sessions move through four states:

```text
pending -> active -> summary -> done
```

- `pending`: blocked on pre-workout suggestion review
- `active`: the user is logging the workout
- `summary`: logging is finished and the post-workout summary is on screen
- `done`: summary has been finalized and the workout is now a stable completed record

`WorkoutSessionContainer` is the UI router for those states:
- `.pending` -> `DeferredSuggestionsView`
- `.active` -> `WorkoutView`
- `.summary` and `.done` -> `WorkoutSummaryView`

## Where Sessions Start

### Empty Workout

Normal entry points:
- the home plus menu in `ContentView`
- `StartWorkoutIntent`
- Siri start-workout handoff

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

Those all route into `AppRouter.startWorkoutSession(from:)`, which:
- checks that no other active flow exists
- creates `WorkoutSession(from: plan)`
- converts the live session copy from canonical kg into the current user unit
- checks whether the source plan still has `pending` or `deferred` suggestion events
- starts the session in `.pending` if unresolved events exist, otherwise `.active`
- inserts, saves, and presents the session

## Resume Behavior

After onboarding reaches `.ready`, `RootView` calls `AppRouter.checkForUnfinishedData()`.

Resume order is:
1. incomplete `WorkoutSession`
2. resumable incomplete `WorkoutPlan`

The important detail is what "incomplete" means:
- `WorkoutSession.incomplete` is any session whose `status != .done`
- so the app can resume `.pending`, `.active`, or `.summary` sessions

Editing copies of plans are not resumed. `RootView` deletes them during launch cleanup.

## The Pending Suggestion Gate

Plan-based sessions can stop in `DeferredSuggestionsView` before logging starts.

That happens when `pendingSuggestionEvents(for: plan, in: context)` finds any event whose decision is:
- `pending`
- `deferred`

Available actions in `DeferredSuggestionsView`:
- accept one change
- reject one change
- accept all
- skip all

Accepting a suggestion does two things:
- mutates the live `WorkoutPlan`
- hydrates the already-created pending session copy through `acceptGroup(...)` -> `hydratePendingSessionCopy(...)` -> `WorkoutSession.applyAcceptedSuggestionEvent(...)`

That means the workout starts from the accepted target state, not from the stale pre-review session copy.

The session only transitions to `.active` once no pending or deferred events remain.

## Active Workout Phase

`WorkoutView` is the main active-workout screen. It owns:
- the exercise pager
- add exercise
- finish and cancel
- rest timer sheet
- workout settings sheet
- pre-workout context sheet
- title and notes editing
- intent/live-activity sheet presentation

The main runtime collaborators are:
- `ExerciseView`
- `ExerciseSetRowView`
- `RestTimerState`
- `WorkoutActivityManager`
- `PreWorkoutContextView`
- `WorkoutSettingsView`

Important runtime behavior:
- `activeExercise` tracks which exercise is in focus
- set completion updates `complete` and `completedAt`
- `WorkoutView` opens pre-workout context automatically if `feeling == .notSet`
- rest timer state is shared and persisted through `RestTimerState`
- live activity state mirrors the active incomplete session

Plan-based sessions also keep frozen historical context for later suggestion work:
- exercise-level target snapshot through `ExercisePerformance.originalTargetSnapshot`
- set-level historical identity through `SetPerformance.originalTargetSetID`

If the user deletes a trailing plan-backed set during the active workout and then adds a set back, `ExercisePerformance.addSet(...)` first tries to restore the next unused tail `SetPrescription` link instead of always creating an unlinked freeform set. That is how the workout flow preserves target identity for common accidental delete-and-readd cases.

## Finishing Active Logging

The finish UI starts in `WorkoutView`, but the model cleanup lives in `WorkoutSession.finish(...)`.

Before a session can leave the active phase, VillainArc checks `unfinishedSetSummary`, which separates:
- empty sets: no reps and no weight
- logged-but-incomplete sets: data entered, not marked complete

Depending on the situation, the user can:
- mark logged sets complete
- delete unfinished sets
- delete only empty sets
- finish directly when nothing is unfinished

`WorkoutSession.finish(...)` then:
- applies the chosen cleanup
- prunes empty exercises
- deletes the whole workout if every exercise is pruned
- syncs exercise dates to the latest completed set where possible
- defaults pre-workout feeling if it was never set
- sets `status = .summary`
- sets `endedAt`
- clears `activeExercise`

If every exercise is pruned, the workout never reaches summary.

## The Two Summary Stages

Summary work is split across two moments.

### Stage 1: Leaving Active Logging

After `WorkoutSession.finish(...)` succeeds, `WorkoutView.finishWorkout(...)`:
- converts active set weights back to canonical kg
- saves the session
- queues Spotlight indexing for the workout
- stops the rest timer
- ends the live activity

At that point the session is already in `.summary`, but it is not finalized as a completed record yet.

### Stage 2: Finalizing Summary

`WorkoutSummaryView` is the final orchestration point. It handles:
- summary stats and notes
- post-workout effort
- PR detection
- older suggestion outcome resolution
- new suggestion generation
- suggestion review
- save-as-plan
- `ExerciseHistory` rebuild

For plan-based sessions, `generateSuggestionsIfNeeded()` runs once per session. Its order is:

1. `OutcomeResolver.resolveOutcomes(...)`
2. `SuggestionGenerator.generateSuggestions(...)`

The current session only generates suggestions if it does not already have generated `SuggestionEvent`s.

## Historical Link Cleanup

Plan-based historical records should not keep relying on live plan links forever.

`WorkoutSummaryView` calls `cleanupHistoricalPrescriptionLinksIfNeeded()`:
- after suggestion generation finishes
- again during final summary save as a defensive cleanup step

So active-only prescription links may be cleared before the user taps Done, not only at the final save moment.

## What Final Save Means

The real completion point is `WorkoutSummaryView.finishSummary()`. It:
- guards against double-save
- converts any still-`pending` current-session suggestions to `deferred`
- clears active-only prescription links for historical use
- rebuilds exercise histories through `ExerciseHistoryUpdater.updateHistoriesForCompletedWorkout(...)`
- sets `workout.status = .done`
- saves
- dismisses the full-screen workout flow

That is the point where the workout becomes a stable completed record used by history-driven surfaces.

## Save As Workout Plan

`WorkoutSummaryView` can convert a finished workout into a plan.

For a freeform workout, that path:
- creates `WorkoutPlan(from: workout, completed: true)`
- inserts it
- backfills `ExercisePerformance.originalTargetSnapshot` from the performed session
- links `workout.workoutPlan` to the new plan
- saves and Spotlight-indexes the plan
- reruns suggestion generation because the session is now plan-backed

This is different from the workout-detail path, which opens an editable draft plan instead.

## Canceling a Session

Canceling removes the incomplete session entirely.

Common cleanup:
- stop the rest timer
- end the live activity
- delete the `WorkoutSession`
- dismiss the full-screen flow

Canceled sessions never reach summary, never rebuild `ExerciseHistory`, and never become completed workout records.

## Live Activity Hooks

`WorkoutActivityManager` is a view onto the current incomplete session, not a separate lifecycle.

The main hooks are:
- `WorkoutView.onAppear` -> `WorkoutActivityManager.start(workout:)`
- active set, timer, and exercise changes -> `WorkoutActivityManager.update(for:)`
- finish or cancel -> `WorkoutActivityManager.end()`

Live activity controls still operate on the same shared session state:
- add exercise can ask the app to present the add-exercise sheet
- complete set can mutate the active session and auto-start the timer
- rest-timer controls act through `RestTimerState`

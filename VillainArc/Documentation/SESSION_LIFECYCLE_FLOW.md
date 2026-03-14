# Workout Session Lifecycle

This document explains how workout sessions move through the app: where they start, how the app prevents conflicting flows, how sessions resume on launch, what happens during logging, how finish and summary work, and which intents and live-activity actions participate in that lifecycle.

## Main Files

- `Data/Services/AppRouter.swift`
- `Data/Models/Sessions/WorkoutSession.swift`
- `Data/Models/Sessions/ExercisePerformance.swift`
- `Data/Models/Sessions/SetPerformance.swift`
- `Views/Workout/WorkoutSessionContainer.swift`
- `Views/Workout/WorkoutView.swift`
- `Views/Workout/WorkoutSummaryView.swift`
- `Views/Suggestions/DeferredSuggestionsView.swift`
- `Data/LiveActivity/WorkoutActivityManager.swift`
- `Data/Services/RestTimerState.swift`

## Session Model

`WorkoutSession` is the root record for a workout in progress or a completed workout. It owns:
- workout metadata like `title`, `notes`, `startedAt`, and `endedAt`
- lifecycle state through `status`
- the optional source `WorkoutPlan`
- `PreWorkoutContext`
- child `ExercisePerformance` rows and their `SetPerformance` rows
- `activeExercise` for workout UI and live-activity state
- `postEffort`
- any `SuggestionEvent` rows generated from the session

Plan-based sessions are created with `WorkoutSession(from: plan)`. Empty workouts use the default initializer.

## Session States

Workout sessions move through four states:

```text
pending -> active -> summary -> done
```

- `pending`: the session is blocked on pre-workout suggestion review
- `active`: the user is logging the workout
- `summary`: the workout has been finished and is showing post-workout review
- `done`: summary has been finalized and the workout is now a completed record

`Views/Workout/WorkoutSessionContainer.swift` is the UI router for those states:
- `.pending` -> `Views/Suggestions/DeferredSuggestionsView.swift`
- `.active` -> `Views/Workout/WorkoutView.swift`
- `.summary` and `.done` -> `Views/Workout/WorkoutSummaryView.swift`

## Where Sessions Start

There are three main ways a session begins.

### 1. Start an Empty Workout

Common entrypoints:
- home "+" menu in `Views/ContentView.swift`
- `Intents/Workout/StartWorkoutIntent.swift`
- legacy Siri start-workout handoff into `AppRouter`

All of these eventually route into `AppRouter.startWorkoutSession()`, which:
- checks that no active workout or plan flow already exists
- creates a new `WorkoutSession()`
- inserts and saves it
- presents it through `activeWorkoutSession`

### 2. Start From a Workout Plan

Common entrypoints:
- `Views/WorkoutPlan/WorkoutPlanDetailView.swift`
- `Intents/WorkoutPlan/StartWorkoutWithPlanIntent.swift`

These route into `AppRouter.startWorkoutSession(from:)`, which:
- checks that no active flow exists
- creates `WorkoutSession(from: plan)`
- converts set weights from canonical kg into the current user unit before the workout UI starts logging
- inserts and saves it
- sets the session to `.pending` instead of `.active` when the plan already has pending or deferred suggestion events

### 3. Start Today’s Workout From a Split

Common entrypoints:
- `Views/HomeSections/WorkoutSplitSectionView.swift`
- `Intents/WorkoutSplit/StartTodaysWorkoutIntent.swift`

This path resolves the plan from the active split first, then still routes into `AppRouter.startWorkoutSession(from:)`.

## Single Active Flow Rule

VillainArc enforces one active flow at a time through `AppRouter`.

`AppRouter.hasActiveFlow()` blocks new flow entry when any of these are true:
- a workout session is already being presented
- a workout plan flow is already being presented
- an incomplete workout session exists in persistence
- an incomplete workout plan exists in persistence

This is why UI buttons, App Intents, Siri handoffs, and Spotlight routes do not create parallel session/plan flows.

## Launch Resume

After onboarding is ready, `Root/RootView.swift` calls `AppRouter.checkForUnfinishedData()`.

That method:
1. avoids double-presenting if a flow is already on screen
2. checks for an incomplete `WorkoutSession`
3. if none exists, checks for a resumable incomplete `WorkoutPlan`

In normal use there should only be one active flow, but the router still applies this ordering defensively.

If an incomplete workout session exists, the app resumes it by setting `activeWorkoutSession` instead of creating a new one.

## Active Workout Phase

`Views/Workout/WorkoutView.swift` is the main active-workout screen.

During the active phase, the session lifecycle is shaped by:
- exercise pages in `Views/Workout/ExerciseView.swift`
- set rows in `Views/Components/ExerciseSetRowView.swift`
- pre-workout context in `Views/Workout/PreWorkoutContextView.swift`
- rest timer in `Views/Workout/RestTimerView.swift`
- workout settings in `Views/Workout/WorkoutSettingsView.swift`

Important runtime behaviors:
- `activeExercise` tracks which exercise is in focus
- set completion updates `SetPerformance.complete` and `completedAt`
- rest timer behavior goes through `RestTimerState.shared`
- auto-start rest timer uses the set’s effective rest seconds and records recents in `RestTimeHistory`
- plan-based workouts continue carrying live plan references during the active session

Plan-based sessions also preserve frozen historical context:
- exercise-level baseline through `ExercisePerformance.originalTargetSnapshot`
- set-level slot mapping through `SetPerformance.linkedTargetSetIndex`

Those fields matter later for suggestion history, but the details live in `SUGGESTION_AND_OUTCOME_FLOW.md`.

## Finishing a Workout

The finish action begins in `WorkoutView`, but the real finish logic lives in `WorkoutSession.finish(action:context:)`.

Before a session can move to summary, VillainArc resolves incomplete sets. `WorkoutSession.unfinishedSetSummary` separates them into:
- empty sets: no reps and no weight
- logged-but-incomplete sets: user entered data but never marked them complete

Depending on the situation, the finish UI offers actions such as:
- mark logged sets complete
- delete unfinished sets
- delete only empty sets
- finish directly when nothing is unfinished

`WorkoutSession.finish(...)` then:
- applies the chosen cleanup
- prunes empty exercises
- deletes the workout entirely if every exercise is pruned
- sets `status = .summary`
- sets `endedAt`
- clears `activeExercise`

If all exercises are pruned, the result is `.workoutDeleted` and the session never reaches summary.

## Summary Phase

After a successful finish, `WorkoutSessionContainer` routes to `Views/Workout/WorkoutSummaryView.swift`.

This screen is where the session becomes a finalized workout record. It handles:
- summary UI and effort rating
- PR detection using cached `ExerciseHistory`
- older suggestion outcome resolution
- new suggestion generation
- suggestion review
- save-as-plan actions

This document only covers the session-level part of that process:
- older suggestions are evaluated first
- new suggestions may be generated second
- remaining pending suggestions are deferred when summary is finalized

## What “Really Saving” a Workout Means

The final save happens in `WorkoutSummaryView.finishSummary()`.

That method:
1. guards against double-finishing
2. converts any still-pending generated suggestions to `deferred`
3. clears active-only prescription links for plan-based historical use
4. rebuilds exercise history through `ExerciseHistoryUpdater.updateHistoriesForCompletedWorkout(...)`
5. sets `workout.status = .done`
6. saves the context
7. dismisses the full-screen workout flow

That is the point where the workout becomes a stable completed record.

The important side effects are:
- exercise analytics are rebuilt
- exercise Spotlight eligibility may change through the history updater
- plan-based sessions stop depending on active-only prescription links
- undecided suggestions are pushed forward to the next plan-based session as deferred review

## Save As Plan From Summary

`WorkoutSummaryView` can also convert a finished workout into a plan.

That path:
- creates `WorkoutPlan(from: workout, completed: true)`
- links the session back to the created plan
- backfills `originalTargetSnapshot` for freeform exercises so the new plan has a frozen target baseline
- saves and Spotlight-indexes the created plan

This does not replace final summary save. It is an additional action that can happen before the session is finalized as `.done`.

This summary path keeps the direct completed-plan creation flow. The separate "Save as Workout Plan" action from `WorkoutDetailView` instead routes through `AppRouter.createWorkoutPlan(from:)`, opens `WorkoutPlanView`, and converts the new editable plan into the user's current unit for editing.

## Canceling a Session

Cancel flows remove the incomplete session entirely.

The main paths are:
- cancel from `WorkoutView`
- `Intents/Workout/CancelWorkoutIntent.swift`
- Siri cancel-workout handoff through `AppRouter.handleSiriCancelWorkout(...)`

Common cleanup behavior:
- stop the rest timer
- clear the active workout presentation
- delete the session from SwiftData
- end the live activity

Canceled sessions never reach summary, never rebuild exercise history, and never become completed workout records.

## Session-Related Intents

These intents participate directly in the session lifecycle:

### Start / Open

- `StartWorkoutIntent`: creates an empty workout session
- `StartWorkoutWithPlanIntent`: creates a session from a specific completed plan
- `StartTodaysWorkoutIntent`: resolves today’s split plan, then creates the session
- `OpenActiveWorkoutIntent`: foregrounds the app so the active session can resume

### Active Workout Controls

- `OpenPreWorkoutContextIntent`
- `OpenRestTimerIntent`
- `OpenWorkoutSettingsIntent`

These do not create or mutate the session directly. They set router flags so `WorkoutView` opens the relevant sheet inside the active session.

### Set Completion and Finish

- `CompleteActiveSetIntent`: marks the next incomplete set complete, may auto-start rest timer, updates the live activity, and may prewarm Foundation Models near the end of a plan-based session
- `FinishWorkoutIntent`: runs the same finish decision logic as the UI, indexes the workout, stops timer/live activity, and returns to the app
- `CancelWorkoutIntent`: deletes the active incomplete session

## Live Activity Hooks

The workout live activity is managed by `Data/LiveActivity/WorkoutActivityManager.swift`.

The main session-touching hooks are:
- `WorkoutView.onAppear` -> `WorkoutActivityManager.start(workout:)`
- set completion / exercise changes / timer changes -> `WorkoutActivityManager.update(for:)`
- finish or cancel -> `WorkoutActivityManager.end()`

Live activity actions can also mutate the active session:
- `LiveActivityAddExerciseIntent` asks the app to open the add-exercise sheet
- `LiveActivityCompleteSetIntent` completes the next incomplete set, may auto-start rest timer, updates the live activity, and may prewarm Foundation Models near the end of a plan-based session
- pause/resume rest timer live-activity intents act through `RestTimerState`

The live activity is a view onto the current incomplete session, not a separate lifecycle.

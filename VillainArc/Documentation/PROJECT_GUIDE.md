# VillainArc Project Guide

This file is the high-level walkthrough for the app. It explains how the main product areas fit together without going file-by-file. For the structure map, read `Documentation/ARCHITECTURE.md`. For deeper subsystem behavior, use the individual flow docs in this folder, especially `Documentation/ONBOARDING_FLOW.md` and `Documentation/HEALTHKIT_INTEGRATION.md`.

## What VillainArc Is

VillainArc is a SwiftUI + SwiftData workout app for:
- setting up a profile and local/cloud-backed data store
- optionally connecting Apple Health for workout export, workout sync, and richer Health workout details
- creating workout plans and split schedules
- logging live workout sessions
- reviewing plan suggestions after workouts
- tracking exercise progress through cached analytics
- exposing core flows through Spotlight, Shortcuts, widgets, and Live Activities

The main product areas are:
- onboarding and readiness
- home dashboard
- workout sessions
- workout plans
- workout splits
- suggestions and outcomes
- exercise analytics and history

## Launch and Readiness

The startup path is:

1. `Root/VillainArcApp.swift` starts the shared CloudKit import monitor and installs the shared model container.
2. `Root/RootView.swift` runs launch cleanup, refreshes shortcut parameters, starts `OnboardingManager`, and after onboarding reaches `.ready` runs the Apple Health post-ready pass: sync Health workouts first, then reconcile completed sessions that still have no Health link.
3. `OnboardingManager` decides whether this is a first bootstrap or a returning launch.
4. `RootView` only asks `AppRouter` to resume unfinished flows after onboarding reaches `.ready`.

That ordering matters. VillainArc never resumes an unfinished workout or draft plan before bootstrap and profile setup are in a valid state.

### First Bootstrap

On the first launch, onboarding takes the full path:
- check network connectivity
- check iCloud sign-in state
- check CloudKit availability
- wait for `CloudKitImportMonitor` to confirm import completion
- seed or sync the bundled exercise catalog through `DataManager`
- reindex Spotlight
- ensure `AppSettings` and `UserProfile` exist
- either route into profile setup or mark the app ready

The wait-before-seed rule prevents duplicate catalog exercises when existing data is still importing from CloudKit.

### Returning Launch

Once the app has already completed at least one catalog sync, onboarding takes the fast path:
- immediately ensure `AppSettings` and `UserProfile` exist
- route into missing profile steps, or if the profile is already complete run any needed catalog sync and then either offer the optional Apple Health step or mark the app ready

Returning launches still prioritize getting the user back into the app quickly, but they now keep the catalog sync on the main actor and finish it before the app transitions to `.ready`.

### Optional Apple Health Step

After core bootstrap and profile setup are complete, onboarding can optionally offer Apple Health connection:
- request the current Apple Health permission set used by the app
- skip without blocking app access

Apple Health is treated as an integration, not a readiness dependency. Once the app reaches `.ready`, VillainArc runs its Health post-ready pass:
- sync Apple Health workouts into the local `HealthWorkout` mirror
- reconcile any already-completed workouts that still have no Apple Health link

### SetupGuard

Many App Intents can run before the foreground app has gone through the current launch's onboarding path. `SetupGuard` is the shared persistence/readiness boundary for those entrypoints. It verifies:
- the initial catalog bootstrap marker exists
- `AppSettings` exists
- `UserProfile` exists and is complete
- no persisted incomplete workout or plan exists when the intent requires a clean slate

Feature-specific checks still happen after `SetupGuard`.

## Home Screen and Navigation

`Views/ContentView.swift` is the foreground shell. It owns:
- the home `NavigationStack`
- the four home sections
- the bottom-bar plus menu
- the full-screen workout flow
- the full-screen plan flow

The home sections are:
- `WorkoutSplitSectionView`: today's split state and today's plan entry
- `RecentWorkoutSectionView`: latest completed workout and workout-history entry
- `RecentWorkoutPlanSectionView`: latest completed plan and all-plans entry
- `RecentExercisesSectionView`: recently completed exercises based on `ExerciseHistory`

The plus menu exposes two main creation entry points:
- start an empty workout
- create a new workout plan

### The Single Active Flow Rule

`AppRouter` enforces one active flow at a time. Starting a workout or plan is blocked when any of these exist:
- an already presented workout session
- an already presented plan flow
- a persisted incomplete `WorkoutSession`
- a persisted incomplete `WorkoutPlan`

That rule keeps UI actions, Spotlight launches, Siri handoffs, and Shortcuts behavior consistent.

## Workout Sessions

There are three normal session entry paths:
- empty workout from the home plus menu or `StartWorkoutIntent`
- plan-based workout from a plan detail screen or intent
- today's workout from the active split

All of them go through `AppRouter`.

### Empty Workout

`AppRouter.startWorkoutSession()` creates a blank `WorkoutSession`, saves it, and presents it full screen.

### Plan-Based Workout

`AppRouter.startWorkoutSession(from:)` creates `WorkoutSession(from: plan)`, converts the live session copy from canonical kg into the current user unit, and checks whether the source plan still has pending or deferred suggestion events.

If unresolved events exist, the session starts in `.pending` instead of `.active`.

### Session States

`WorkoutSessionContainer` routes the session by state:
- `.pending` -> `DeferredSuggestionsView`
- `.active` -> `WorkoutView`
- `.summary` and `.done` -> `WorkoutSummaryView`

Because `WorkoutSession.incomplete` means `status != .done`, launch resume can reopen any unfinished session state, including `.pending` or `.summary`.

### Working Out

`WorkoutView` is the active logging surface. It owns:
- the horizontal exercise pager
- add exercise
- finish and cancel
- pre-workout context
- rest timer
- workout settings
- title and notes editing
- intent/live-activity sheet presentation

`ExerciseView` and `ExerciseSetRowView` handle most set-level logging behavior.

`RestTimerState` and `WorkoutActivityManager` are shared runtime services:
- the timer persists active state in shared defaults
- live activity mirrors the current active exercise, set, and timer state

### Finishing a Workout

Finish is a two-stage process.

Stage 1 happens in `WorkoutView`:
- resolve unfinished sets
- if `promptForPostWorkoutEffort` is on and the workout will survive, capture post-workout effort before moving on
- prune empty exercises
- delete the workout entirely if nothing meaningful remains
- set the session to `.summary`
- convert live set weights back to canonical kg
- save the session
- end the live Apple Health workout session if one is running and persist the linked `HealthWorkout` when available
- stop the rest timer and live activity

Stage 2 happens in `WorkoutSummaryView`:
- optionally save the workout as a plan
- resolve older suggestion outcomes if the session is plan-backed
- generate new suggestions if the session is plan-backed
- defer any still-pending suggestions when the user finishes summary
- clear active-only prescription links for historical use
- rebuild `ExerciseHistory`
- mark the workout `.done`
- queue Spotlight indexing for the finalized workout
- save and dismiss

The first stage gets the session out of active logging cleanly. The second stage turns it into a stable completed record.

Pre-workout context is now treated as true optional context rather than a required field. If the user never records a feeling, it stays `.notSet`, the detail UI hides the feeling badge, and history/detail surfaces only show explicit pre-workout data that the user actually entered.

`FinishWorkoutIntent` mirrors that ownership boundary. When post-workout effort prompting is enabled, the intent routes back into the active workout UI instead of finishing the session directly. That keeps unfinished-set cleanup choice and effort capture centralized in `WorkoutView` rather than duplicating finish behavior in the intent layer.

### Save As Workout Plan

There are two different save-as-plan paths:

- From `WorkoutSummaryView`, a freeform completed workout can be turned directly into a completed `WorkoutPlan`. That path also backfills target snapshots and then reruns suggestion generation because the session is now plan-backed.
- From `WorkoutDetailView`, a completed workout routes through `AppRouter.createWorkoutPlan(from:)`, which creates an editable incomplete plan draft and opens the plan editor.

### Deleting Workout History

Completed workout deletion is controlled by `AppSettings.retainPerformancesForLearning`:
- when it is on, deleting a completed workout hides it with `isHidden = true`
- when it is off, deleting a completed workout hard-deletes the session and the suggestion-learning records tied to it
- turning the setting off also purges workouts that were previously hidden under the old retention mode

In both modes, the workout is removed from Spotlight first, then `ExerciseHistoryUpdater` rebuilds the affected exercise histories and exercise Spotlight entries.

## Apple Health Integration

VillainArc now uses Apple Health for more than export:
- live workout collection during active logging
- local mirroring of Health workouts into `HealthWorkout`
- merged workout history that can show app workouts and Apple Health workouts together
- richer Health workout detail loaded on demand from HealthKit

The split is:
- `WorkoutSession` stays the app-owned source of truth
- `HealthWorkout` is the local mirror/cache of Apple Health workout summaries

The current Health integration includes:
- versioned permission prompting through `HealthPreferences`
- a live HealthKit workout session during the local `.active` phase
- anchored workout sync through `HealthWorkoutSyncCoordinator`
- relinking by Health metadata plus fallback export reconciliation
- a Health detail loader that fetches the live `HKWorkout` by UUID and conditionally renders richer sections

For the full design, read `Documentation/HEALTHKIT_INTEGRATION.md`.

## Workout Plans

Plans are the reusable blueprint layer of the app.

Main surfaces:
- `WorkoutPlanView`: create/edit flow
- `WorkoutPlanDetailView`: read-only plan detail
- `WorkoutPlansListView`: all plans
- `WorkoutPlanPickerView`: select or clear a plan for a split day
- `WorkoutPlanSuggestionsSheet`: plan-level suggestion review and "awaiting outcome" view

### Creating Plans

Plans can be created from:
- the home plus menu
- the split day plan picker
- a completed workout

Blank plan creation starts as an incomplete draft. A workout-derived plan draft can also start as incomplete and immediately open in the editor.

### Editing Existing Plans

Editing uses a copy-merge workflow:

1. `AppRouter.editWorkoutPlan(_:)` creates a persisted editing copy from the original plan.
2. The copy is converted from canonical kg into the user's current weight unit.
3. `WorkoutPlanView` edits the copy directly.
4. On save, the copy is converted back to kg and `WorkoutPlan.applyEditingCopy(...)` merges it into the original plan.
5. On cancel, the editing copy is deleted and the original remains unchanged.

This protects the original plan and gives the app one place to reconcile unresolved suggestion state that the manual edit invalidates.

While editing an existing plan, re-adding a deleted tail set first tries to restore the next unused tail set identity from the original plan instead of always creating a brand-new set. That preserves set identity for common accidental delete-and-readd cases while still letting field-specific suggestion cleanup run if the restored values are changed.

### Plan Suggestions Sheet

`WorkoutPlanDetailView` can open `WorkoutPlanSuggestionsSheet`, which has two tabs:
- `To Review`: pending or deferred suggestions attached to the plan
- `Awaiting Outcome`: accepted or rejected suggestions whose outcomes are still unresolved

That screen does not generate new suggestions by itself. It is a management surface for plan state that already exists.

## Workout Splits

Splits are the scheduling layer that answers "what should I do today?"

The flow is:
- create a split in `SplitBuilderView`
- manage it in `WorkoutSplitView` / `WorkoutSplitListView`
- edit individual days in `WorkoutSplitDayView`
- assign plans through `WorkoutPlanPickerView`
- surface today's split status and plan through `WorkoutSplitSectionView`

`WorkoutSplit` owns the schedule logic itself:
- weekly mode with a recoverable missed-day offset
- rotation mode with current-position tracking and automatic day refresh
- today's day resolution
- today's workout-plan resolution

The same split state feeds:
- the home split card
- `StartTodaysWorkoutIntent`
- `OpenTodaysPlanIntent`
- `TrainingSummaryIntent`
- Spotlight
- widget surfaces

## Suggestions and Outcomes

The suggestion system is only relevant for plan-backed training. It is the feedback loop between:
- what the plan asked for
- what happened in the workout
- how future prescriptions should change

### Review Flow

There are two review moments.

Before a plan-based workout:
- if the plan still has pending or deferred suggestion events, the new session starts in `.pending`
- `DeferredSuggestionsView` blocks the workout until those events are accepted or rejected
- accepting a change mutates the live plan immediately and hydrates the already-created pending session copy so the workout starts from the accepted target state

After a plan-based workout:
- `WorkoutSummaryView` resolves older outcomes first
- then generates new suggestion events
- then shows the current session's generated suggestions for accept / reject / defer

When summary closes, any still-pending current-session suggestions are converted to `deferred`.

### Outcome Resolution

Outcomes are not finalized after one later workout. `OutcomeResolver` persists one `SuggestionEvaluation` per eligible later session, then finalizes the event once enough evaluations have accumulated.

The key rules are:
- only unresolved events attached to the current plan structure are considered
- deterministic rules run first
- AI is a fallback for lower-confidence cases, but now receives pre/post workout context too
- training-style AI only replaces `.unknown` when its confidence is greater than `0.5`, and it only looks back up to 3 recent performances
- final outcome selection is weighted across accumulated evaluations, not a fixed safety-priority list and not a recency winner-take-all rule
- some mixed 2-session results escalate the event to require a 3rd evaluation instead of finalizing immediately

### Manual Plan Editing and Suggestions

Plan editing is treated as a new source of truth. If a manual edit invalidates a still-unresolved suggestion target, `WorkoutPlan+Editing` deletes that unresolved event instead of keeping stale work around.

For the full suggestion subsystem, read `Documentation/SUGGESTION_AND_OUTCOME_FLOW.md`.

## Exercise Analytics and History

VillainArc separates raw performed work from cached exercise analytics.

- Raw performed work lives in `ExercisePerformance` and `SetPerformance`.
- Cached analytics live in `ExerciseHistory`.

`ExerciseHistoryUpdater` rebuilds that cache:
- when a workout is finalized in summary
- when completed workouts are hidden from history

### User-Facing Exercise Surfaces

- `RecentExercisesSectionView`: top recent exercises on the home screen
- `ExercisesListView`: searchable full exercise browser
- `ExerciseDetailView`: cached analytics, stat cards, and charts
- `ExerciseHistoryView`: raw completed-performance drill-down

This split is intentional:
- `ExerciseDetailView` is fast because it reads the cache
- `ExerciseHistoryView` is literal because it reads completed performances directly

If exercise ordering or analytics look wrong, `ExerciseHistoryUpdater` and `ExerciseHistory` are usually the first places to inspect.

## Spotlight, Shortcuts, Widgets, and Live Activities

These are not separate product areas, but they touch almost every main flow.

### Spotlight

`SpotlightIndexer` indexes:
- completed workouts
- completed plans
- exercises that have completed history
- workout splits

The app re-enters from Spotlight through `AppRouter.handleSpotlight(_:)`.

### App Intents and Shortcuts

Intent entrypoints live under `Intents/`. They generally reuse app logic through `SetupGuard`, `AppRouter`, and the same models/services used by the UI. `IntentDonations.swift` is the shared donation layer.

### Widgets and Live Activities

`WorkoutActivityManager` and the widget extension expose the active session and timer state outside the app. Live-activity controls still route through the same app state instead of creating a separate session model.

### Rest Timer Surfaces

The rest timer is not only an in-app sheet. Timer intents also drive snippet/control surfaces, so timer behavior spans:
- `RestTimerState`
- rest timer intents
- `RestTimerSnippetView`
- live activity controls

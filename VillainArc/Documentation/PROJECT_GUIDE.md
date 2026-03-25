# VillainArc Project Guide

This file is the high-level product walkthrough for the app. It explains what the major product areas are and how they fit together. For the file-level structure map, read `Documentation/ARCHITECTURE.md`.

## What VillainArc Is

VillainArc is a SwiftUI + SwiftData strength-training app centered around:

- first-run setup and optional cloud sync
- reusable workout plans
- weekly or rotating workout splits
- live workout logging
- plan suggestions and later outcome evaluation
- cached exercise analytics
- Apple Health integration for workouts and body mass
- Shortcuts, Spotlight, widgets, and Live Activities built on the same app state

The main product areas are:

- onboarding and readiness
- home navigation and active-flow routing
- workout sessions
- workout plans
- workout splits
- suggestions and outcomes
- exercise analytics
- health history and goals

## Launch and Readiness

The launch path is:

1. `VillainArcApp` installs the shared model container and forwards Spotlight/Siri handoffs.
2. `RootView` starts `OnboardingManager`, cleans up abandoned plan-edit copies, and refreshes shortcut parameters.
3. `OnboardingManager` decides whether the app is doing first bootstrap or a returning launch.
4. Only after onboarding reaches `.ready` does `RootView`:
   - ask `AppRouter` to resume unfinished work
   - start Health observer queries
   - run the first Health sync pass

That ordering matters. VillainArc does not resume persisted incomplete workouts or plans before setup is in a valid state.

### First Bootstrap

On the first launch, VillainArc takes the full setup path:

- check connectivity
- check iCloud sign-in state
- check CloudKit availability
- wait for CloudKit import completion
- seed or sync the bundled exercise catalog
- reindex Spotlight
- ensure `AppSettings` and `UserProfile` exist
- route into profile onboarding, where new users always see the Apple Health step right after the name step
- let the user either connect Apple Health there or choose `Not Now`, which postpones the request until after the required profile fields are done

The wait-before-seed rule prevents duplicate built-in exercises if older cloud data is still importing.

### Returning Launch

Once the catalog bootstrap marker exists, launch takes the faster path:

- ensure `AppSettings`
- ensure `UserProfile`
- route into missing profile steps if needed
- otherwise sync the bundled catalog only if its version changed
- if the current Health type set still needs a request, transition into the standalone Health-permission screen
- otherwise transition directly to `.ready`

### Optional Apple Health Step

Apple Health is not required for the app's long-term use, but the current launch flow does treat the standalone Health-permission prompt as part of readiness for any launch where the current type set still has not crossed the request boundary. VillainArc can offer Health access:

- during onboarding for new users
- after setup for returning users when the current type set still needs a prompt
- later from Settings

For new users, the onboarding Health step is built into the profile flow. Choosing `Not Now` only postpones the request; after the required profile fields are complete, onboarding still transitions into the standalone Health screen because the current type set has not been requested yet.
For any launch that reaches the standalone Health screen, onboarding currently blocks the launch flow until the user taps `Connect to Apple Health` once, after which onboarding moves to `.ready` whether permission was granted or denied.

Once the app is ready, the post-ready Health pass:

- starts workout and body-mass observers
- refreshes background delivery registration
- syncs Health data into local mirrors
- reconciles pending local workout and weight exports

## Foreground Navigation

`ContentView` is the top-level foreground shell. It owns:

- the `TabView`
- the full-screen workout flow
- the full-screen plan flow

The per-tab navigation stacks live inside:

- `HomeTabView`
- `HealthTabView`

`AppRouter` is the shared navigation and active-flow coordinator used by UI flows, intents, Spotlight, and Live Activities.

### The Single Active Flow Rule

VillainArc allows only one active workout-or-plan flow at a time.

Starting a new workout or plan is blocked when any of these exist:

- a presented workout session
- a presented plan flow
- a persisted incomplete `WorkoutSession`
- a persisted incomplete `WorkoutPlan`

That keeps in-app actions, intents, and resume behavior aligned.

## Home Tab

The home tab is the main dashboard for everyday app use.

Its major sections are:

- `WorkoutSplitSectionView`: today's split status and today's plan entry
- `RecentWorkoutSectionView`: latest completed workout and workout-history entry
- `RecentWorkoutPlanSectionView`: latest completed plan and all-plans entry
- `RecentExercisesSectionView`: recent completed exercises from `ExerciseHistory`

The bottom-bar plus menu exposes the two main creation entry points:

- start an empty workout
- create a workout plan

The settings button lives in the home tab, not in the app root.

## Workout Sessions

Workout sessions are the live logging side of the app.

Normal entry paths are:

- start an empty workout from the home tab
- start a workout from a plan
- start today's workout from the active split
- shortcut / intent / Siri entrypoints that route into the same logic

All of them go through `AppRouter`.

### Session States

The workout lifecycle is:

`pending -> active -> summary -> done`

- `pending`: plan workout blocked on deferred/pending suggestions
- `active`: live logging
- `summary`: logging finished, summary screen still active
- `done`: finalized completed record

`WorkoutSessionContainer` routes the UI by state.

### Working Out

`WorkoutView` is the active logging surface. It owns:

- exercise paging
- add/edit exercise actions
- rest timer sheet
- pre-workout context sheet
- workout settings sheet
- finish and cancel
- live Apple Health sheet

Shared runtime services during active logging are:

- `RestTimerState`
- `WorkoutActivityManager`
- `HealthLiveWorkoutSessionCoordinator`

### Finishing a Workout

Finish is split across two phases.

Phase 1 happens in `WorkoutView`:

- resolve unfinished sets
- optionally capture post-workout effort
- prune empty work
- move the session to `.summary`
- convert set weights back to canonical kg
- stop the live Health workout session
- stop the rest timer
- end the Live Activity

Phase 2 happens in `WorkoutSummaryView`:

- show summary stats and notes
- detect PRs
- resolve older suggestion outcomes
- generate new suggestions when the workout is plan-backed
- optionally save the workout as a plan
- rebuild `ExerciseHistory`
- mark the session `.done`
- Spotlight-index the finished workout

### Save As Plan

There are two different "save as plan" paths:

- from `WorkoutSummaryView`, a completed freeform workout can become a completed plan immediately
- from completed workout detail, `AppRouter.createWorkoutPlan(from:)` opens an editable draft plan

## Workout Plans

Workout plans are the reusable prescription layer of the app.

Main surfaces:

- `WorkoutPlanView`: create/edit flow
- `WorkoutPlanDetailView`: read-only detail, favorite/start/edit/delete, suggestion-sheet entry
- `WorkoutPlansListView`: all completed plans
- `WorkoutPlanPickerView`: plan assignment for split days

### Plan Creation

Plans can be created from:

- the home tab
- a completed workout
- split-day assignment flows

New plans are persisted drafts, not temporary view state. That is why unfinished new-plan creation can resume later.

### Editing Existing Plans

Editing a completed plan always uses copy-merge:

1. `AppRouter.editWorkoutPlan(_:)` creates a persisted editing copy.
2. The copy is converted into the user's display weight unit.
3. `WorkoutPlanView` edits the copy directly.
4. Saving converts the copy back to canonical kg and merges it into the original plan.
5. Canceling deletes the copy and leaves the original untouched.

This gives the app one place to clean up unresolved suggestion state invalidated by manual edits.

## Workout Splits

Splits are the scheduling layer that answers "what should I do today?"

The split system includes:

- split creation in `SplitBuilderView`
- split management in `WorkoutSplitView`
- per-day editing in `WorkoutSplitDayView`
- optional plan assignment through `WorkoutPlanPickerView`
- today's split and today's plan surfaced on the home tab

`WorkoutSplit` itself owns the scheduling logic:

- weekly mode with missed-day recovery
- rotation mode with current-position tracking
- today's day resolution
- today's plan resolution

The same state also feeds intents, Spotlight, and widget surfaces.

## Suggestions and Outcomes

The suggestion system is the plan-feedback loop:

- what the plan asked for
- what happened in the workout
- how the plan should change next

### Before a Plan Workout

If a plan still has pending or deferred suggestions:

- `AppRouter.startWorkoutSession(from:)` creates the workout in `.pending`
- `DeferredSuggestionsView` blocks active logging
- accepting a suggestion mutates the plan and hydrates the already-created pending workout copy

### After a Plan Workout

`WorkoutSummaryView` handles plan-backed summary work in this order:

1. resolve older pending outcomes
2. generate new suggestions for the current workout
3. show the new suggestions for accept / reject / defer

Any current-session suggestion still left as `pending` becomes `deferred` when summary is finished.

### Later Outcome Resolution

Outcomes are multi-session, not single-session. `OutcomeResolver` can accumulate more than one `SuggestionEvaluation` before finalizing a result such as:

- `good`
- `tooAggressive`
- `tooEasy`
- `insufficient`
- `ignored`

### Plan-Level Suggestion Sheet

`WorkoutPlanDetailView` can open `WorkoutPlanSuggestionsSheet`, which serves as the plan's suggestion-management surface:

- `To Review`: pending or deferred suggestions
- `Awaiting Outcome`: accepted suggestions whose outcomes are still unresolved

For deeper suggestion behavior, read `Documentation/SUGGESTION_AND_OUTCOME_FLOW.md`.

## Exercise Analytics

VillainArc separates raw performed work from cached analytics.

- Raw workout data lives in `ExercisePerformance` and `SetPerformance`.
- Cached analytics live in `ExerciseHistory`.

The cache powers:

- recent exercise ordering on the home tab
- exercise ordering in the exercise browser
- stat cards in exercise detail
- progression charts
- exercise Spotlight eligibility

`ExerciseHistoryUpdater` rebuilds the cache:

- when a workout is finalized in summary
- when completed workouts are hidden or deleted

The intended split is:

- `ExerciseDetailView` = cached analytics
- `ExerciseHistoryView` = raw completed-performance drill-down

## Health Tab and Apple Health

The Health tab is the app's health-history surface.

Current user-facing areas are:

- weight summary on the tab root
- detailed weight history with multiple time ranges
- active weight-goal summary and goal history
- add-weight-entry flow
- merged workout history that can include Apple Health workouts
- on-demand Health workout detail

Under the hood, VillainArc treats Apple Health as an integration layer:

- `WorkoutSession` remains the app-owned workout source of truth
- `HealthWorkout` is a local mirror/cache of Health workouts
- `WeightEntry` is the single local body-mass record used for both app-created and Health-imported data
- `WeightGoal` is local goal-tracking state for the Health tab

For the full design, read `Documentation/HEALTHKIT_INTEGRATION.md`.

## Spotlight, Shortcuts, Widgets, and Live Activities

These are not separate product areas; they reuse the same app state.

### Spotlight

`SpotlightIndexer` indexes:

- completed workouts
- completed plans
- exercises that have completed history
- workout splits

The app re-enters from Spotlight through `AppRouter`.

### App Intents and Shortcuts

Intent entrypoints live under `Intents/` and generally reuse:

- `SetupGuard`
- `AppRouter`
- the same models and services the UI uses

### Widgets and Live Activities

Widgets and the workout Live Activity project the active workout and timer state outside the app, but they still act on the same shared models and runtime services rather than creating a separate state layer.

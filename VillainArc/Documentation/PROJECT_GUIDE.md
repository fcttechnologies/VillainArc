# VillainArc Project Guide

This is the product-level overview for VillainArc. Read this first to understand what the app is, how the main areas fit together, and which conventions show up everywhere else in the codebase. Then read the specific flow docs for the area you want to work on.

Use these docs in this order:

1. `Documentation/PROJECT_GUIDE.md`
2. `Documentation/ARCHITECTURE.md`
3. the specific flow docs for the feature you want to change

## What VillainArc Is

VillainArc is a SwiftUI + SwiftData strength-training app built around:

- resumable workout logging
- reusable workout plans
- weekly or rotating workout splits
- plan suggestions and later outcome evaluation
- cached exercise analytics
- Apple Health integration for workouts, weight, sleep, daily steps, daily distance, and daily energy
- Shortcuts, home-screen quick actions, Spotlight, widgets, and Live Activities that reuse the same app state

The main product areas are:

- onboarding and readiness
- home navigation and active-flow routing
- workout sessions
- workout plans and plan editing
- workout splits
- training condition status and history
- suggestions and outcomes
- exercise analytics
- health history, goals, and notifications

## App Shell

After onboarding is ready, `Views/AppShell/ContentView.swift` owns:

- the root `TabView` (`Home`, `Health`)
- full-screen workout flow
- full-screen workout-plan flow
- full-screen weight-goal-completion flow

## App-Wide Conventions

These rules are important because they shape most of the codebase.

### One Active Authoring Flow

VillainArc allows only one active workout-or-plan flow at a time.

Starting a new workout or plan is blocked when any of these exist:

- a presented workout session
- a presented plan flow
- a persisted incomplete `WorkoutSession`
- a persisted incomplete `WorkoutPlan`

This keeps UI flows, intents, Spotlight entry points, and resume behavior aligned.

Quick actions follow the same rule too:

- `Start Today's Workout` only runs when no workout or plan flow is already active
- `Add Weight Entry` routes into the Health tab and presents the same sheet the foreground UI uses

### Persist Real Drafts, Not Temporary State

Incomplete workouts and new-plan drafts are persisted SwiftData records, not temporary view-only state.

That is why:

- unfinished workout sessions can resume
- unfinished new-plan creation can resume
- edit copies of existing plans can be cleaned up safely on launch

### Store Canonical Values, Present User Units

Persisted load values are stored canonically in kilograms.

The app converts to the user’s preferred display unit when editing or presenting data and converts back to canonical values before save. This keeps calculations and merges stable even when the user changes unit preferences later.

The same general rule applies to Health caches:

- distance is stored canonically in meters
- energy and step values are stored as raw numeric totals for the day

### Goals Are Date-Ranged and Historical

Health goals are historical records, not mutable singleton flags.

Current goal patterns are:

- `WeightGoal` uses start/end timestamps and allows only one active goal at a time through app logic
- `StepsGoal` uses start/end calendar days and also keeps one active goal at a time through app logic

Replacing a goal does not mutate the old goal into the new goal. The app ends or deletes the old active record and inserts a new one. That preserves history and keeps charts and summaries date-correct.

### Training Condition Is Historical Context

Training condition is also stored as historical truth, not as a mutable singleton flag.

The current pattern is:

- `TrainingConditionPeriod` uses `startDate` and optional `endDate`
- only one active non-normal condition exists at a time through app logic
- ending a condition returns the user to the default "training normally" state without inserting a fake `normal` row
- replacing a condition ends the previous active period and creates a new one only when the kind actually changes

This keeps later split resolution, session adjustment, and suggestion reasoning grounded in real timestamps instead of whichever condition happens to be active today.

### Singletons Are Explicit Models

VillainArc keeps true singleton-style records in SwiftData:

- `AppSettings`
- `UserProfile`
- `HealthSyncState`

Startup code ensures they exist before the app treats launch as ready.

### Apple Health Is an Integration Layer

Apple Health is not the app’s primary source of truth.

The split is:

- `WorkoutSession` remains the app-owned training record
- `HealthWorkout` is a local Apple Health mirror/cache
- `WeightEntry` is the app’s local weight history model, which can also link to Apple Health samples
- `HealthSleepNight` is a per-wake-day Apple Health sleep rollup cache
- `HealthSleepBlock` is the persisted per-block sleep detail layer for naps and same-day secondary sleep blocks
- `HealthStepsDistance` and `HealthEnergy` are per-day Health caches
- `WeightGoal` and `StepsGoal` are local app models

This keeps the app’s own domain logic independent from HealthKit while still letting Health data enrich the app.

### Background Sync Is Opportunistic

VillainArc installs Health observers and enables Health background delivery where available, but background updates are still best-effort. The app always needs a good foreground recovery path.

That is why the ready/settings flow also:

- reinstalls any missing observers
- refreshes Health background delivery registration
- runs a full Health sync and export reconciliation pass

## Launch and Readiness

The high-level launch path is:

1. `VillainArcApp` installs the shared model container and forwards Spotlight/Siri handoffs.
2. The app delegate reinstalls Health observers on process launch.
3. `RootView` starts `OnboardingManager`, cleans up abandoned plan-edit copies, and refreshes shortcut parameters.
4. `OnboardingManager` decides whether this is first bootstrap or a returning launch.
5. Only after onboarding reaches `.ready` does `RootView`:
   - ask `AppRouter` to resume unfinished work
   - reinstall any missing Health observers
   - refresh Health background delivery registration
   - run the full Health sync plus export-reconciliation pass
   - request local-notification permission if it has not been requested yet

That ordering matters. VillainArc does not resume unfinished work before setup is valid.

## First Bootstrap

On the first launch, VillainArc takes the full setup path:

- check connectivity
- check iCloud sign-in state
- check CloudKit availability
- wait for CloudKit import completion
- seed or sync the bundled exercise catalog
- reindex Spotlight
- ensure singleton records exist
- route into profile onboarding

The wait-before-seed rule prevents duplicate built-in exercises if older cloud data is still importing.

Note:

- if the user chooses `Continue Without iCloud`, the app still seeds locally and continues onboarding, but it does not perform the first-bootstrap Spotlight reindex pass in that path

## Returning Launch

Once the exercise-catalog bootstrap marker exists, launch is faster:

- ensure singleton records exist
- route into missing profile steps if needed
- sync the bundled exercise catalog only if its version changed
- decide whether the current Health permissions version still needs a one-time prompt
- otherwise transition directly to `.ready`

## Main Product Areas

### Workout Sessions

Workout sessions are the live logging flow. They move through:

`pending -> active -> summary -> done`

- `pending` is the pre-workout suggestion gate for plan-backed sessions
- `active` is live logging
- `summary` is the finished-but-not-finalized stage
- `done` is the stable completed record

See:

- `Documentation/SESSION_LIFECYCLE_FLOW.md`
- `Documentation/SUGGESTION_AND_OUTCOME_FLOW.md`

### Workout Plans

Workout plans are reusable prescriptions. New plans are persisted drafts. Existing completed plans are never edited in place; the app uses copy-merge editing.

See:

- `Documentation/PLAN_EDITING_FLOW.md`

### Workout Splits

Splits answer “what should I do today?” and can point to plans. The app supports weekly and rotation scheduling. Home surfaces use split state to show today’s plan or rest status.

### Suggestions and Outcomes

Suggestions are persisted coaching events attached to plan structure. Users review them in summary, at the deferred pre-workout gate, or from the plan suggestions sheet. Outcomes are resolved later from future workouts.

Exercise-level catalog settings can globally disable suggestion generation for a specific exercise. When that happens, VillainArc:

- stops generating new suggestions for that exercise everywhere
- hides progression-step tuning in the exercise suggestion settings sheet
- deletes unresolved suggestion state for that exercise when the user saves the setting

See:

- `Documentation/SUGGESTION_AND_OUTCOME_FLOW.md`

### Exercise Analytics

Exercise analytics are cache-backed. `ExerciseHistory` stores derived per-exercise aggregates and progression points, while raw completed performances still back the detailed history drill-down.

See:

- `Documentation/EXERCISE_HISTORY_FLOW.md`

### Health History and Goals

The Health tab combines:

- a top training condition status row with an editor sheet and condition history
- a latest sleep summary card backed by cached nightly sleep
- a dedicated sleep history screen with a day stage view, cached week/month block charts, grouped broader-range charts, weekday averages, and sleep highlights
- weight history with intraday day view plus weight goals
- daily steps and distance history with intraday day view plus steps goals
- daily energy history with intraday day view

That surface is also reused by App Intents and quick actions:

- read-only health intents answer from the same local caches and app-owned records the Health tab uses
- foreground health intents route into the same navigation destinations and sheets as the Health tab UI
- the home-screen `Add Weight Entry` quick action opens the Health add-weight sheet once the app is ready

Notification behavior is part of that surface:

- rest timer completions
- steps goal and coaching events, including double goal, triple goal, and new-best milestones when the app can observe the Health update in time

Home-tab navigation also includes workout-centric history/detail routes such as:

- completed workout history (`WorkoutsListView`)
- Apple Health workout detail (`HealthWorkoutDetailView`)

See:

- `Documentation/HEALTHKIT_INTEGRATION.md`

## Where To Read Next

If you are changing:

- launch, bootstrap, or readiness behavior:
  - `Documentation/ONBOARDING_FLOW.md`
- Health syncing, observers, or Health-backed UI:
  - `Documentation/HEALTHKIT_INTEGRATION.md`
- workout logging, finish flow, or resume behavior:
  - `Documentation/SESSION_LIFECYCLE_FLOW.md`
- plan authoring or edit-copy behavior:
  - `Documentation/PLAN_EDITING_FLOW.md`
- suggestions or outcome evaluation:
  - `Documentation/SUGGESTION_AND_OUTCOME_FLOW.md`
- cached exercise analytics:
  - `Documentation/EXERCISE_HISTORY_FLOW.md`
- future feature planning or release sequencing:
  - `Documentation/PRODUCT_ROADMAP.md`

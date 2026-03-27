# VillainArc Architecture

This file is the structure map for the app. Use it to understand the major layers, which files own which responsibilities, and how data and flows connect. For a product-level walkthrough, read `Documentation/PROJECT_GUIDE.md`. For deeper behavior, use the flow docs in this folder.

## Read Order

1. App shell and startup
2. Persistence and bootstrap
3. Core domain models
4. Runtime services and feature surfaces
5. Integrations

## App Shell and Startup

### `Root/VillainArcApp.swift`

- App entry point.
- Installs `SharedModelContainer.container`.
- Forwards Spotlight and Siri handoffs into `AppRouter.shared`.
- Does not own onboarding or navigation state beyond booting `RootView`.

### `Root/RootView.swift`

- Launch coordinator for the foreground app.
- Starts `OnboardingManager`, deletes abandoned plan-editing copies, refreshes shortcut parameters, and only resumes persisted unfinished work after onboarding reaches `.ready`.
- Starts the Health observer pipeline plus the first post-ready sync pass when onboarding finishes.
- Presents `Views/Onboarding/OnboardingView.swift` as the blocking setup sheet.

### `Views/ContentView.swift`

- Top-level foreground shell after launch is ready.
- Hosts the root `TabView` and the app-level full-screen flows:
  - `activeWorkoutSession` -> `Views/Workout/WorkoutSessionContainer.swift`
  - `activeWorkoutPlan` -> `Views/WorkoutPlan/WorkoutPlanView.swift`
  - `activeWeightGoalCompletion` -> `Views/Health/WeightGoalCompletionView.swift`
- Does not own the per-tab `NavigationStack`s.

### `Views/HomeTabView.swift`

- Home tab navigation shell.
- Owns the home `NavigationStack`, home destinations, settings sheet, and the bottom-bar plus menu for starting workouts and creating plans.
- Routes detailed navigation through `AppRouter.homeTabPath`.

### `Views/Health/HealthTabView.swift`

- Health tab navigation shell.
- Owns the Health `NavigationStack`, the add-weight-entry sheet, and health-specific destinations such as weight history, all weight entries, and weight goals.
- Routes detailed navigation through `AppRouter.healthTabPath`.

### `Data/Services/AppRouter.swift`

- Global navigation and active-flow coordinator.
- Owns:
  - home and health navigation paths
  - current tab selection
  - the single active workout flow
  - the single active plan flow
  - the active weight-goal completion presentation
  - the original-plan pointer for edit-copy flows
  - intent/live-activity flags that feature views listen to
- Enforces the app-wide single-active-flow rule by checking both presented state and persisted incomplete flows.

## Persistence and Bootstrap

### `Data/SharedModelContainer.swift`

- Shared SwiftData schema and app-group backed `ModelContainer`.
- Stores app data in the app-group container and enables private CloudKit sync.
- Defines the full schema used by the main app, intents, widgets, and Live Activity surfaces.

### `Data/Services/OnboardingManager.swift`

- First-run and returning-launch readiness state machine.
- Handles:
  - connectivity checks
  - iCloud / CloudKit checks
  - CloudKit import waiting on first bootstrap
  - exercise catalog seeding and sync
  - singleton record creation
  - profile onboarding
  - optional Apple Health prompt timing

### `Data/Services/CloudKitImportMonitor.swift`

- Watches `NSPersistentCloudKitContainer` import events during first bootstrap.
- Lets onboarding wait for import completion before seeding the bundled exercise catalog.

### `Data/Services/DataManager.swift`

- Exercise catalog sync service.
- Seeds missing built-in exercises, updates changed catalog metadata, and propagates metadata changes into stored prescriptions and performances.
- Also owns the bootstrap marker through `exerciseCatalogVersionKey`.

### `Data/Services/SystemState.swift`

- Ensures `AppSettings` and `UserProfile` exist.
- Used by onboarding and other startup-safe code paths.

### `Data/Services/SetupGuard.swift`

- Readiness boundary for App Intents.
- Verifies bootstrap completed, singleton records exist, the user profile is complete, and optionally that no incomplete workout or plan exists.

## Core Domain Models

### `Data/Models/Sessions/WorkoutSession.swift`

- Root workout aggregate.
- Owns:
  - workout metadata
  - lifecycle state (`pending`, `active`, `summary`, `done`)
  - optional source `WorkoutPlan`
  - `PreWorkoutContext`
  - performed exercises and sets
  - active exercise focus
  - post-workout effort
  - created suggestion events
  - optional linked `HealthWorkout`
- Defines finish-time cleanup and the plan-to-live-session copy path.

### `Data/Models/Sessions/ExercisePerformance.swift`

- Per-exercise performed record inside a workout.
- Carries copied exercise metadata, target snapshots, live prescription links while active, and completed set data used later by suggestions and history rebuilding.

### `Data/Models/Sessions/SetPerformance.swift`

- Per-set performed data.
- Stores completion state, actual reps/load/rest/RPE, the live `SetPrescription` link while active, and `originalTargetSetID` for later historical matching.

### `Data/Models/Sessions/PreWorkoutContext.swift`

- Optional pre-workout state attached to a workout.
- Stores feeling, pre-workout supplement state, and notes.

### `Data/Models/Plans/WorkoutPlan.swift`

- Root workout-plan aggregate.
- Owns exercises, split links, completion/editing state, and sessions created from the plan.

### `Data/Models/Plans/WorkoutPlan+Editing.swift`

- Copy-merge editing workflow for existing plans.
- Creates persisted editing copies, reconciles unresolved suggestion state invalidated by manual edits, merges changes back into the original, and deletes removed children.

### `Data/Models/Plans/ExercisePrescription.swift`

- Per-exercise plan prescription.
- Carries copied exercise metadata, rep-range policy, live active-session links, and suggestion events attached at the exercise scope.

### `Data/Models/Plans/SetPrescription.swift`

- Per-set plan target.
- Stores set type, target load/reps/rest/RPE, active set-performance link while a workout is live, and set-scoped suggestion events.

### `Data/Models/Suggestions/SuggestionEvent.swift`

- Persisted suggestion unit.
- Owns:
  - source session
  - live target exercise and optional target set
  - trigger performance
  - decision state
  - outcome state
  - required evaluation count
  - training style
  - confidence and reasoning
  - optional frozen `weightStepUsed`
  - child `PrescriptionChange` rows

### `Data/Models/Suggestions/SuggestionEvaluation.swift`

- One later-workout evaluation pass for one suggestion event.
- Used by multi-session outcome resolution.

### `Data/Models/Exercise/Exercise.swift`

- Canonical exercise catalog row.
- Owns search metadata, alternate names, favorites, picker recency, equipment defaults, and built-in versus custom identity.

### `Data/Models/Exercise/ExerciseHistory.swift`

- Cached analytics row keyed by `catalogID`.
- Stores completed-workout recency, totals, PR-style aggregates, and progression points.
- Powers recent exercise ordering, exercise detail stats, and exercise Spotlight eligibility.

### `Data/Models/WorkoutSplit/WorkoutSplit.swift`

- Split scheduling aggregate.
- Owns weekly or rotation scheduling state, active split behavior, and "today" resolution.

### `Data/Models/WorkoutSplit/WorkoutSplitDay.swift`

- One day inside a split.
- Stores day order, rest-day state, target muscles, and optional assigned plan.

### `Data/Models/Health/HealthWorkout.swift`

- Local mirror/cache of an Apple Health workout summary.
- Stores Health workout identity, linked `WorkoutSession` when available, cached summary values, source name, and Health availability state.

### `Data/Models/Health/WeightEntry.swift`

- Local body-mass record used by the Health tab.
- Can represent:
  - a local-only entry
  - an app-created entry linked to Apple Health
  - a Health-imported entry

### `Data/Models/Health/WeightGoal.swift`

- Local weight-goal record for the Health tab.
- Stores a stable local goal ID, goal type, start/end dates, target weight, optional target date, optional target pace, and end reason when replaced or finished.

### `Data/Models/AppSettings.swift`

- Singleton app settings.
- Holds unit preferences, timer behavior, workout prompts, retention settings, Apple Health removed-data retention, and Live Activity / notification settings.

### `Data/Models/UserProfile.swift`

- Singleton profile used by onboarding, readiness checks, and some Apple Health prefill.

## Runtime Services

### Workout Runtime

- `Views/Workout/WorkoutSessionContainer.swift`
  - State router for `pending`, `active`, `summary`, and `done`.
- `Views/Workout/WorkoutView.swift`
  - Active logging surface and owner of finish/cancel flow, sheets, and runtime hooks.
- `Views/Workout/WorkoutSummaryView.swift`
  - Summary/finalization orchestrator for PRs, suggestion generation, save-as-plan, history rebuild, and final completion.
- `Data/Services/RestTimerState.swift`
  - Shared rest timer state persisted in shared defaults.
- `Data/LiveActivity/WorkoutActivityManager.swift`
  - Live Activity projection of the active workout and timer state.
- `Data/Services/HealthKit/HealthLiveWorkoutSessionCoordinator.swift`
  - Live Apple Health workout session manager during local active logging.

### Suggestions and Outcomes

- `Data/Services/Suggestions/Generation/SuggestionGenerator.swift`
  - Top-level suggestion generation entrypoint.
- `Data/Services/Suggestions/Generation/RuleEngine.swift`
  - Deterministic suggestion rules.
- `Data/Services/Suggestions/Generation/SuggestionDeduplicator.swift`
  - Deduplicates or suppresses conflicting drafts.
- `Data/Services/Suggestions/Outcomes/OutcomeResolver.swift`
  - Resolves older pending outcomes against later workouts.
- `Data/Services/Suggestions/Outcomes/OutcomeRuleEngine.swift`
  - Deterministic outcome logic.
- `Views/Suggestions/DeferredSuggestionsView.swift`
  - Pre-workout gate for pending/deferred plan suggestions.
- `Views/Suggestions/SuggestionReviewView.swift`
  - Shared accept/reject/defer UI and mutation helpers.
- `Views/Suggestions/WorkoutPlanSuggestionsSheet.swift`
  - Plan-level view into reviewable and awaiting-outcome suggestion state.

### Exercise Analytics

- `Data/Services/ExerciseHistoryUpdater.swift`
  - Rebuilds `ExerciseHistory` after completion or deletion flows.
- `Views/Exercise/ExercisesListView.swift`
  - Searchable exercise browser ordered by cached completed-workout recency.
- `Views/Exercise/ExerciseDetailView.swift`
  - Cached analytics detail screen with chart metric switching.
- `Views/Exercise/ExerciseHistoryView.swift`
  - Raw completed-performance drill-down.
- `Views/HomeSections/RecentExercisesSectionView.swift`
  - Home card backed by `ExerciseHistory`, not picker recency.

### Plans and Splits

- `Views/WorkoutPlan/WorkoutPlanView.swift`
  - Create/edit plan flow.
- `Views/WorkoutPlan/WorkoutPlanDetailView.swift`
  - Read-only plan detail, favorite/start/edit/delete actions, and suggestion-sheet entry.
- `Views/WorkoutSplit/WorkoutSplitView.swift`
  - Split management surface.
- `Views/WorkoutSplit/WorkoutSplitDayView.swift`
  - Per-day editing and plan assignment.
- `Views/HomeSections/WorkoutSplitSectionView.swift`
  - Home card for today's split state and today's plan entry.

### Health Surfaces

- `Views/Health/HealthTabView.swift`
  - Health tab root.
- `Views/Health/WeightSectionCard.swift`
  - Health tab summary card for weight.
- `Views/Health/WeightHistoryView.swift`
  - Detailed weight chart, cached multi-range time-series view, active goal summary, and goal-aware metadata.
- `Views/Health/AllWeightEntriesListView.swift`
  - Full list of stored weight entries.
- `Views/Health/WeightGoalSummaryCard.swift`
  - Reusable active-goal summary card and compact goal progress chart.
- `Views/Health/WeightGoalHistoryView.swift`
  - History of active and ended weight goals with reusable mini progress charts.
- `Views/Health/WeightGoalCompletionView.swift`
  - App-level full-screen goal completion flow for achieved, manual-override, and same-day delete cases.
- `Views/Workout/HealthWorkoutDetailView.swift`
  - On-demand Health workout detail.
- `Helpers/TimeSeriesCharting.swift`
  - Shared chart bucketing, axis labeling, and time-series helpers used by weight and exercise analytics.

## Integrations

### Apple Health

- `Data/Services/HealthKit/HealthAuthorizationManager.swift`
  - Health availability, status, request boundary, and metadata helpers.
- `Data/Services/HealthKit/HealthStoreUpdateCoordinator.swift`
  - Observer registration, background delivery registration, and serialized Health sync entrypoint.
- `Data/Services/HealthKit/HealthSyncCoordinator.swift`
  - Anchored sync for workouts and body mass.
- `Data/Services/HealthKit/HealthExportCoordinator.swift`
  - Reconciliation-aware export/repair path for completed workouts and weight entries.
- `Data/Services/HealthKit/HealthWorkoutDetailLoader.swift`
  - On-demand richer Health workout detail loading.
- `Data/Services/HealthKit/HealthPreferences.swift`
  - Shared-defaults storage for Health sync anchors.

### Spotlight and App Intents

- `Data/Services/SpotlightIndexer.swift`
  - Indexes completed workouts, completed plans, history-backed exercises, and splits.
- `Intents/Workout/*`, `Intents/WorkoutPlan/*`, `Intents/WorkoutSplit/*`, `Intents/Exercise/*`, `Intents/RestTimer/*`
  - App Intent entrypoints that reuse `SetupGuard`, `AppRouter`, and the same models/services used by the UI.
- `Intents/VillainArcShortcuts.swift`
  - Top-level shortcut declarations.
- `Intents/IntentDonations.swift`
  - Donation helpers shared across flows.

### Widgets and Live Activities

- `VillainArcWidgetExtension/*`
  - Widget and Live Activity UI.
- `Data/LiveActivity/WorkoutActivityAttributes.swift`
  - Shared ActivityKit model.
- `Data/LiveActivity/WorkoutActivityManager.swift`
  - Activity lifecycle and state synchronization.

### AI Helpers

- `Data/Services/AI/Suggestions/AITrainingStyleClassifier.swift`
  - Fallback classifier when deterministic training-style detection is unknown.
- `Data/Services/AI/Outcomes/AIOutcomeInferrer.swift`
  - Fallback evaluator for lower-confidence outcome cases.
- `Data/Services/AI/Shared/FoundationModelPrewarmer.swift`
  - Prewarms on-device model usage near likely suggestion/outcome entry points.

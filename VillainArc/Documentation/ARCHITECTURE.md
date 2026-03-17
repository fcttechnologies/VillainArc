# VillainArc Architecture

This file is the structure map for the app. Use it to find the main coordinators, domain models, and cross-cutting services. For the user-facing walkthrough, read `Documentation/PROJECT_GUIDE.md`. For subsystem details, use the individual flow docs in this folder.

## Read Order

1. App shell and startup
2. Workout and plan models
3. Suggestions, history, and splits
4. Integrations and tests

## App Shell and Startup

### `Root/VillainArcApp.swift`
- App entry point.
- Starts `CloudKitImportMonitor.shared`, installs `SharedModelContainer.container`, and forwards Spotlight plus Siri handoffs into `AppRouter.shared`.
- Read with: `Root/RootView.swift`, `Data/SharedModelContainer.swift`, `Data/Services/AppRouter.swift`.

Note: the `com.villainarc.siri.endWorkout` activity is registered here, but it currently has no handler logic.

### `Root/RootView.swift`
- Startup coordinator.
- Owns `OnboardingManager`, cleans up abandoned plan editing copies, refreshes shortcut parameters, starts onboarding, and only resumes unfinished flows after onboarding reaches `.ready`.
- Presents `Views/Onboarding/OnboardingView.swift` as the blocking setup sheet.
- Read with: `Data/Services/OnboardingManager.swift`, `Views/ContentView.swift`.

### `Views/ContentView.swift`
- Foreground shell after startup is ready.
- Owns the home `NavigationStack`, home sections, stack destinations, and the two full-screen active flows:
  - `activeWorkoutSession` -> `Views/Workout/WorkoutSessionContainer.swift`
  - `activeWorkoutPlan` -> `Views/WorkoutPlan/WorkoutPlanView.swift`
- Read with: `Data/Services/AppRouter.swift`.

### `Data/Services/AppRouter.swift`
- Global navigation and active-flow coordinator.
- Owns stack navigation, active workout presentation, active plan presentation, the original-plan pointer for edit-copy flows, and intent/live-activity flags consumed by feature views.
- Guards new flow creation against both presented flows and persisted incomplete flows.
- Read with: `Views/ContentView.swift`, `Views/Workout/WorkoutView.swift`, `Views/WorkoutSplit/WorkoutSplitView.swift`, intent entrypoints under `Intents/`.

### `Data/SharedModelContainer.swift`
- Shared SwiftData schema and app-group backed `ModelContainer`.
- Defines the app's full schema and points persistence at the shared store plus private CloudKit database.
- Read with: every `@Model` change, widget/intents work, and onboarding/bootstrap code.

## Bootstrap and Readiness

### `Data/Services/OnboardingManager.swift`
- First-run and returning-launch state machine.
- First bootstrap path: connectivity -> iCloud status -> CloudKit availability -> wait for import -> seed catalog -> reindex Spotlight -> ensure singleton records -> route into profile onboarding or ready.
- Returning-launch path: optionally kick off background catalog sync, then immediately ensure singleton records and route into profile onboarding or ready.
- Read with: `Views/Onboarding/OnboardingView.swift`, `Data/Services/CloudKitImportMonitor.swift`, `Data/Services/DataManager.swift`.

### `Views/Onboarding/OnboardingView.swift`
- Bootstrap and profile setup UI.
- Renders blocking states such as no network, no iCloud, CloudKit issues, syncing, and generic bootstrap errors, then drives the profile steps for name, birthday, and height.
- Read with: `Data/Models/UserProfile.swift`, `Data/Services/OnboardingManager.swift`.

### `Data/Services/CloudKitImportMonitor.swift`
- Tracks SwiftData CloudKit import completion.
- Lets onboarding wait for existing cloud data before seeding the bundled exercise catalog.
- Read with: `Root/VillainArcApp.swift`, `Data/Services/OnboardingManager.swift`.

### `Data/Services/DataManager.swift`
- Exercise catalog sync and persistence helpers.
- Seeds or updates built-in exercises, propagates catalog metadata into stored prescriptions and performances, and provides shared `saveContext()` / `scheduleSave()`.
- Read with: `Data/Models/Exercise/Exercise.swift`, `Data/Models/Exercise/ExerciseCatalog.swift`.

### `Data/Services/SystemState.swift`
- Lazy singleton-record creation for `AppSettings` and `UserProfile`.
- Read with: `Data/Models/AppSettings.swift`, `Data/Models/UserProfile.swift`.

### `Data/Services/SetupGuard.swift`
- Shared readiness guard for App Intents.
- Ensures bootstrap completed, singleton records exist, profile onboarding is complete, and optionally that no persisted incomplete workout or plan exists.
- Read with: intent files under `Intents/`.

## Core Domain Models

### `Data/Models/Sessions/WorkoutSession.swift`
- Root workout aggregate.
- Owns session metadata, lifecycle state, linked plan, pre-workout context, active exercise, performed exercises, and generated suggestion events.
- Handles finish-time cleanup, pruning, and conversion from a plan into a live session copy.
- Read with: `Views/Workout/WorkoutSessionContainer.swift`, `Views/Workout/WorkoutView.swift`, `Views/Workout/WorkoutSummaryView.swift`.

### `Data/Models/Sessions/ExercisePerformance.swift`
- Per-exercise performed record inside a workout session.
- Carries copied exercise metadata, live prescription links, frozen target snapshots, and set rows.
- Read with: `Data/Models/Sessions/SetPerformance.swift`, `Data/Models/Suggestions/SuggestionSnapshots.swift`.

### `Data/Models/Sessions/SetPerformance.swift`
- Per-set performed data.
- Stores completion state, actual reps/weight/rest/RPE, the live `SetPrescription` link while the session is active, and `originalTargetSetID` for historical matching after plan edits or reindexing.
- Read with: `Views/Components/ExerciseSetRowView.swift`, `Data/Models/Plans/SetPrescription.swift`.

### `Data/Models/Sessions/PreWorkoutContext.swift`
- Pre-workout feeling, supplement toggle, and notes attached to a session.
- Read with: `Views/Workout/PreWorkoutContextView.swift`, `Views/Workout/WorkoutDetailView.swift`.

### `Data/Models/Plans/WorkoutPlan.swift`
- Root workout-plan aggregate.
- Owns exercises, split assignments, completion/editing state, and the create-from-session path.
- Read with: `Data/Models/Plans/WorkoutPlan+Editing.swift`, `Views/WorkoutPlan/WorkoutPlanView.swift`, `Views/WorkoutPlan/WorkoutPlanDetailView.swift`.

### `Data/Models/Plans/WorkoutPlan+Editing.swift`
- Copy-merge editing workflow for existing plans.
- Creates persisted editing copies, reconciles stale unresolved suggestion state, merges the edited copy back into the original, and removes invalidated children.
- Read with: `Documentation/PLAN_EDITING_FLOW.md`, `Views/WorkoutPlan/WorkoutPlanView.swift`.

### `Data/Models/Plans/ExercisePrescription.swift`
- Per-exercise plan prescription.
- Carries copied exercise metadata, rep-range policy, active session link, and attached suggestion events.
- Read with: `Data/Models/Plans/SetPrescription.swift`, `Data/Models/Sessions/ExercisePerformance.swift`.

### `Data/Models/Plans/SetPrescription.swift`
- Per-set plan target.
- Owns set type, target weight, target reps, target rest, target RPE, the active set-performance link while a session is live, and attached suggestion events.
- Read with: `Data/Models/Sessions/SetPerformance.swift`.

### `Data/Models/Suggestions/SuggestionEvent.swift`
- Grouped persisted suggestion record.
- Owns the triggering performance, live target exercise/set, decision state, outcome state, required evaluation count, confidence tier, reasoning text, and child `PrescriptionChange` rows.
- Read with: `Data/Models/Suggestions/PrescriptionChange.swift`, `Data/Models/Suggestions/SuggestionEvaluation.swift`, `Data/Models/Suggestions/SuggestionSnapshots.swift`.

### `Data/Models/Suggestions/PrescriptionChange.swift`
- Scalar before/after mutation inside one suggestion event.
- Read with: `Views/Suggestions/SuggestionReviewView.swift`, `Data/Services/Suggestions/Outcomes/OutcomeRuleEngine.swift`.

### `Data/Models/Suggestions/SuggestionEvaluation.swift`
- One persisted outcome-evaluation pass for one later workout.
- Read with: `Data/Services/Suggestions/Outcomes/OutcomeResolver.swift`.

### `Data/Models/Suggestions/SuggestionSnapshots.swift`
- Frozen target and performance snapshots used by generation, outcome evaluation, and AI helpers.
- Historical matching is UUID-based through copied target-set IDs, not live set indices.
- Read with: `ExercisePerformance.swift`, `SetPerformance.swift`, suggestion services.

### `Data/Models/Exercise/Exercise.swift`
- Canonical exercise catalog row.
- Owns search metadata, alternate names, favorites, picker recency, and custom-vs-catalog identity.
- Read with: `Data/Models/Exercise/ExerciseCatalog.swift`, `Helpers/ExerciseSearch.swift`.

### `Data/Models/Exercise/ExerciseHistory.swift`
- Derived analytics cache per `catalogID`.
- Stores workout-based recency, totals, PR-style aggregates, and progression points used by exercise analytics UI and Spotlight eligibility.
- Read with: `Data/Services/ExerciseHistoryUpdater.swift`, `Views/Exercise/ExerciseDetailView.swift`.

### `Data/Models/Exercise/ProgressionPoint.swift`
- Chart point model for exercise analytics.
- Read with: `ExerciseHistory.swift`, `Views/Exercise/ExerciseDetailView.swift`.

### `Data/Models/WorkoutSplit/WorkoutSplit.swift`
- Split schedule aggregate.
- Owns weekly-offset and rotation state, active split behavior, today's split resolution, and today's plan resolution.
- Read with: `Data/Models/WorkoutSplit/WorkoutSplitDay.swift`, `Views/WorkoutSplit/WorkoutSplitView.swift`.

### `Data/Models/WorkoutSplit/WorkoutSplitDay.swift`
- One day inside a split.
- Stores name, order, rest-day state, target muscles, and optional assigned plan.
- Read with: `Views/WorkoutSplit/WorkoutSplitDayView.swift`, `Views/HomeSections/WorkoutSplitSectionView.swift`.

### `Data/Models/AppSettings.swift`
- Singleton app settings.
- Holds weight unit, height unit, timer behavior, notification settings, live activity settings, and related display/runtime preferences.
- Read with: `Helpers/WeightFormatting.swift`, `Data/Services/RestTimerState.swift`, `Data/LiveActivity/WorkoutActivityManager.swift`.

### `Data/Models/UserProfile.swift`
- Singleton user profile used by onboarding and readiness checks.
- Read with: `Views/Onboarding/OnboardingView.swift`, `Data/Services/SystemState.swift`.

### `Data/Models/RestTimeHistory.swift`
- Recent rest-duration history used by the timer UI and timer intents.
- Read with: `Views/Workout/RestTimerView.swift`, `Intents/RestTimer/*`.

## Major Feature Surfaces

### Workout Runtime
- `Views/Workout/WorkoutSessionContainer.swift`
  - Routes `.pending`, `.active`, `.summary`, and `.done` states to the right surface.
- `Views/Workout/WorkoutView.swift`
  - Main logging surface, finish/cancel entry point, and sheet host for add exercise, timer, pre-workout context, and settings.
- `Views/Workout/ExerciseView.swift`
  - Per-exercise logging surface.
- `Views/Components/ExerciseSetRowView.swift`
  - Set-level editing, completion, quick actions, timer kickoff, and live-activity updates.
- `Views/Workout/WorkoutSummaryView.swift`
  - Post-workout orchestration point for summary UI, PR detection, outcome resolution, new suggestion generation, suggestion review, save-as-plan, and history rebuild.
- Read with: `Documentation/SESSION_LIFECYCLE_FLOW.md`.

### Workout Plans
- `Views/WorkoutPlan/WorkoutPlanView.swift`
  - Full-screen create/edit plan flow.
- `Views/WorkoutPlan/WorkoutPlanDetailView.swift`
  - Read-only plan detail, favorite/start/edit/delete actions, and entry into the suggestions sheet.
- `Views/Suggestions/WorkoutPlanSuggestionsSheet.swift`
  - Plan-level view of suggestions that still need review or are still awaiting outcome.
- `Views/WorkoutPlan/WorkoutPlansListView.swift`
  - All-plans list with deletion and favorite toggles.
- `Views/WorkoutPlan/WorkoutPlanPickerView.swift`
  - Picker used by split day assignment.
- Read with: `Documentation/PLAN_EDITING_FLOW.md`.

### Suggestions
- `Views/Suggestions/DeferredSuggestionsView.swift`
  - Pre-workout gate when the source plan still has pending or deferred events.
- `Views/Suggestions/SuggestionReviewView.swift`
  - Shared review UI and mutation helpers for accept/reject/defer.
- `Data/Services/Suggestions/Generation/SuggestionGenerator.swift`
  - Top-level generation entrypoint after a plan-backed workout reaches summary.
- `Data/Services/Suggestions/Generation/RuleEngine.swift`
  - Deterministic generation logic.
- `Data/Services/Suggestions/Generation/SuggestionDeduplicator.swift`
  - Conflict resolution across generated drafts.
- `Data/Services/Suggestions/Outcomes/OutcomeResolver.swift`
  - Multi-session outcome evaluation and finalization.
- `Data/Services/Suggestions/Outcomes/OutcomeRuleEngine.swift`
  - Deterministic outcome logic.
- Read with: `Documentation/SUGGESTION_AND_OUTCOME_FLOW.md`.

### Exercise Analytics
- `Views/HomeSections/RecentExercisesSectionView.swift`
  - Home card driven by completed-workout recency, not picker recency.
- `Views/Exercise/ExercisesListView.swift`
  - Searchable exercise browser ordered by `ExerciseHistory`.
- `Views/Exercise/ExerciseDetailView.swift`
  - Cached analytics and charts for one exercise.
- `Views/Exercise/ExerciseHistoryView.swift`
  - Raw completed-performance drill-down.
- `Data/Services/ExerciseHistoryUpdater.swift`
  - Rebuilds or deletes `ExerciseHistory` rows after workout completion or when completed workouts are hidden.
- Read with: `Documentation/EXERCISE_HISTORY_FLOW.md`.

### Splits
- `Views/HomeSections/WorkoutSplitSectionView.swift`
  - Home card for today's split status and plan entry.
- `Views/WorkoutSplit/WorkoutSplitView.swift`
  - Main split management surface.
- `Views/WorkoutSplit/WorkoutSplitDayView.swift`
  - Per-day editing and plan assignment.
- `Views/WorkoutSplit/SplitBuilderView.swift`
  - New split creation flow.
- `Views/WorkoutSplit/WorkoutSplitListView.swift`
  - Active/inactive split management.

## Integrations

### Spotlight and App Entities
- `Data/Services/SpotlightIndexer.swift`
  - Indexes workouts, plans, exercises, and splits.
  - Exercise indexing is history-backed, not catalog-backed.
- `Intents/Workout/WorkoutSessionEntity.swift`
- `Intents/WorkoutPlan/WorkoutPlanEntity.swift`
- `Intents/WorkoutSplit/WorkoutSplitEntity.swift`
- `Intents/Exercise/ExerciseEntity.swift`
- Read with: `AppRouter.handleSpotlight(_:)`.

### App Intents and Shortcuts
- `Intents/VillainArcShortcuts.swift`
  - Declares the main shortcut surface.
- `Intents/IntentDonations.swift`
  - Central donation helpers used by UI flows.
- `Intents/Workout/*`, `Intents/WorkoutPlan/*`, `Intents/WorkoutSplit/*`, `Intents/Exercise/*`, `Intents/RestTimer/*`
  - Reuse app logic through `SetupGuard`, `AppRouter`, and shared models/services.

### Timer and Live Activity
- `Data/Services/RestTimerState.swift`
  - App-wide timer state machine with app-group persistence and notification hookup.
- `Helpers/RestTimerNotifications.swift`
  - Local notification scheduling for the rest timer.
- `Data/LiveActivity/WorkoutActivityManager.swift`
  - Workout live activity lifecycle and synchronization.
- `VillainArcWidgetExtension/*`
  - Widget and live activity UI surfaces.

### AI Helpers
- `Data/Services/AI/Suggestions/AITrainingStyleClassifier.swift`
  - Fallback classifier when deterministic style detection is ambiguous.
- `Data/Services/AI/Outcomes/AIOutcomeInferrer.swift`
  - Fallback evaluator for lower-confidence outcome cases.
- `Data/Services/AI/Shared/FoundationModelPrewarmer.swift`
  - Prewarms on-device model usage near likely suggestion/outcome entry points.

## Read By Task

- Startup, onboarding, or resume bugs:
  - `VillainArcApp.swift`, `RootView.swift`, `OnboardingManager.swift`, `AppRouter.swift`, `SetupGuard.swift`
- Workout logging, finish, or summary bugs:
  - `WorkoutSession.swift`, `WorkoutView.swift`, `WorkoutSummaryView.swift`, `WorkoutSessionContainer.swift`
- Plan creation, editing, or deletion bugs:
  - `WorkoutPlan.swift`, `WorkoutPlan+Editing.swift`, `WorkoutPlanView.swift`, `WorkoutPlanDetailView.swift`
- Suggestion generation, review, or outcome bugs:
  - `SuggestionEvent.swift`, `SuggestionGenerator.swift`, `OutcomeResolver.swift`, `SuggestionReviewView.swift`
- Exercise ordering, charts, or history bugs:
  - `ExerciseHistory.swift`, `ExerciseHistoryUpdater.swift`, `ExercisesListView.swift`, `ExerciseDetailView.swift`
- Split-day or today's-plan bugs:
  - `WorkoutSplit.swift`, `WorkoutSplitView.swift`, `WorkoutSplitSectionView.swift`
- Spotlight or shortcut issues:
  - `SpotlightIndexer.swift`, entity files, intent files, `IntentDonations.swift`

## Tests

### `VillainArcTests/WorkoutFinishTests.swift`
- Finish-time pruning and incomplete-set resolution.

### `VillainArcTests/VillainArcTests.swift`
- Plan editing semantics and unresolved-suggestion cleanup.

### `VillainArcTests/SuggestionSystemTests.swift`
- Suggestion generation, training-style handling, and related persistence behavior.

### `VillainArcTests/MultiSessionEvaluationTests.swift`
- Multi-session outcome accumulation and finalization.

### `VillainArcTests/OutcomeRuleEngineTests.swift`
- Deterministic outcome logic by change type.

### `VillainArcTests/OutcomeResolverGroupingTests.swift`
- Group-level outcome aggregation behavior.

### `VillainArcTests/UUIDTargetTrackingTests.swift`
- UUID-based historical set matching through plan edits and reindexing.

### `VillainArcTests/ExerciseHistoryMetricsTests.swift`
- Derived exercise history totals, PR metrics, and progression points.

### `VillainArcTests/ExerciseReplacementTests.swift`
- Exercise replacement mechanics and cleanup of stale prescription links.

### `VillainArcTests/DataManagerCatalogSyncTests.swift`
- Catalog sync and metadata propagation into stored plan/session copies.

### `VillainArcTests/WeightConversionTests.swift`
- Canonical-kg storage and user-unit conversion paths.

### `VillainArcTests/SpotlightSummaryTests.swift`
- Spotlight summary text and indexing assumptions.

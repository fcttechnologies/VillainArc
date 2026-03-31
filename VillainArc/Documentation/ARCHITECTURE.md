# VillainArc Architecture

This file is the structure map for the app. It answers “where does this responsibility live?” and “which files should I open first?” For product context, read `Documentation/PROJECT_GUIDE.md` first.

## Read Order

1. app shell and startup
2. persistence and singleton state
3. domain models
4. runtime services
5. integrations and feature surfaces

## App Shell and Startup

### `Root/VillainArcApp.swift`

- app entry point
- installs `SharedModelContainer.container`
- forwards Spotlight and Siri handoffs into `AppRouter.shared`
- app delegate reinstalls Health observers on process launch and installs the notification delegate

### `Root/RootView.swift`

- launch coordinator for the foreground app
- starts `OnboardingManager`
- cleans up abandoned plan-editing copies
- refreshes shortcut parameters
- only resumes unfinished flows after onboarding reaches `.ready`
- after `.ready`, asks `AppRouter` to resume unfinished work, refreshes Health observer/background registration, runs Health sync/export reconciliation, and requests notification permission if needed

### `Views/AppShell/ContentView.swift`

- top-level foreground shell after launch is ready
- owns the root `TabView`
- presents full-screen workout, plan, and weight-goal-completion flows
- installs the toast overlay host

### `Data/Services/App/AppRouter.swift`

- shared navigation and active-flow coordinator
- owns home/health tab paths
- owns the currently presented workout session and workout plan
- owns the active weight-goal completion route
- blocks new flows when any other workout/plan flow is already active

## Persistence and Shared State

### `Data/SharedModelContainer.swift`

- shared SwiftData schema and `ModelContainer`
- app-group backed store
- private CloudKit sync
- used by the main app, intents, widgets, and live activities

### Singleton Models

- `Data/Models/AppSettings.swift`
- `Data/Models/UserProfile.swift`
- `Data/Models/Health/HealthSyncState.swift`

These are created by startup/system-state code and treated as singleton-style records.

### `Data/Services/App/SystemState.swift`

- ensures singleton-style records exist

### `Data/Services/App/OnboardingManager.swift`

- first-run and returning-launch readiness state machine
- owns CloudKit bootstrap waiting, singleton setup, profile onboarding routing, and Health permission timing

### `Data/Services/App/CloudKitImportMonitor.swift`

- watches persistent CloudKit import events during first bootstrap
- lets onboarding wait for import completion before exercise catalog seeding

### `Data/Services/App/DataManager.swift`

- exercise catalog seeding/sync
- bundled catalog versioning
- propagation of updated built-in exercise metadata into stored plan/workout snapshots

### `Data/Services/App/SetupGuard.swift`

- readiness guard for App Intents

## Core Domain Models

### Workout and Session Models

- `Data/Models/Sessions/WorkoutSession.swift`
  - root workout aggregate
- `Data/Models/Sessions/ExercisePerformance.swift`
  - performed exercise inside a session
- `Data/Models/Sessions/SetPerformance.swift`
  - performed set inside an exercise
- `Data/Models/Sessions/PreWorkoutContext.swift`
  - optional session-scoped pre-workout context

### Plan Models

- `Data/Models/Plans/WorkoutPlan.swift`
  - root plan aggregate
- `Data/Models/Plans/WorkoutPlan+Editing.swift`
  - editing-copy creation, merge, and delete helpers
- `Data/Models/Plans/ExercisePrescription.swift`
  - plan exercise row
- `Data/Models/Plans/SetPrescription.swift`
  - plan set row

### Suggestion Models

- `Data/Models/Suggestions/SuggestionEvent.swift`
  - persisted suggestion unit
- `Data/Models/Suggestions/PrescriptionChange.swift`
  - scalar mutation inside a suggestion
- `Data/Models/Suggestions/SuggestionEvaluation.swift`
  - one later-workout evaluation pass

### Exercise and Split Models

- `Data/Models/Exercise/Exercise.swift`
  - exercise catalog row
- `Data/Models/Exercise/ExerciseHistory.swift`
  - cached per-exercise analytics
- `Data/Models/Exercise/ProgressionPoint.swift`
  - cached chart point
- `Data/Models/WorkoutSplit/WorkoutSplit.swift`
  - split aggregate
- `Data/Models/WorkoutSplit/WorkoutSplitDay.swift`
  - one split day

### Health Models

- `Data/Models/Health/HealthWorkout.swift`
  - Apple Health workout mirror/cache
- `Data/Models/Health/WeightEntry.swift`
  - local weight history record with optional Apple Health linkage
- `Data/Models/Health/HealthSleepNight.swift`
  - one-row-per-wake-day Apple Health sleep summary cache
- `Data/Models/Health/HealthStepsDistance.swift`
  - per-day steps and distance cache
- `Data/Models/Health/HealthEnergy.swift`
  - per-day energy cache
- `Data/Models/Health/WeightGoal.swift`
  - date-ranged weight-goal history with one active goal at a time through app logic
- `Data/Models/Health/StepsGoal.swift`
  - date-ranged steps-goal history with one active goal at a time through app logic
- `Data/Models/Health/HealthKitCatalog.swift`
  - shared HealthKit types and units

## Runtime Services

### Workout Runtime

- `Views/Workout/WorkoutSessionContainer.swift`
  - routes session UI by status
- `Views/Workout/WorkoutView.swift`
  - active logging screen
- `Views/Workout/WorkoutSummaryView.swift`
  - summary/finalization orchestrator
- `Data/Services/Workout/RestTimerState.swift`
  - shared rest timer state persisted in app-group defaults
- `Data/LiveActivity/WorkoutActivityManager.swift`
  - Live Activity projection of the active workout
- `Data/Services/HealthKit/Live/HealthLiveWorkoutSessionCoordinator.swift`
  - live Apple Health workout session management during logging

### Suggestions and Outcomes

- `Data/Services/Suggestions/Generation/SuggestionGenerator.swift`
- `Data/Services/Suggestions/Generation/RuleEngine.swift`
- `Data/Services/Suggestions/Generation/SuggestionDeduplicator.swift`
- `Data/Services/Suggestions/Outcomes/OutcomeResolver.swift`
- `Data/Services/Suggestions/Outcomes/OutcomeRuleEngine.swift`
- `Views/Suggestions/DeferredSuggestionsView.swift`
- `Views/Suggestions/SuggestionReviewView.swift`
- `Views/Suggestions/WorkoutPlanSuggestionsSheet.swift`

### Exercise Analytics

- `Data/Services/Workout/ExerciseHistoryUpdater.swift`
  - rebuilds `ExerciseHistory`
- `Data/Services/Workout/WorkoutDeletionCoordinator.swift`
  - deletion path that also repairs history and suggestion-learning data

### Notifications and Toasts

- `Data/Services/App/NotificationCoordinator.swift`
  - local notification authorization, scheduling, and foreground delegate handling
- `Views/Components/Overlays/ToastManager.swift`
  - in-app toast presentation

## Integrations

### Apple Health

- `Data/Services/HealthKit/Authorization/HealthAuthorizationManager.swift`
  - permission state and HealthKit metadata helpers
- `Data/Services/HealthKit/Sync/HealthStoreUpdateCoordinator.swift`
  - observer installation, observer recovery, background delivery registration, and top-level manual sync entrypoint
- `Data/Services/HealthKit/Sync/HealthSyncCoordinator.swift`
  - workout and weight sync orchestration plus full-sync sequencing for Health caches
- `Data/Services/HealthKit/Sync/HealthDailyMetricsSync.swift`
  - daily steps/distance/energy sync orchestration
- `Data/Services/HealthKit/Sync/HealthSleepSync.swift`
  - nightly sleep-summary sync orchestration
- `Data/Services/HealthKit/Sync/StepsGoalEvaluator.swift`
  - steps-goal completion logic tied to daily step updates
- `Data/Services/HealthKit/Export/HealthExportCoordinator.swift`
  - workout and weight export/reconciliation
- `Data/Services/HealthKit/HealthMirrorSupport.swift`
  - Health metadata keys, HealthKit lookup helpers, and workout mirror import helpers
- `Data/Services/HealthKit/Detail/HealthWorkoutDetailLoader.swift`
  - on-demand richer workout detail loading

### Spotlight and App Intents

- `Data/Services/App/SpotlightIndexer.swift`
- `Intents/**/*`

### Widgets and Live Activities

- `VillainArcWidgetExtension/**/*`
- `Data/LiveActivity/WorkoutActivityAttributes.swift`
- `Data/LiveActivity/WorkoutActivityManager.swift`

### AI Helpers

- `Data/Services/AI/Suggestions/AITrainingStyleClassifier.swift`
- `Data/Services/AI/Outcomes/AIOutcomeInferrer.swift`
- `Data/Services/AI/Shared/FoundationModelPrewarmer.swift`

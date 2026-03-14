# VillainArc Project Structure

This file is a structure map for the codebase. It explains what the important files and folders are for, what tends to call into them, what they call out to, and which files should usually be read together.

## App Shell

### `Root/VillainArcApp.swift`
- Purpose: app entry point, model container injection, Siri/Spotlight activity forwarding.
- Called by: iOS runtime.
- Calls: `RootView`, `SharedModelContainer`, `AppRouter`, `VillainArcShortcuts`.
- Read with: `Root/RootView.swift`, `Views/ContentView.swift`, `Data/Services/AppRouter.swift`.

### `Root/RootView.swift`
- Purpose: startup wrapper that owns `OnboardingManager`, performs launch cleanup/shortcut refresh, and runs bootstrap once per app launch.
- Called by: `VillainArcApp`.
- Calls: `OnboardingManager`, `OnboardingView`, `AppRouter.checkForUnfinishedData()`, `VillainArcShortcuts`, `ContentView`.
- Read with: `Views/ContentView.swift`, `Data/Services/OnboardingManager.swift`.

### `Views/ContentView.swift`
- Purpose: foreground shell, home screen composition, stack destinations, and full-screen presentation of active workout and active plan-edit flows.
- Called by: `RootView`.
- Calls: `AppRouter`, home section views, top-level destination views.
- Read with: `Root/RootView.swift`, `Data/Services/AppRouter.swift`, `Data/Services/OnboardingManager.swift`.

### `Data/Services/AppRouter.swift`
- Purpose: global navigation and active-flow coordinator.
- Called by: `VillainArcApp`, `ContentView`, feature views, App Intents, Spotlight routes.
- Calls: SwiftData main context, `saveContext`, `RestTimerState`, `WorkoutActivityManager`, `SpotlightIndexer`.
- Read with: `Views/ContentView.swift`, workout/plan intent files.

### `Data/SharedModelContainer.swift`
- Purpose: shared SwiftData schema, container, and app-group persistence setup.
- Called by: app shell, intents, services, widgets, live activity manager.
- Calls: SwiftData `Schema`, `ModelContainer`, app-group storage helpers.
- Read with: any new model file, migration-sensitive changes.

## Home and Entry Surfaces

### `Views/HomeSections/RecentWorkoutSectionView.swift`
- Purpose: home entry surface for recent workout and workout-history navigation.
- Called by: `ContentView`.
- Calls: `WorkoutRowView`, `AppRouter.navigate(.workoutSessionsList)`, `IntentDonations`.
- Read with: `Views/History/WorkoutsListView.swift`, `Views/Workout/WorkoutDetailView.swift`.

### `Views/HomeSections/RecentWorkoutPlanSectionView.swift`
- Purpose: home entry surface for recent workout plan and plans-list navigation.
- Called by: `ContentView`.
- Calls: `WorkoutPlanRowView`, `AppRouter.navigate(.workoutPlansList)`, `IntentDonations`.
- Read with: `Views/WorkoutPlan/WorkoutPlansListView.swift`.

### `Views/HomeSections/RecentExercisesSectionView.swift`
- Purpose: home entry surface for recently completed exercises using cached history ordering.
- Called by: `ContentView`.
- Calls: `ExerciseHistoryOrdering`, `ExerciseSummaryRow`, `AppRouter.navigate(.exercisesList)`, `IntentDonations`.
- Read with: `Views/Exercise/ExercisesListView.swift`, `Data/Models/Exercise/ExerciseHistory.swift`.

### `Views/HomeSections/WorkoutSplitSectionView.swift`
- Purpose: home entry surface for active split status and today's plan routing.
- Called by: `ContentView`.
- Calls: `WorkoutSplit.refreshRotationIfNeeded`, `AppRouter`, `IntentDonations`, `SmallUnavailableView`.
- Read with: `Views/WorkoutSplit/WorkoutSplitView.swift`, `Data/Models/WorkoutSplit/WorkoutSplit.swift`.

### `Views/Onboarding/OnboardingView.swift`
- Purpose: onboarding and bootstrap UI, including retry/error states and profile setup path.
- Called by: `ContentView`.
- Calls: `OnboardingManager`, profile-step subviews, retry actions.
- Read with: `Data/Services/OnboardingManager.swift`, `Data/Models/UserProfile.swift`.

## Startup and Shared Services

### `Data/Services/DataManager.swift`
- Purpose: exercise catalog seeding, dedupe, snapshot metadata sync, shared `saveContext()` / `scheduleSave()`.
- Called by: `ContentView`, add-exercise flows, model/service code across the app.
- Calls: `ExerciseCatalog`, SwiftData fetch/insert/delete/save.
- Read with: `Data/Models/Exercise/Exercise.swift`, `Data/Models/Exercise/ExerciseCatalog.swift`.

### `Data/Services/OnboardingManager.swift`
- Purpose: first-run setup orchestration.
- Called by: `ContentView`.
- Calls: `NetworkMonitor`, `CloudKitStatusChecker`, `DataManager`, `SpotlightIndexer`, `SystemState`.
- Read with: `Views/Onboarding/OnboardingView.swift`, `Data/Services/SystemState.swift`.

### `Data/Services/SystemState.swift`
- Purpose: lazy creation of singleton-style app records like `UserProfile` and `AppSettings`.
- Called by: onboarding and settings-related code.
- Calls: `UserProfile.single`, `AppSettings.single`, SwiftData saves.
- Read with: `Data/Models/UserProfile.swift`, `Data/Models/AppSettings.swift`.

### `Data/Models/AppSettings.swift`
- Purpose: singleton app settings for timer behavior, notifications, live activities, workout logging preferences, and display units (weight and height).
- Called by: settings UI, timer/live-activity services, bootstrap helpers, any view displaying weight or height.
- Calls: singleton fetch helpers.
- Read with: `Data/Services/SystemState.swift`, `Views/Workout/WorkoutSettingsView.swift`, `Data/Models/Enums/WeightUnit.swift`, `Data/Models/Enums/HeightUnit.swift`.

### `Data/Models/UserProfile.swift`
- Purpose: user profile model used during onboarding and setup validation.
- Called by: onboarding UI, `OnboardingManager`, `SetupGuard`, `SystemState`.
- Calls: completion/step helpers.
- Read with: `Views/Onboarding/OnboardingView.swift`.

### `Data/Models/RestTimeHistory.swift`
- Purpose: recent rest-duration history used for timer quick picks and shortcuts.
- Called by: rest timer UI and timer-related intents.
- Calls: record/fetch helpers.
- Read with: `Views/Workout/RestTimerView.swift`, `Intents/RestTimer/*`.

### `Data/Services/SetupGuard.swift`
- Purpose: shared App Intent guardrail for bootstrap readiness and active-flow checks.
- Called by: foreground/navigation intents.
- Calls: `DataManager`, `AppSettings`, `UserProfile`, `WorkoutSession.incomplete`, `WorkoutPlan.incomplete`.
- Read with: intent entrypoint files under `Intents/`.

## Workout Runtime

### `Data/Models/Sessions/WorkoutSession.swift`
- Purpose: root workout aggregate, lifecycle state, finish/prune logic, plan-linked workout creation.
- Called by: `AppRouter`, workout views, workout intents, tests.
- Calls: `ExercisePerformance`, finish helpers, fetch descriptors.
- Read with: `Views/Workout/WorkoutSessionContainer.swift`, `Views/Workout/WorkoutSummaryView.swift`.

### `Data/Models/Sessions/ExercisePerformance.swift`
- Purpose: per-exercise workout log, copied exercise metadata, frozen suggestion context, best-set helpers.
- Called by: `WorkoutSession`, workout views, suggestion system, history updater.
- Calls: `SetPerformance`, descriptor helpers, rest/metric helpers.
- Read with: `Data/Models/Sessions/SetPerformance.swift`, `Data/Models/Suggestions/SuggestionSnapshots.swift`.

### `Data/Models/Sessions/SetPerformance.swift`
- Purpose: per-set performed data including completion state, actual values, optional frozen target-set index.
- Called by: `ExercisePerformance`, set row UI, suggestion and outcome logic.
- Calls: computed helpers for rest, volume, and estimated 1RM.
- Read with: `Views/Components/ExerciseSetRowView.swift`, `Data/Models/Plans/SetPrescription.swift`.

### `Data/Models/Sessions/PreWorkoutContext.swift`
- Purpose: pre-workout mood, pre-workout toggle, and notes.
- Called by: `WorkoutSession`, pre-workout sheet UI.
- Calls: none.
- Read with: `Views/Workout/PreWorkoutContextView.swift`.

### `Views/Workout/WorkoutSessionContainer.swift`
- Purpose: routes an active session to deferred-suggestions review, workout logging, or summary.
- Called by: `ContentView`.
- Calls: `DeferredSuggestionsView`, `WorkoutView`, `WorkoutSummaryView`.
- Read with: `Data/Models/Sessions/WorkoutSession.swift`.

### `Views/Workout/WorkoutView.swift`
- Purpose: main active-workout screen, sheet/menu routing, add exercise, finish/cancel actions.
- Called by: `WorkoutSessionContainer`.
- Calls: `ExerciseView`, `RestTimerView`, `PreWorkoutContextView`, `WorkoutSettingsView`, `WorkoutSession.finish`, `WorkoutActivityManager`, `IntentDonations`.
- Read with: `Views/Workout/ExerciseView.swift`, `Views/Workout/WorkoutSummaryView.swift`.

### `Views/Workout/ExerciseView.swift`
- Purpose: per-exercise workout logging surface.
- Called by: `WorkoutView`.
- Calls: `ExerciseSetRowView`, rep-range/rest editors, replace flow, exercise history sheet.
- Read with: `Views/Components/ExerciseSetRowView.swift`, `Views/Workout/ReplaceExerciseView.swift`.

### `Views/Components/ExerciseSetRowView.swift`
- Purpose: editable set row for reps, weight, completion, set type, timer trigger, and quick actions.
- Called by: `ExerciseView`.
- Calls: `RestTimerState`, `WorkoutActivityManager`, `IntentDonations`, save helpers.
- Read with: `Data/Models/Sessions/SetPerformance.swift`, `Views/Workout/RestTimerView.swift`.

### `Views/Workout/WorkoutSummaryView.swift`
- Purpose: post-workout orchestration point for summary UI, suggestion generation, outcome resolution, history rebuild, and save-as-plan actions.
- Called by: `WorkoutSessionContainer`.
- Calls: `OutcomeResolver`, `SuggestionGenerator`, `ExerciseHistoryUpdater`, `SuggestionReviewView`, `WorkoutPlan` creation paths.
- Read with: `Data/Services/Suggestions/*`, `Data/Services/ExerciseHistoryUpdater.swift`.

### `Views/Workout/WorkoutDetailView.swift`
- Purpose: read-only completed-workout detail screen with delete and save-as-plan actions.
- Called by: navigation and workout row taps.
- Calls: `WorkoutPlan(from:)`, `ExerciseHistoryUpdater`, `SpotlightIndexer`, `AppRouter`, `IntentDonations`.
- Read with: `Views/History/WorkoutsListView.swift`, `Data/Models/Sessions/WorkoutSession.swift`.

### `Views/Workout/RestTimerView.swift`
- Purpose: rest timer control screen and next-set completion shortcut.
- Called by: `WorkoutView`.
- Calls: `RestTimerState`, `RestTimeHistory`, `WorkoutActivityManager`, timer intents/donations.
- Read with: `Data/Services/RestTimerState.swift`, `Helpers/RestTimerNotifications.swift`.

### `Views/Workout/WorkoutSettingsView.swift`
- Purpose: workout-scoped settings UI for timer, notifications, and live activity behavior.
- Called by: `WorkoutView`.
- Calls: `AppSettings.single`, `SystemState`, `WorkoutActivityManager`, `RestTimerNotifications`.
- Read with: `Data/Models/AppSettings.swift`, `Data/LiveActivity/WorkoutActivityManager.swift`.

### `Views/History/WorkoutsListView.swift`
- Purpose: completed-workout history list with single-delete and bulk-delete flows.
- Called by: `ContentView`, recent-workout home section navigation.
- Calls: `WorkoutRowView`, `SpotlightIndexer`, `ExerciseHistoryUpdater`, `IntentDonations`.
- Read with: `Views/Workout/WorkoutDetailView.swift`.

## Workout Plans

### `Data/Models/Plans/WorkoutPlan.swift`
- Purpose: root plan aggregate, exercise ownership, split assignment surface, create-from-session path.
- Called by: plan views, plan intents, split assignment, router.
- Calls: `ExercisePrescription`, ordering helpers, fetch descriptors.
- Read with: `Data/Models/Plans/WorkoutPlan+Editing.swift`, `Views/WorkoutPlan/WorkoutPlanView.swift`.

### `Data/Models/Plans/WorkoutPlan+Editing.swift`
- Purpose: copy-merge editing workflow and stale-suggestion cleanup.
- Called by: plan detail/edit flows.
- Calls: sync helpers, unresolved suggestion cleanup, delete/finish/cancel editing logic.
- Read with: `WorkoutPlan.swift`, `Views/WorkoutPlan/WorkoutPlanView.swift`, `Documentation/PLAN_EDITING_FLOW.md`.

### `Data/Models/Plans/ExercisePrescription.swift`
- Purpose: per-exercise plan prescription, copied exercise metadata, active workout-performance link.
- Called by: `WorkoutPlan`, plan editor, workout-from-plan creation, suggestion system.
- Calls: `SetPrescription`, policy copy helpers.
- Read with: `Data/Models/Plans/SetPrescription.swift`, `Data/Models/Sessions/ExercisePerformance.swift`.

### `Data/Models/Plans/SetPrescription.swift`
- Purpose: per-set target reps/weight/rest/type/RPE.
- Called by: `ExercisePrescription`, plan editor, suggestion system, session-to-plan conversion.
- Calls: constructors from `SetPerformance`, copy helpers.
- Read with: `Data/Models/Sessions/SetPerformance.swift`.

### `Views/WorkoutPlan/WorkoutPlanView.swift`
- Purpose: full-screen create/edit plan workflow.
- Called by: `ContentView`, plan detail, plan picker, workout detail/save-as-plan flows.
- Calls: `AddExerciseView`, text editors, rep/rest editors, `WorkoutPlan.finishEditing`, `SpotlightIndexer`.
- Read with: `Data/Models/Plans/WorkoutPlan+Editing.swift`, `Views/WorkoutPlan/WorkoutPlanDetailView.swift`.

### `Views/WorkoutPlan/WorkoutPlanDetailView.swift`
- Purpose: read-only plan detail screen and launch point for start/edit/delete/favorite actions.
- Called by: navigation, plan picker callbacks.
- Calls: `AppRouter.editWorkoutPlan`, `AppRouter.startWorkoutSession(from:)`, `IntentDonations`, `SpotlightIndexer`.
- Read with: `WorkoutPlanView.swift`, `Intents/WorkoutPlan/StartWorkoutWithPlanIntent.swift`.

### `Views/WorkoutPlan/WorkoutPlansListView.swift`
- Purpose: all-plans list with filtering, favorite toggles, and deletion.
- Called by: `ContentView`.
- Calls: `WorkoutPlanRowView`, `SpotlightIndexer`, donation helpers, save helpers.
- Read with: `Views/Components/WorkoutPlanRowView.swift`.

### `Views/WorkoutPlan/WorkoutPlanPickerView.swift`
- Purpose: choose, clear, or create a plan for split-day assignment.
- Called by: split editing flows.
- Calls: `WorkoutPlanDetailView`, `WorkoutPlanView`, save helpers.
- Read with: `Views/WorkoutSplit/WorkoutSplitDayView.swift`.

## Suggestions

### `Data/Models/Suggestions/SuggestionEvent.swift`
- Purpose: grouped persisted suggestion record with shared decision/outcome state and snapshots.
- Called by: suggestion generation, review UI, outcome evaluation.
- Calls: child-change ordering helpers.
- Read with: `Data/Models/Plans/PrescriptionChange.swift`, `Data/Models/Suggestions/SuggestionSnapshots.swift`.

### `Data/Models/Plans/PrescriptionChange.swift`
- Purpose: scalar change inside a suggestion event, including live target references and durable target-set indexing.
- Called by: suggestion generation, review UI, outcome logic, plan editing cleanup.
- Calls: none.
- Read with: `SuggestionEvent.swift`, `SuggestionGrouping.swift`.

### `Data/Models/Suggestions/SuggestionSnapshots.swift`
- Purpose: frozen target/performance context used by suggestion history and AI inputs.
- Called by: performance models, suggestion generation, outcome evaluation, AI DTO builders.
- Calls: snapshot mappers from plans and performances.
- Read with: `ExercisePerformance.swift`, `SetPerformance.swift`, `AIModels/*`.

### `Data/Services/Suggestions/Generation/SuggestionGenerator.swift`
- Purpose: top-level post-workout suggestion generation entrypoint.
- Called by: `WorkoutSummaryView`.
- Calls: `MetricsCalculator`, `AITrainingStyleClassifier`, `RuleEngine`, `SuggestionDeduplicator`, SwiftData persistence.
- Read with: `RuleEngine.swift`, `SuggestionDeduplicator.swift`, `Documentation/SUGGESTION_AND_OUTCOME_FLOW.md`.

### `Data/Services/Suggestions/Generation/RuleEngine.swift`
- Purpose: deterministic suggestion generation rules.
- Called by: `SuggestionGenerator`.
- Calls: `MetricsCalculator`, model helpers, draft builders.
- Read with: `SuggestionEventDraft.swift`, `MetricsCalculator.swift`.

### `Data/Services/Suggestions/Generation/SuggestionDeduplicator.swift`
- Purpose: resolves conflicts between generated suggestion drafts.
- Called by: `SuggestionGenerator`.
- Calls: internal scope/priority helpers.
- Read with: `SuggestionEventDraft.swift`.

### `Data/Services/Suggestions/Outcomes/OutcomeResolver.swift`
- Purpose: top-level evaluation of older suggestions against the next completed workout.
- Called by: `WorkoutSummaryView`.
- Calls: `OutcomeRuleEngine`, `AIOutcomeInferrer`, suggestion mutation helpers.
- Read with: `OutcomeRuleEngine.swift`, `SuggestionEvent.swift`.

### `Data/Services/Suggestions/Outcomes/OutcomeRuleEngine.swift`
- Purpose: deterministic outcome scoring logic.
- Called by: `OutcomeResolver`.
- Calls: `MetricsCalculator`, change-type-specific evaluators.
- Read with: `PrescriptionChange.swift`, `SetPerformance.swift`.

### `Data/Services/AI/Suggestions/AITrainingStyleClassifier.swift` and `Data/Services/AI/Suggestions/AITrainingStyleTools.swift`
- Purpose: on-device fallback classifier and history tool used when deterministic training-style detection is ambiguous.
- Called by: `SuggestionGenerator`.
- Calls: Foundation Models session APIs, recent-performance fetches, AI DTOs.
- Read with: `MetricsCalculator.swift`, `Data/Models/AIModels/Suggestions/*`.

### `Data/Services/AI/Outcomes/AIOutcomeInferrer.swift`
- Purpose: on-device fallback evaluator for grouped suggestion outcomes.
- Called by: `OutcomeResolver`.
- Calls: Foundation Models session APIs and AI outcome DTOs.
- Read with: `OutcomeRuleEngine.swift`, `Data/Models/AIModels/Outcomes/*`.

### `Data/Services/AI/Shared/FoundationModelPrewarmer.swift`
- Purpose: shared warm-up helper for likely Foundation Models usage points.
- Called by: workout summary, set completion, rest timer, and live-activity/workout intents.
- Calls: Foundation Models session prewarm APIs.
- Read with: exercise progression and suggestion AI services.

### `Views/Suggestions/DeferredSuggestionsView.swift`
- Purpose: pre-workout review for pending/deferred suggestions.
- Called by: `WorkoutSessionContainer`.
- Calls: `pendingSuggestionEvents`, `groupSuggestions`, `SuggestionReviewView`, apply/reject helpers.
- Read with: `Views/Suggestions/SuggestionReviewView.swift`.

### `Views/Suggestions/SuggestionReviewView.swift`
- Purpose: shared grouped suggestion UI for both pre-workout review and summary review.
- Called by: `DeferredSuggestionsView`, `WorkoutSummaryView`.
- Calls: action closures, change-application helpers, save helpers.
- Read with: `Data/Models/Plans/SuggestionGrouping.swift`.

## Exercise Catalog and History

### `Data/Models/Exercise/Exercise.swift`
- Purpose: canonical exercise catalog row, favorites, recency, search metadata, alternate names.
- Called by: picker flows, entity resolution, catalog sync, plan/workout constructors.
- Calls: search-token helpers and fetch descriptors.
- Read with: `ExerciseCatalog.swift`, `Helpers/ExerciseSearch.swift`.

### `Data/Models/Exercise/ExerciseCatalog.swift`
- Purpose: built-in exercise dataset and seed version.
- Called by: `DataManager`, sample data.
- Calls: none.
- Read with: `DataManager.swift`.

### `Data/Models/Exercise/ExerciseHistory.swift`
- Purpose: derived analytics cache per exercise, including progression points and recency used by exercise ordering.
- Called by: exercise analytics UI, exercise entity query, history updater.
- Calls: recalculation helpers and fetch descriptors.
- Read with: `ProgressionPoint.swift`, `Data/Services/ExerciseHistoryUpdater.swift`.

### `Data/Services/ExerciseHistoryUpdater.swift`
- Purpose: rebuild/create/delete `ExerciseHistory` records from completed performances.
- Called by: workout summary, workout deletion flows.
- Calls: performance fetches, history recalculation, `SpotlightIndexer`.
- Read with: `ExerciseHistory.swift`, `Views/Exercise/ExerciseDetailView.swift`.

### `Views/Exercise/ExercisesListView.swift`
- Purpose: searchable exercise list ordered by completed-history recency.
- Called by: `ContentView`.
- Calls: `ExerciseSummaryRow`, search helpers, save helpers, donation helpers.
- Read with: `Views/Components/ExerciseSummaryRow.swift`, `Helpers/ExerciseSearch.swift`.

### `Views/Exercise/ExerciseDetailView.swift`
- Purpose: read-only analytics/detail screen for one exercise.
- Called by: navigation and exercise intents.
- Calls: `ExerciseHistory`, charts, `ExerciseHistoryView`.
- Read with: `Views/Exercise/ExerciseHistoryView.swift`.

### `Views/Exercise/ExerciseHistoryView.swift`
- Purpose: raw completed-performance history for one exercise.
- Called by: navigation, exercise detail, workout/plan sheets.
- Calls: performance queries, `RPEBadge`, time-format helpers.
- Read with: `Data/Models/Sessions/ExercisePerformance.swift`.

## Splits

### `Data/Models/WorkoutSplit/WorkoutSplit.swift`
- Purpose: split schedule aggregate, active split state, weekly/rotation day resolution.
- Called by: split views, split intents, widget/home "today" surfaces.
- Calls: day-resolution helpers, `saveContext` for rotation refresh.
- Read with: `WorkoutSplitDay.swift`, `Views/WorkoutSplit/WorkoutSplitView.swift`.

### `Data/Models/WorkoutSplit/WorkoutSplitDay.swift`
- Purpose: one day in a split, including rest-day status, target muscles, and assigned plan.
- Called by: split creation/editing, plan picker assignment.
- Calls: resolved-muscle helpers.
- Read with: `WorkoutSplit.swift`, `Views/WorkoutSplit/WorkoutSplitDayView.swift`.

### `Views/WorkoutSplit/WorkoutSplitView.swift`
- Purpose: main split editor and active/inactive split management entrypoint.
- Called by: navigation and split intents.
- Calls: `WorkoutSplitDayView`, `WorkoutSplitListView`, `SplitBuilderView`, rename/delete/rotation helpers, donations.
- Read with: `WorkoutSplit.swift`, `Views/HomeSections/WorkoutSplitSectionView.swift`.

### `Views/WorkoutSplit/WorkoutSplitListView.swift`
- Purpose: sheet-based split management list for active and inactive splits.
- Called by: `WorkoutSplitView`.
- Calls: `WorkoutSplitView`, `SplitBuilderView`, save helpers.
- Read with: `WorkoutSplitView.swift`.

### `Views/WorkoutSplit/WorkoutSplitDayView.swift`
- Purpose: per-day split editor for plan assignment, rest-day status, name, and target muscles.
- Called by: `WorkoutSplitView`.
- Calls: `WorkoutPlanPickerView`, `MuscleFilterSheetView`, save helpers.
- Read with: `WorkoutPlanPickerView.swift`.

### `Views/WorkoutSplit/SplitBuilderView.swift`
- Purpose: preset/scratch split creation flow.
- Called by: split screens when creating a new split.
- Calls: split/day model creation and save helpers.
- Read with: `WorkoutSplitView.swift`, `WorkoutSplitListView.swift`.

## Integrations

### `Intents/IntentDonations.swift`
- Purpose: central place for donating App Intents from UI/workflow events.
- Called by: home, workout, plan, split, exercise, and timer surfaces.
- Calls: `.donate()` on specific intents.
- Read with: relevant intent files under `Intents/`.

### `Intents/VillainArcShortcuts.swift`
- Purpose: declares the app's discoverable shortcut surface.
- Called by: `VillainArcApp` and the system shortcuts framework.
- Calls: shortcut registration for selected workout, split, exercise, and timer intents.
- Read with: the underlying intent files and `IntentDonations.swift`.

### `Intents/Workout/*`, `Intents/WorkoutPlan/*`, `Intents/WorkoutSplit/*`, `Intents/Exercise/*`, `Intents/RestTimer/*`
- Purpose: Siri/Shortcuts/App Intent entrypoints into the same app logic.
- Called by: system intent execution, donations, widgets, snippets.
- Calls: `SetupGuard`, `AppRouter`, shared services, model fetch/mutation logic.
- Read with: `AppRouter.swift`, corresponding feature views/models.

### `Intents/Workout/WorkoutSessionEntity.swift`, `Intents/WorkoutPlan/WorkoutPlanEntity.swift`, `Intents/WorkoutSplit/WorkoutSplitEntity.swift`, `Intents/Exercise/ExerciseEntity.swift`
- Purpose: App Entity definitions, search/query logic, Spotlight association, and transfer payloads.
- Called by: Spotlight indexing, intent parameter resolution, donations, user activities.
- Calls: shared model fetches, search helpers, JSON transfer/export logic.
- Read with: `Data/Services/SpotlightIndexer.swift`, corresponding model files.

### `Intents/OpenAppIntent.swift` and `Intents/RestTimer/RestTimerSnippetView.swift`
- Purpose: common foreground handoff target and snippet-based rest timer surface.
- Called by: many foreground intents and timer-control intents.
- Calls: rest timer control intents, app open results, time-format helpers.
- Read with: `Intents/RestTimer/*`, `Helpers/TimeFormatting.swift`.

### `Data/Services/SpotlightIndexer.swift`
- Purpose: index and remove workouts, plans, and exercises in Spotlight.
- Called by: workout/plan completion and deletion flows, history updater.
- Calls: CoreSpotlight APIs and entity association helpers.
- Read with: entity files under `Intents/*Entity.swift`, `AppRouter.handleSpotlight`.

### `Data/Services/RestTimerState.swift`
- Purpose: app-wide timer state machine with persistence and notification hookup.
- Called by: timer UI, set rows, workout views, timer intents, live-activity intents, router cleanup.
- Calls: `RestTimerNotifications`, `WorkoutActivityManager`, `UserDefaults`.
- Read with: `Views/Workout/RestTimerView.swift`, `Helpers/RestTimerNotifications.swift`.

### `Data/LiveActivity/WorkoutActivityManager.swift`
- Purpose: workout live-activity lifecycle and synchronization.
- Called by: workout UI, timer state, live-activity intents.
- Calls: ActivityKit APIs, `AppSettings.single`, current workout fetches.
- Read with: `Data/LiveActivity/WorkoutActivityAttributes.swift`, widget extension files.

### `VillainArcWidgetExtension/*`
- Purpose: home widget and workout live-activity UI.
- Called by: widget extension runtime.
- Calls: shared models, live-activity attributes, split/workout intents.
- Read with: `Intents/LiveActivity/*`, `Data/LiveActivity/*`.

## Helpers and Shared UI

### `Helpers/Accessibility.swift`
- Purpose: central accessibility IDs, labels, hints, and formatting helpers.
- Called by: most views.
- Calls: internal string/ID helpers.
- Read with: any view adding new UI controls.

### `Helpers/ExerciseSearch.swift` and `Helpers/TextNormalization.swift`
- Purpose: exercise search scoring, tokenization, fuzzy matching, and entity search behavior.
- Called by: exercise lists, add/replace flows, exercise entity query.
- Calls: normalization and phrase/token scoring helpers.
- Read with: `Data/Models/Exercise/Exercise.swift`, `Intents/Exercise/ExerciseEntity.swift`.

### `Helpers/TimeFormatting.swift`
- Purpose: shared date/time and timer display formatting.
- Called by: workout, exercise, timer, and snippet UI.
- Calls: Foundation formatting APIs.
- Read with: any view showing time or date ranges.

### `Helpers/WeightFormatting.swift`
- Purpose: `formattedWeightText` and `formattedWeightValue` helpers that convert a kg value to the user's preferred unit and format it with a label.
- Called by: exercise detail, history, workout summary, workout detail, plan detail, and exercise summary views.
- Calls: `WeightUnit.display` / `WeightUnit.fromKg`.
- Read with: `Data/Models/Enums/WeightUnit.swift`, `Data/Models/AppSettings.swift`.

### `Data/Models/Enums/WeightUnit.swift`
- Purpose: `WeightUnit` enum (`.kg` / `.lbs`) with `fromKg`, `toKg`, `display`, and `systemDefault` helpers. Canonical persisted weight uses kg, while active `WorkoutSession` rows and editable `WorkoutPlan` copies may be converted into the user's current unit during logging or editing before save/finish paths normalize back to kg.
- Called by: every view that shows or accepts a weight value, suggestion context, Live Activity manager.
- Calls: none.
- Read with: `Helpers/WeightFormatting.swift`, `Data/Models/AppSettings.swift`.

### `Data/Models/Enums/HeightUnit.swift`
- Purpose: `HeightUnit` enum (`.cm` / `.imperial`) with `toCm`, `fromCm`, `displayString`, and `systemDefault` helpers. Height is stored as `heightCm` on `UserProfile`.
- Called by: onboarding height step.
- Calls: none.
- Read with: `Data/Models/UserProfile.swift`, `Views/Onboarding/OnboardingView.swift`.

### `Views/Components/Navbar.swift`
- Purpose: shared sheet/navigation title bars and close button behavior.
- Called by: root and sheet-style views.
- Calls: `Haptics`, dismiss environment action.
- Read with: `TextEntryEditorView.swift`, editor sheets.

### `Views/Components/WorkoutRowView.swift`, `Views/Components/WorkoutPlanRowView.swift`, `Views/Components/ExerciseSummaryRow.swift`
- Purpose: reusable navigation row surfaces for workouts, plans, and exercises.
- Called by: home sections and list screens.
- Calls: `AppRouter`, `IntentDonations`, presentational card components.
- Read with: corresponding detail/list views.

### `Views/Workout/AddExerciseView.swift`, `Views/Workout/FilteredExerciseListView.swift`, `Views/Workout/ReplaceExerciseView.swift`
- Purpose: shared exercise selection and replacement surfaces used by workout and plan flows.
- Called by: workout and plan editors.
- Calls: exercise queries, search helpers, favorite toggles, save helpers, donation helpers.
- Read with: `Exercise.swift`, `Helpers/ExerciseSearch.swift`.

## Tests

### `VillainArcTests/WorkoutFinishTests.swift`
- Purpose: protects finish-time pruning and incomplete-set resolution.
- Read with: `Data/Models/Sessions/WorkoutSession.swift`.

### `VillainArcTests/VillainArcTests.swift`
- Purpose: protects plan editing semantics and suggestion override behavior.
- Read with: `Data/Models/Plans/WorkoutPlan+Editing.swift`.

### `VillainArcTests/SuggestionSystemTests.swift`
- Purpose: protects training-style detection, suggestion generation, deduplication, and outcome logic.
- Read with: `Data/Services/Suggestions/*`.

### `VillainArcTests/ExerciseReplacementTests.swift`
- Purpose: protects exercise replacement mechanics and historical link cleanup.
- Read with: `ExercisePerformance.swift`, `WorkoutSession(from: plan)` paths.

### `VillainArcTests/DataManagerCatalogSyncTests.swift`
- Purpose: protects catalog metadata propagation into plan/session exercise copies.
- Read with: `DataManager.swift`, `Exercise.swift`.

### `VillainArcTests/ExerciseHistoryMetricsTests.swift`
- Purpose: protects rep-based history metrics and progression points.
- Read with: `ExerciseHistory.swift`, `ExerciseHistoryUpdater.swift`.

# VillainArc Architecture Map

**Status**: Current
**Last updated**: 2026-03-11
**Scope**: Full codebase — root app/navigation + onboarding + persistence/Spotlight + intent/shortcuts/donations + workout history/detail + workout session/suggestions + suggestion rules/AI pipeline + workout plan list/detail + split planning/editing + exercise selection/editor slice + helper utility slice + data model layer (session/plan/split/history/suggestions).
**See also**: `PROJECT_GUIDE.md` for conceptual overview and feature→file map. `WORKOUT_PLAN_SUGGESTION_FLOW.md` for suggestion engine deep dive.

## 1) Architecture Map

- `VillainArcApp`
  - Creates root `ContentView`
  - Injects `SharedModelContainer.container`
  - Forwards Spotlight/Siri user activities to `AppRouter.shared`
- `ContentView`
  - Binds root navigation and modal state to `AppRouter.shared`
  - Runs startup bootstrap via `DataManager.seedExercisesIfNeeded`
  - Hosts home sections including `RecentWorkoutSectionView` and `RecentExercisesSectionView`
  - Uses shared UI helpers (`navBar`, accessibility labels/ids)
- `AppRouter.shared`
  - Owns app navigation/workflow state (`path`, active workout/plan, transient intent-driven sheet flags)
  - Reads/writes SwiftData through `SharedModelContainer.container.mainContext`
  - Persists via `saveContext`
  - Uses `SpotlightIndexer` prefixes when resolving Spotlight identifiers
- `SharedModelContainer`
  - Defines the SwiftData schema
  - Builds the shared `ModelContainer` (app-group store when available)
- `WorkoutSession` / `ExercisePerformance` / `SetPerformance`
  - Runtime logging models for active/completed workouts
  - Tie UI logging flows to suggestion generation/outcome evaluation inputs
- `WorkoutPlan` / `ExercisePrescription` / `SetPrescription`
  - Persistent training prescription models used by plan editing and plan-based session starts
  - Target surface for suggestion application and user edit overrides
- `PrescriptionChange` + suggestion grouping helpers
  - Persist suggestion lifecycle (`pending/accepted/rejected/deferred` + outcome)
  - Link source evidence to target plan/set modifications
- `WorkoutSplit` / `WorkoutSplitDay`
  - Weekly/rotation scheduling models used by split management and "today's workout" routing
- `WorkoutSplitEntity` + nested transfer payloads
  - Split export/share representation with ordered day snapshots and lightweight workout-plan references
- `Exercise` + catalog/search metadata + `ExerciseHistory`/`ProgressionPoint`
  - Canonical exercise identity/search + derived longitudinal performance cache
- `AppSettings`
  - Singleton app-preference model for workout logging, rest timer, notifications, and live-activity behavior
- `UserProfile`
  - User account data (name, birthday, height) collected during onboarding
- `RepRangePolicy` / `RestTimeHistory` / `PreWorkoutContext`
  - Reusable policy and session-adjacent models shared by workout and plan flows
- `OnboardingManager`
  - First-run state machine (network/iCloud/CloudKit checks → sync → seed → Spotlight rebuild → profile collection)
- `SetupGuard`
  - Intent pre-condition guard that validates initial bootstrap/user profile setup and, for navigation intents, preserves the single-active-flow invariant without creating missing singleton records
- `SystemState`
  - Shared singleton bootstrap helper that ensures `UserProfile` and `AppSettings` exist before feature code reads them
- `DataManager` (`saveContext` / `scheduleSave`)
  - Seeds and dedupes exercise catalog data
  - Provides shared save helpers used by router/views/models
- `SpotlightIndexer`
  - Indexes/deletes workout sessions, workout plans, and exercises in Spotlight
  - Exercise items use shared system alternate names plus the exercise subtitle for richer Spotlight matches
  - Prefix constants are consumed by `AppRouter.handleSpotlight`
- `IntentDonations`
  - Central donation adapter from UI/workflow events to App Intents
- `VillainArcShortcuts`
  - Declares the discoverable App Shortcuts surface
- `App Intents` (`Workout*`, `WorkoutSplit*`, `WorkoutPlan*`, `Exercise*`, `RestTimer*`, `OpenAppIntent`)
  - Handle Siri/Shortcuts actions and foreground/background routing
- `LiveActivity Intents` + `RestTimerSnippetIntent`
  - Support lock-screen/live activity controls and snippet interactions
- `RecentWorkoutSectionView`
  - Queries the latest workout for home summary
  - Navigates to workout history via `AppRouter.navigate(.workoutSessionsList)`
- `RecentExercisesSectionView`
  - Queries recently used exercises for the home "Exercises" section
  - Navigates to the exercises list and exercise detail screens via `AppRouter`
- `ExerciseSummaryRow`
  - Reusable exercise card row for home and exercise-list navigation
- `WorkoutRowView`
  - Reusable workout summary card row
  - Navigates to workout detail via `AppRouter.navigate(.workoutSessionDetail)`
- `ExerciseSetRowView`
  - Editable set row used in active workout exercises
  - Handles set type, reps/weight logging, completion, timer start, and per-set quick actions
- `WorkoutsListView`
  - Shows completed workouts list
  - Handles bulk/single delete with Spotlight cleanup + exercise history recompute
- `ExercisesListView`
  - Shows all exercises sorted by `lastUsed`
  - Navigates to `ExerciseDetailView` for the selected exercise
- `ExerciseDetailView`
  - Read-only exercise analytics screen keyed by `catalogID`
  - Reads `Exercise` + cached `ExerciseHistory` metrics instead of scanning performances directly
  - Combines summary stat tiles with a picker-driven progress chart surface and links to full performance history
- `ExerciseHistoryView`
  - Shows every completed `ExercisePerformance` for one `catalogID`
  - Uses sectioned set grids to display performed sets, rest, rep range, and notes
- `WorkoutDetailView`
  - Shows one workout's exercises/sets and notes
  - Handles delete + "save as plan" actions
- `WorkoutSessionContainer`
  - Chooses workout flow screen by session status
  - Routes pending sessions to suggestions review, active sessions to workout logging, and done sessions to summary
- `WorkoutView`
  - Active workout logging screen with exercise pager/list, add exercise, rest timer, and finish/cancel flows
- `ExerciseView`
  - Per-exercise logging page with set grid, rep/rest editors, replace flow, and notes
- `PreWorkoutContextView`
  - Pre-workout check-in sheet for energy/mood/notes
- `RestTimerView`
  - Rest-timer sheet with countdown controls, recents, and next-set quick complete action
- `WorkoutSummaryView`
  - Post-workout summary with stats/PRs, effort rating, suggestion review, and save-as-plan actions
- `DeferredSuggestionsView`
  - Pre-workout suggestion decision screen for sessions launched from plans
- `SuggestionReviewView`
  - Shared grouped suggestion UI + accept/reject/defer action wiring used in pending and summary stages
- `SuggestionGenerator`
  - Builds post-workout prescription suggestions for plan-based sessions
  - Orchestrates training-style inference, rule evaluation, and deduplication
- `RuleEngine`
  - Deterministic suggestion rule set (progression, safety, rest, set-type cleanup)
- `MetricsCalculator`
  - Shared heuristics for training style detection, progression set selection, and weight increments
- `SuggestionDeduplicator`
  - Resolves conflicting/overlapping suggested changes before persistence
- `OutcomeResolver`
  - Scores prior suggestions after the next workout using rules + optional AI override
- `OutcomeRuleEngine`
  - Deterministic outcome scoring for each accepted/rejected change
- `AITrainingStyleClassifier` + `RecentExercisePerformancesTool`
  - On-device model classification used when set-style inference is ambiguous
- `AIOutcomeInferrer`
  - On-device model evaluator for group-level suggestion outcomes during resolution
- `ExerciseHistoryUpdater`
  - Rebuilds exercise history stats from completed performances
  - Used after workout completion/deletion flows
- `RecentWorkoutPlanSectionView`
  - Queries the latest workout plan for home summary
  - Navigates to workout plan list via `AppRouter.navigate(.workoutPlansList)`
- `WorkoutPlanRowView`
  - Reusable row wrapper for a workout plan card
  - Navigates to workout plan detail via `AppRouter.navigate(.workoutPlanDetail)`
- `WorkoutPlanCardView`
  - Presentational card for plan title, muscles targeted, and exercise list
- `WorkoutPlansListView`
  - Shows workout plans list with favorite filter and edit/delete flows
  - Handles Spotlight cleanup on delete
- `WorkoutPlanDetailView`
  - Shows one plan's exercises/sets and notes
  - Supports favorite toggle, start workout, edit copy flow, and delete
- `WorkoutPlanView`
  - Full-screen create/edit workflow for a workout plan
  - Handles exercise editing, notes/title editing, save/cancel, and Spotlight update
- `TextEntryEditorView`
  - Reusable single-field sheet editor for titles/notes
  - Used by workout, workout-plan, workout-summary, and split-name editing flows
- `AddExerciseView`
  - Shared add-exercise modal for workouts and workout plans
  - Uses `FilteredExerciseListView` for selection and `MuscleFilterSheetView` for filter chips
- `FilteredExerciseListView`
  - Reusable searchable/filterable exercise catalog list with selection state
  - Supports both multi-select add flow and single-select replacement flow
- `ReplaceExerciseView`
  - Single-select replacement flow for swapping one workout exercise to another
  - Reuses catalog filtering and muscle filter sheet behavior
- `MuscleFilterSheetView`
  - Reusable major/minor muscle selection sheet with apply/clear behavior
- `RepRangeEditorView`
  - Rep-range policy editor with mode switching and history-based suggestion
- `RestTimeEditorView`
  - Rest-time policy editor for all-same/individual/by-type modes
  - Uses `TimerDurationPicker` for rest duration selection
- `WorkoutPlanPickerView`
  - Select/clear/create workflow for choosing a plan
  - Used by split-day assignment flows
- `WorkoutSplitView`
  - Split overview screen (active + inactive splits)
  - Handles split actions (rotation/offset), split activation, per-day plan selection, and publishes the current split as a searchable/predictable user activity
- `WorkoutSplitSectionView`
  - Home-level split summary card with quick routes to split settings/today plan
  - Uses `SmallUnavailableView` and section header button patterns
- `SplitBuilderView`
  - Guided split creation flow (scratch or templates)
  - Creates split/day models and routes to split detail editor
- `WorkoutSplitCreationView`
  - Split detail editor (weekly/rotation headers, rename, swap/rotate day controls, delete split)
  - Hosts per-day editing pages via `WorkoutSplitDayView`
- `WorkoutSplitDayView`
  - Per-day split editor (rest toggle, day naming, plan assignment, target muscles)
  - Opens plan picker and muscle picker sheets
- `HomeSectionHeaderButton`
  - Reusable section-header action button used by home cards
- `Navbar` (`InlineLargeTitle` / `CloseButton` / `SheetTitleBar`)
  - Shared top safe-area title bar and close action for sheet-style screens
- `Accessibility` (`AccessibilityIdentifiers` / `AccessibilityText`)
  - Centralized accessibility IDs, labels, hints, and formatting helpers used across views
- `Haptics`
  - Centralized UI feedback wrapper used by router and interactive views
- `TimeFormatting`
  - Shared `secondsToTime` and `formattedDateRange` helpers for timer/date display

## 2) File Index

### `VillainArc/Root/VillainArcApp.swift`
- Does: App entry point. Boots `ContentView`, injects SwiftData container, forwards Siri/Spotlight activity to router.
- Called by: iOS runtime (`@main`).
- Calls: `ContentView`, `VillainArcShortcuts.updateAppShortcutParameters`, `AppRouter.shared.handleSpotlight`, `AppRouter.shared.handleSiriWorkout`, `AppRouter.shared.handleSiriCancelWorkout`, `.modelContainer(SharedModelContainer.container)`.

### `VillainArc/Views/ContentView.swift`
- Does: Root/home UI shell. Hosts `NavigationStack`, menu actions, startup seed/resume task, and workout/plan presentations.
- Called by: `VillainArcApp`, SwiftUI preview.
- Calls: `AppRouter.startWorkoutSession`, `AppRouter.createWorkoutPlan`, `AppRouter.checkForUnfinishedData`, `OnboardingManager.startOnboarding`, home sections (`WorkoutSplitSectionView`, `RecentWorkoutSectionView`, `RecentWorkoutPlanSectionView`, `RecentExercisesSectionView`), destination views (`WorkoutsListView`, `WorkoutDetailView`, `WorkoutPlansListView`, `WorkoutPlanDetailView`, `ExercisesListView`, `ExerciseDetailView`, `ExerciseHistoryView`, `WorkoutSplitView`, `WorkoutSplitCreationView`), full-screen views (`WorkoutSessionContainer`, `WorkoutPlanView`), `IntentDonations.*`.

### `VillainArc/Data/Services/AppRouter.swift`
- Does: App-wide navigation/workflow coordinator. Owns `path`, `activeWorkoutSession`, `activeWorkoutPlan`, transient intent-driven sheet flags, auto-resumes unfinished workout/plan work on launch, blocks parallel flows while one is active, and routes Spotlight results for workouts, plans, and exercises.
- Called by: `VillainArcApp`, `ContentView`, many feature views under `VillainArc/Views/*`, and app intents under `VillainArc/Intents/*`.
- Calls: SwiftData context (`insert/fetch/delete` via `SharedModelContainer.container.mainContext`), `saveContext`, `Haptics.selection`, `pendingSuggestions`, `RestTimerState.shared.stop`, `WorkoutActivityManager.end`, `SpotlightIndexer.workoutSessionIdentifierPrefix`, `SpotlightIndexer.workoutPlanIdentifierPrefix`, `SpotlightIndexer.exerciseIdentifierPrefix`.

### `VillainArc/Data/SharedModelContainer.swift`
- Does: Defines app-wide SwiftData schema, creates the shared `ModelContainer`, and exposes app-group `UserDefaults` for non-model shared state like catalog versioning and rest-timer restoration.
- Called by: `VillainArcApp` (`.modelContainer`), `AppRouter` (`mainContext`), `WorkoutActivityManager`, and many app intent/entity files.
- Calls: `Schema(...)` with model types, `FileManager.default.containerURL(...)`, `ModelConfiguration(...)`, `ModelContainer(for:configurations:)`.

### `VillainArc/Data/Services/DataManager.swift`
- Does: Catalog bootstrap/dedupe (`DataManager`) plus shared persistence helpers (`saveContext`, `scheduleSave`); catalog metadata sync also propagates canonical exercise name/muscles/equipment updates into matching plan/session exercise snapshots.
- Called by: `ContentView` (`seedExercisesIfNeeded`), `AddExerciseView` (`dedupeCatalogExercisesIfNeeded`), exercise intents, and many views/models/router through `saveContext`/`scheduleSave`.
- Calls: app-group `UserDefaults` (`exerciseCatalogVersion`), `ExerciseCatalog` (`catalogVersion`, `all`, `byID`), `ModelContext.fetch/insert/delete/save`.

### `VillainArc/Data/Services/OnboardingManager.swift`
- Does: First-run state machine orchestrating network/iCloud/CloudKit checks, data sync, exercise catalog seeding, fresh-install Spotlight rebuild, and singleton bootstrap for `UserProfile` plus `AppSettings`.
- Called by: `ContentView` (via `onboardingManager.startOnboarding()`).
- Calls: `NetworkMonitor.checkConnectivity`, `CloudKitStatusChecker.checkiCloudStatus/checkCloudKitAvailability`, `DataManager.seedExercisesForOnboarding`, `SpotlightIndexer.reindexAll`, `SystemState.ensureUserProfile`, `SystemState.ensureAppSettings`, `saveContext`.

### `VillainArc/Data/Services/SetupGuard.swift`
- Does: Intent pre-condition guard that validates initial bootstrap, required singleton presence, and user profile setup before allowing intent execution, with a shared helper for blocking navigation while a workout or plan flow is already active.
- Called by: flow-entry and navigation intents including `StartWorkoutIntent`, `CreateWorkoutPlanIntent`, `StartTodaysWorkoutIntent`, `OpenWorkoutIntent`, `OpenWorkoutPlanIntent`, `OpenExerciseIntent`, `OpenExercisesIntent`, `OpenWorkoutSplitIntent`, `CreateWorkoutSplitIntent`, `ManageWorkoutSplitsIntent`, `OpenTodaysPlanIntent`, `ShowWorkoutHistoryIntent`, `ShowWorkoutPlansIntent`, and `ViewLastWorkoutIntent`.
- Calls: `DataManager.hasCompletedInitialBootstrap`, `AppSettings.single`, `UserProfile.single`, `WorkoutPlan.incomplete`, `WorkoutSession.incomplete`, `SetupGuardError`, `StartWorkoutError`.

### `VillainArc/Data/Services/SystemState.swift`
- Does: Shared singleton bootstrap service that lazily ensures `UserProfile` and `AppSettings` exist.
- Called by: `OnboardingManager`, `WorkoutSettingsView`.
- Calls: `UserProfile.single`, `AppSettings.single`, `ModelContext.fetch/insert/save`.

### `VillainArc/Data/Services/Suggestions/SuggestionGenerator.swift`
- Does: Generates `PrescriptionChange` suggestions for completed plan-based sessions by combining deterministic rules with optional AI style inference.
- Called by: `WorkoutSummaryView` (`generateSuggestionsIfNeeded`).
- Calls: `MetricsCalculator.detectTrainingStyle`, `AITrainingStyleClassifier.infer`, `RuleEngine.evaluate`, `SuggestionDeduplicator.process`, `ExercisePerformance.matching(...)`, `ModelContext.fetch`.

### `VillainArc/Data/Services/Suggestions/RuleEngine.swift`
- Does: Main deterministic suggestion engine (progression/safety/rest/set-type rules) that emits candidate `PrescriptionChange` values.
- Called by: `SuggestionGenerator`.
- Calls: `MetricsCalculator.selectProgressionSets`, `MetricsCalculator.weightIncrement`, `MetricsCalculator.roundToNearestPlate`, model helpers (`ExercisePerformance.effectiveRestSeconds`, `repRange`, set/prescription linkage), `PrescriptionChange` initializers.

### `VillainArc/Data/Services/Suggestions/MetricsCalculator.swift`
- Does: Shared training metrics helper for style detection, progression set selection, increment sizing, and plate rounding.
- Called by: `SuggestionGenerator`, `RuleEngine`, `OutcomeResolver`, `OutcomeRuleEngine`.
- Calls: Internal heuristics only (`detectTrainingStyle`, `setsForStyle`, `weightIncrement`, `roundToNearestPlate`).

### `VillainArc/Data/Services/Suggestions/SuggestionDeduplicator.swift`
- Does: Conflict resolver for generated suggestions (strategy conflicts, policy conflicts, same-target property collisions).
- Called by: `SuggestionGenerator`.
- Calls: Internal grouping/priority helpers (`resolveLogicalConflicts`, `resolveConflicts`).

### `VillainArc/Data/Services/Suggestions/OutcomeResolver.swift`
- Does: Resolves outcomes for prior suggestions in the next workout by combining deterministic rule results with optional AI inference at group level.
- Called by: `WorkoutSummaryView` (`generateSuggestionsIfNeeded` pre-step).
- Calls: `OutcomeRuleEngine.evaluate`, `AIOutcomeInferrer.inferApplied`, `AIOutcomeInferrer.inferRejected`, `MetricsCalculator.detectTrainingStyle`, change outcome mutation helpers, `ModelContext.save`.

### `VillainArc/Data/Services/Suggestions/OutcomeRuleEngine.swift`
- Does: Deterministic per-change outcome evaluator (`good` / `tooAggressive` / `tooEasy` / `ignored`) using actual set performance.
- Called by: `OutcomeResolver`.
- Calls: `MetricsCalculator.weightIncrement`, change-type-specific evaluation helpers.

### `VillainArc/Data/Services/Suggestions/AITrainingStyleClassifier.swift`
- Does: On-device Foundation Models classifier for exercise training style when deterministic style detection is inconclusive.
- Called by: `SuggestionGenerator` (for `.unknown` style cases).
- Calls: `SystemLanguageModel.default`, `LanguageModelSession`, `RecentExercisePerformancesTool`, `AIInferenceOutput` generation/validation.

### `VillainArc/Data/Services/Suggestions/AITrainingStyleTools.swift`
- Does: Defines `RecentExercisePerformancesTool` used by the style classifier to fetch recent exercise history snapshots.
- Called by: `AITrainingStyleClassifier` (tool-enabled `LanguageModelSession`).
- Calls: `ModelContext(SharedModelContainer.container)`, `ExercisePerformance.matching(...)`, `ModelContext.fetch`, `AIExercisePerformanceSnapshot`.

### `VillainArc/Data/Services/Suggestions/AIOutcomeInferrer.swift`
- Does: On-device Foundation Models evaluator that infers grouped suggestion outcomes for applied vs rejected paths.
- Called by: `OutcomeResolver`.
- Calls: `SystemLanguageModel.default`, `LanguageModelSession`, `AIOutcomeGroupInput` prompts, `AIOutcomeInferenceOutput` validation.

### `VillainArc/Data/Services/Suggestions/FoundationModelPrewarmer.swift`
- Does: Lightweight Foundation Models warm-up helper that loads a generic `LanguageModelSession` into memory ahead of likely suggestion-summary work.
- Called by: `WorkoutSummaryView`, `ExerciseSetRowView`, `RestTimerView`, `CompleteActiveSetIntent`, `LiveActivityCompleteSetIntent`, `FinishWorkoutIntent`.
- Calls: `SystemLanguageModel.default`, `LanguageModelSession.prewarm`.

### `VillainArc/Data/Services/SpotlightIndexer.swift`
- Does: Central Spotlight indexing/deindexing for `WorkoutSession`, `WorkoutPlan`, and `Exercise`; defines reusable identifier prefixes. Exercise eligibility is driven by `ExerciseHistory` presence during history updates and full Spotlight rebuilds, and exercise Spotlight metadata uses shared system alternate names plus the exercise subtitle.
- Called by: workout/plan views for index/delete actions, `ExerciseHistoryUpdater`, `AppRouter` (Spotlight identifier parsing), and related intent/editing flows.
- Calls: `CSSearchableItemAttributeSet`, `CSSearchableItem`, `CSSearchableIndex.default().indexSearchableItems`, `CSSearchableIndex.default().deleteSearchableItems`, `associateAppEntity(...)` using `WorkoutSessionEntity`, `WorkoutPlanEntity`, `ExerciseEntity`.

### `VillainArc/Views/HomeSections/RecentWorkoutSectionView.swift`
- Does: Home "Workouts" section; shows empty state or latest workout card and provides quick navigation to workout history.
- Called by: `ContentView`, SwiftUI preview.
- Calls: `@Query(WorkoutSession.recent)`, `HomeSectionHeaderButton`, `AppRouter.navigate(to: .workoutSessionsList)`, `WorkoutRowView`, `IntentDonations.donateShowWorkoutHistory`, `IntentDonations.donateViewLastWorkout`.

### `VillainArc/Views/Components/WorkoutRowView.swift`
- Does: Reusable workout summary row/card that opens workout detail when tapped.
- Called by: `RecentWorkoutSectionView`, `WorkoutsListView`, SwiftUI preview.
- Calls: `AppRouter.navigate(to: .workoutSessionDetail(...))`, `IntentDonations.donateOpenWorkout`, `AccessibilityText.workoutRowLabel/workoutRowValue/workoutRowHint`.

### `VillainArc/Views/Components/ExerciseSetRowView.swift`
- Does: Editable set row used during active workout logging (set type, reps/weight fields, target/previous reference apply, complete/uncomplete, optional actual RPE badge, and inline RPE submenu picker). Linked plan targets stay in the target/reference column, and `AppSettings` can auto-complete the set immediately after the user picks an RPE. Completing the final remaining set in a plan workout also prewarms the suggestion pipeline.
- Called by: `ExerciseView`, SwiftUI preview via `ExerciseView`.
- Calls: `RPEBadge`, `RPEValue`, `AppSettings.single` query, `RestTimerState.shared`, `RestTimeHistory.record`, `FoundationModelPrewarmer`, `WorkoutActivityManager.update`, `IntentDonations.donateStartRestTimer`, `IntentDonations.donateCompleteActiveSet`, `Haptics.selection`, `saveContext`, `scheduleSave`, `secondsToTime`.

### `VillainArc/Views/Components/RPEBadge.swift`
- Does: Shared compact RPE badge for actual set RPE and plan target RPE display.
- Called by: `ExerciseSetRowView`, `WorkoutDetailView`, `WorkoutPlanDetailView`, `WorkoutPlanView`.
- Calls: None (display helper only).

### `VillainArc/Views/Components/RepRangeButton.swift`
- Does: Shared rep-range trigger button that observes `RepRangePolicy` directly so rep-range display text updates immediately in workout and plan headers.
- Called by: `ExerciseView`, `WorkoutPlanView` (`WorkoutPlanExerciseView`).
- Calls: `Haptics.selection`.

### `VillainArc/Views/Onboarding/OnboardingView.swift`
- Does: Half-sheet onboarding UI progressing through system checks, data sync, and profile collection (name/birthday/height).
- Called by: `SetupGuard` (presented as non-dismissible sheet).
- Calls: `OnboardingManager` state observation, `UserProfile` bindings, `Haptics.selection`.

### `VillainArc/Views/HomeSections/HomeSectionHeaderButton.swift`
- Does: Reusable home section header button with title + chevron styling and accessibility wiring.
- Called by: `RecentWorkoutSectionView`, `RecentWorkoutPlanSectionView`, `RecentExercisesSectionView`, `WorkoutSplitSectionView`.
- Calls: Provided `action` closure.

### `VillainArc/Views/HomeSections/RecentExercisesSectionView.swift`
- Does: Home "Exercises" section; shows the most recently used exercises using the shared summary cards enriched with cached history chips, and links to the full exercises list.
- Called by: `ContentView`, SwiftUI preview.
- Calls: `@Query(Exercise.all)`, `@Query(ExerciseHistory)`, `HomeSectionHeaderButton`, `AppRouter.navigate(to: .exercisesList)`, `IntentDonations.donateOpenExercises`, `ExerciseSummaryRow`, `SmallUnavailableView`.

### `VillainArc/Views/Components/SmallUnavailableView.swift`
- Does: Compact unavailable/empty-state presentational component.
- Called by: `WorkoutSplitSectionView`, `RecentExercisesSectionView`, SwiftUI preview.
- Calls: None (display-only component).

### `VillainArc/Views/Components/TextEntryEditorView.swift`
- Does: Reusable single-text-field sheet editor (title/notes style) with auto-focus and trim-on-close behavior.
- Called by: `WorkoutPlanView`, `WorkoutView`, `WorkoutSummaryView`, `WorkoutSplitCreationView`, SwiftUI preview.
- Calls: `dismissKeyboard`, `.navBar(title:)`, `CloseButton`, bound text mutation (`trimmingCharacters`).

### `VillainArc/Views/Components/SummaryStatCard.swift`
- Does: Shared glass stat tile used for compact summary metrics across workout and exercise progress screens.
- Called by: `WorkoutSummaryView`, `ExerciseDetailView`.
- Calls: None (presentational component).

### `VillainArc/Views/Components/ExerciseSummaryRow.swift`
- Does: Shared exercise summary card row for navigation surfaces, showing exercise identity plus cached context like subtitle, favorite badge, last-used state, session count, and best-set chips when history is available.
- Called by: `RecentExercisesSectionView`, `ExercisesListView`.
- Calls: `AppRouter.navigate(to: .exerciseDetail(...))`, `IntentDonations.donateOpenExercise`.

### `VillainArc/Views/History/WorkoutsListView.swift`
- Does: List of completed workouts with edit mode, per-item delete, and delete-all workflow.
- Called by: `ContentView` navigation destination for `.workoutSessionsList`, SwiftUI preview.
- Calls: `@Query(WorkoutSession.completedSession)`, `WorkoutRowView`, `Haptics.selection`, `SpotlightIndexer.deleteWorkoutSessions`, `ModelContext.delete`, `ExerciseHistoryUpdater.updateHistory`, `IntentDonations.donateDeleteWorkout`, `IntentDonations.donateDeleteAllWorkouts`.

### `VillainArc/Views/Exercise/ExercisesListView.swift`
- Does: Searchable list of all exercises sorted by `lastUsed`, with favorites-only filtering, swipe actions to toggle favorites, and shared summary cards populated with cached exercise-history chips before navigating to exercise detail.
- Called by: `ContentView` navigation destination for `.exercisesList`, SwiftUI previews.
- Calls: `@Query(Exercise.all)`, `@Query(ExerciseHistory)`, exercise search helpers (`normalizedTokens`, `exerciseSearchMatches`, fuzzy matching), `ExerciseSummaryRow`, `IntentDonations.donateToggleExerciseFavorite`, `Haptics.selection`, `saveContext`.

### `VillainArc/Views/Exercise/ExerciseDetailView.swift`
- Does: Read-only exercise detail/progress screen keyed by `catalogID` backed by `Exercise` + `ExerciseHistory`, with smart non-zero stat tiles, segmented progression metrics, charts gated until at least two points exist, and interactive chart selection that reveals a rule-mark callout for the chosen session.
- Called by: `ContentView` navigation destination for `.exerciseDetail`, SwiftUI previews; intended for reuse from workout, plan, and active-session exercise surfaces.
- Calls: `@Query(Exercise.withCatalogID)`, `@Query(ExerciseHistory.forCatalogID)`, `SummaryStatCard`, `Charts` line/point/rule marks, chart selection modifiers, chart scaling helpers, `AppRouter.navigate(to: .exerciseHistory(...))`, cached history metrics.

### `VillainArc/Views/Exercise/ExerciseHistoryView.swift`
- Does: List of all completed performances for one exercise, with one section per performance and a set grid showing set label/type, weight, reps, rest, rep range, per-set RPE badges, and notes. Supports both browse navigation (`catalogID`) and future contextual sheet presentation from workout/plan exercise headers.
- Called by: `ContentView` navigation destination for `.exerciseHistory`, future workout/plan sheets, SwiftUI previews.
- Calls: `@Query(Exercise.withCatalogID)`, `@Query(ExercisePerformance.matching(...))`, `RPEBadge`, `formattedDateRange`, `secondsToTime`.

### `VillainArc/Views/Workout/WorkoutDetailView.swift`
- Does: Detailed readout for one completed workout (notes, exercises, sets, rest, actual RPE badges, pre-workout context toolbar status, post-workout effort ring) with actions to delete the workout, save as plan when no linked plan exists, and open linked plan when present.
- Called by: `ContentView` navigation destination for `.workoutSessionDetail`, SwiftUI preview.
- Calls: `formattedDateRange`, `WorkoutPlanView` (fullScreenCover), `RPEBadge`, `workoutEffortDescription`, `AppRouter.popToRoot`, `AppRouter.navigate(to: .workoutPlanDetail(...))`, `IntentDonations.donateOpenWorkoutPlan`, `IntentDonations.donateDeleteWorkout`, `userActivity` with `WorkoutSessionEntity`, `Haptics.selection`, `SpotlightIndexer.deleteWorkoutSession`, `ModelContext.delete/insert`, `ExerciseHistoryUpdater.updateHistory`, `saveContext`.

### `VillainArc/Views/Workout/WorkoutSessionContainer.swift`
- Does: Status-driven workout flow container that switches between suggestion review, active logging, and summary stages.
- Called by: `ContentView` fullScreenCover for `activeWorkoutSession`, SwiftUI previews.
- Calls: `DeferredSuggestionsView`, `WorkoutView`, `WorkoutSummaryView`.

### `VillainArc/Views/Workout/WorkoutView.swift`
- Does: Primary active-workout screen (exercise pager/list, add exercise, timer access, title/notes/pre-checkin sheets, finish/cancel actions). Keeps the original direct cancel button when the workout is empty and otherwise exposes the ellipsis menu, while also reacting to intent-driven router flags to open workout settings, rest timer, or pre-workout context.
- Called by: `WorkoutSessionContainer`, SwiftUI previews.
- Calls: `ExerciseView`, `AddExerciseView`, `RestTimerView`, `PreWorkoutContextView`, `TextEntryEditorView`, `WorkoutSettingsView`, `WorkoutSession.finish`, `WorkoutSession.ensurePreWorkoutFeelingDefault`, `AppRouter.shared` intent flags, `SpotlightIndexer.index(workoutSession:)`, `WorkoutActivityManager.start/update/end`, `IntentDonations` workout actions, `RestTimerState.shared.stop`, `saveContext`, `scheduleSave`, `Haptics.selection`.

### `VillainArc/Views/Workout/WorkoutSettingsView.swift`
- Does: Workout-scoped settings sheet for timer auto-start, auto-complete-after-RPE, rest timer notifications, live activity visibility, and manual live activity restart, backed by the singleton `AppSettings` model.
- Called by: `WorkoutView`, SwiftUI preview.
- Calls: `AppSettings.single` query, `SystemState.ensureAppSettings`, `WorkoutActivityManager.restart/end`, `RestTimerNotifications.schedule/cancel`, `saveContext`, `.navBar(title:)`, `CloseButton`.

### `VillainArc/Views/Workout/ExerciseView.swift`
- Does: Per-exercise workout page with set logging grid, notes, rep/rest editors, replace action, and set reference handling. Exercises still linked to a plan prescription show target references, including target RPE badges when present; exercises without a linked prescription use previous-performance references instead.
- Called by: `WorkoutView`, SwiftUI preview.
- Calls: `ExerciseSetRowView`, `RepRangeButton`, `RepRangeEditorView`, `RestTimeEditorView`, `ReplaceExerciseView`, `ExerciseHistoryView` (sheet), `WorkoutActivityManager.update`, `IntentDonations.donateReplaceExercise`, `saveContext`, `scheduleSave`, `Haptics.selection`, `secondsToTime`.

### `VillainArc/Views/Workout/PreWorkoutContextView.swift`
- Does: Sheet for recording pre-workout status (mood, pre-workout drink toggle, optional notes).
- Called by: `WorkoutView`, SwiftUI preview.
- Calls: `Haptics.selection`, `dismissKeyboard`, `saveContext`, `scheduleSave`, `dismiss` environment action.

### `VillainArc/Views/Workout/RestTimerView.swift`
- Does: Rest timer control screen with picker/start-pause-resume-stop, recent durations, and next-set completion shortcut. The timer auto-start preference is read from singleton `AppSettings`.
- Called by: `WorkoutView`, SwiftUI preview.
- Calls: `TimerDurationPicker`, `AppSettings.single` query, `RestTimerState.shared` (`start/pause/resume/stop/adjust`), `RestTimeHistory.record`, `WorkoutSession.activeExerciseAndSet`, `WorkoutActivityManager.update`, `IntentDonations` rest-timer actions, `saveContext`, `secondsToTime`, `Haptics.selection`.

### `VillainArc/Views/Workout/WorkoutSummaryView.swift`
- Does: Post-workout summary and finalization screen (stats, weight/volume/rep PR detection, effort rating, notes/title edits, suggestion review, save as plan). Freeform summaries also prewarm a generic Foundation Models session in case the workout is saved as a plan.
- Called by: `WorkoutSessionContainer`, SwiftUI previews.
- Calls: `formattedDateRange`, `TextEntryEditorView`, `FoundationModelPrewarmer`, `SuggestionReviewView`, `OutcomeResolver.resolveOutcomes`, `SuggestionGenerator.generateSuggestions`, `groupSuggestions`, `acceptGroup/rejectGroup/deferGroup`, `ExerciseHistoryUpdater.batchFetchHistories/updateHistoriesForCompletedWorkout`, `SpotlightIndexer.index(workoutPlan:)`, `IntentDonations.donateSaveWorkoutAsPlan`, `saveContext`, `scheduleSave`, `Haptics.selection`.

### `VillainArc/Views/Suggestions/DeferredSuggestionsView.swift`
- Does: Review step shown before workout logging for pending/deferred plan suggestions, with skip-all/accept-all actions.
- Called by: `WorkoutSessionContainer` (when session status is `.pending`), SwiftUI preview.
- Calls: `pendingSuggestions`, `groupSuggestions`, `SuggestionReviewView`, `acceptGroup`, `rejectGroup`, `applyChange`, `saveContext`, `Haptics.selection`.

### `VillainArc/Views/Suggestions/SuggestionReviewView.swift`
- Does: Shared grouped suggestion UI used in both deferred and summary review flows, including action rows and decision-state rendering.
- Called by: `DeferredSuggestionsView`, `WorkoutSummaryView`.
- Calls: action closures (`onAcceptGroup`, `onRejectGroup`, `onDeferGroup`), `Haptics.selection`; helper functions in file call `applyChange`, `saveContext`.

### `VillainArc/Views/Workout/AddExerciseView.swift`
- Does: Shared add-exercise modal that selects exercises and appends them to a `WorkoutSession` or `WorkoutPlan`.
- Called by: `WorkoutView`, `WorkoutPlanView`, SwiftUI preview.
- Calls: `FilteredExerciseListView`, `MuscleFilterSheetView`, `DataManager.dedupeCatalogExercisesIfNeeded`, `WorkoutSession.addExercise`, `WorkoutPlan.addExercise`, `Exercise.updateLastUsed`, `saveContext`, `IntentDonations.donateAddExercise/donateAddExercises`, `Haptics.selection`.

### `VillainArc/Views/Workout/FilteredExerciseListView.swift`
- Does: Reusable exercise list for search/filter/sort/select with favorite toggling and optional single-selection mode.
- Called by: `AddExerciseView`, `ReplaceExerciseView`, SwiftUI preview.
- Calls: `@Query(Exercise...)` with dynamic filter/sort, search helpers (`normalizedTokens`, `exerciseSearchMatches`, fuzzy matching), `Haptics.selection`, `IntentDonations.donateToggleExerciseFavorite`, `saveContext`, `AccessibilityIdentifiers`, `AccessibilityText`.

### `VillainArc/Views/Workout/ReplaceExerciseView.swift`
- Does: Sheet flow for replacing one workout exercise with another (single selection plus keep/clear sets confirmation).
- Called by: `ExerciseView`, SwiftUI preview.
- Calls: `FilteredExerciseListView`, `MuscleFilterSheetView`, provided `onReplace` callback, `Haptics.selection`, `dismiss` environment action.

### `VillainArc/Views/Workout/Editors/MuscleFilterSheetView.swift`
- Does: Reusable sheet for selecting major/minor muscle filters and returning the chosen set through `onConfirm`.
- Called by: `AddExerciseView`, `ReplaceExerciseView`, `WorkoutSplitDayView`, SwiftUI previews.
- Calls: `Haptics.selection`, `AccessibilityIdentifiers.muscleFilterChip`, provided `onConfirm` callback, `dismiss` environment action.

### `VillainArc/Views/Workout/Editors/RepRangeEditorView.swift`
- Does: Editor for an exercise's rep-range policy (`notSet` / `target` / `range`) with suggestion from recent history.
- Called by: `WorkoutPlanView` (`WorkoutPlanExerciseView`), `ExerciseView`, SwiftUI preview.
- Calls: `RepRangeMode`/`RepRangePolicy` mutations, history fetch via `ExercisePerformance.matching/completedAll`, `Haptics.selection`, `saveContext`, `scheduleSave`, `.navBar(title:)`, `CloseButton`.

### `VillainArc/Views/Workout/Editors/RestTimeEditorView.swift`
- Does: Generic rest-time editor for exercises with mode-specific rest controls, copy/paste seconds, and per-row picker expansion.
- Called by: `WorkoutPlanView` (`WorkoutPlanExerciseView`), `ExerciseView`, SwiftUI preview.
- Calls: `TimerDurationPicker`, `secondsToTime`, `Haptics.selection`, `saveContext`, `scheduleSave`, `.navBar(title:)`, `CloseButton`.

### `VillainArc/Views/HomeSections/RecentWorkoutPlanSectionView.swift`
- Does: Home "Workout Plans" section; shows empty state or latest plan card and provides quick navigation to the full plans list.
- Called by: `ContentView`, SwiftUI preview.
- Calls: `@Query(WorkoutPlan.recent)`, `HomeSectionHeaderButton`, `AppRouter.navigate(to: .workoutPlansList)`, `WorkoutPlanRowView`, `IntentDonations.donateShowWorkoutPlans`.

### `VillainArc/Views/Components/WorkoutPlanRowView.swift`
- Does: Clickable row wrapper for one plan card; handles navigation to plan detail.
- Called by: `RecentWorkoutPlanSectionView`, `WorkoutPlansListView`, `WorkoutSplitView`, SwiftUI preview.
- Calls: `AppRouter.navigate(to: .workoutPlanDetail(...))`, `WorkoutPlanCardView`, `IntentDonations.donateOpenWorkoutPlan`.

### `VillainArc/Views/Components/WorkoutPlanCardView.swift`
- Does: Pure display card for workout plan summary (favorite star, title, muscles targeted, exercise/set breakdown).
- Called by: `WorkoutPlanRowView`, `WorkoutPlanPickerView`, `WorkoutSplitDayView`, SwiftUI preview.
- Calls: `WorkoutPlan.musclesTargeted()`, `WorkoutPlan.sortedExercises`, `AccessibilityText.workoutPlanRowHint`.

### `VillainArc/Views/WorkoutPlan/WorkoutPlansListView.swift`
- Does: Full workout plans list screen with favorite filtering, swipe favorite toggle, and edit/delete-all workflows.
- Called by: `ContentView` navigation destination for `.workoutPlansList`, SwiftUI preview.
- Calls: `@Query(WorkoutPlan.all)`, `WorkoutPlanRowView`, `Haptics.selection`, `saveContext`, `SpotlightIndexer.deleteWorkoutPlans`, `ModelContext.delete`, `IntentDonations.donateToggleWorkoutPlanFavorite`, `IntentDonations.donateDeleteWorkoutPlan`, `IntentDonations.donateDeleteAllWorkoutPlans`.

### `VillainArc/Views/WorkoutPlan/WorkoutPlanDetailView.swift`
- Does: Detailed view for a single workout plan with actions to select/start/edit/delete and favorite the plan. Set rows show target reps/weight/rest plus optional target RPE badges.
- Called by: `ContentView` navigation destination for `.workoutPlanDetail`, `WorkoutPlanPickerView`, SwiftUI preview.
- Calls: `WorkoutPlan.musclesTargeted()`, `plan.createEditingCopy(context:)`, `WorkoutPlanView` (fullScreenCover), `@Query` over `WorkoutSplit`, `AppRouter.startWorkoutSession(from:)`, `IntentDonations.donateStartWorkoutWithPlan`, `IntentDonations.donateStartTodaysWorkout` (when the started plan matches active split's current day), `IntentDonations.donateToggleWorkoutPlanFavorite`, `IntentDonations.donateDeleteWorkoutPlan`, `userActivity` with `WorkoutPlanEntity`, `Haptics.selection`, `SpotlightIndexer.deleteWorkoutPlan`, `ModelContext.delete`, `saveContext`.

### `VillainArc/Views/WorkoutPlan/WorkoutPlanView.swift`
- Does: Full-screen editor for creating or editing a workout plan, including exercise list editing, set editing, optional target RPE per non-warmup set, notes/title editing, and save/cancel logic.
- Called by: `ContentView` (`activeWorkoutPlan` fullScreenCover), `WorkoutPlanDetailView` (editing copy flow), `WorkoutPlanPickerView` (new plan flow), `WorkoutDetailView` (save workout as plan), SwiftUI preview.
- Calls: `AddExerciseView`, `TextEntryEditorView`, `WorkoutPlan.finishEditing`, `WorkoutPlan.cancelEditing`, `WorkoutPlan.deletePlanEntirely`, `WorkoutPlan.deleteExercise`, `WorkoutPlan.moveExercise`, `ExerciseHistoryView` (via `WorkoutPlanExerciseView` sheet), `RPEBadge`, `RPEValue`, `SpotlightIndexer.index(workoutPlan:)`, `saveContext`, `scheduleSave`, `dismissKeyboard`, nested editors (`RepRangeEditorView`, `RestTimeEditorView`), `WorkoutPlanEntity` via `userActivity`.

### `VillainArc/Views/WorkoutPlan/WorkoutPlanPickerView.swift`
- Does: Plan selection screen for assigning/clearing a selected plan, with ability to create a new plan inline.
- Called by: `WorkoutSplitView` (`SplitDayPlanPickerSheet`), `WorkoutSplitDayView`, SwiftUI preview.
- Calls: `@Query(WorkoutPlan.all)`, `WorkoutPlanDetailView` (with select callback), `WorkoutPlanCardView`, `WorkoutPlanView` (new plan fullScreenCover), `ModelContext.insert/fetch`, `saveContext`, `IntentDonations.donateCreateWorkoutPlan`, `Haptics.selection`.

### `VillainArc/Views/WorkoutSplit/WorkoutSplitView.swift`
- Does: Main split editor screen for the active split (or an override split). Shows day-paging TabView with capsule headers, options menu (rename, schedule adjustments, swap/rotate days, delete), and "Create New Split" bottom bar. When routed with `autoPresentBuilder`, it presents the split builder on first appearance. Also shows empty-state views when no splits or no active split exist, and publishes the current split as `com.villainarc.workoutSplit.view`.
- Called by: `ContentView` navigation destination for `.workoutSplit`, `WorkoutSplitListView` (navigation destination for inactive split tap), SwiftUI preview.
- Calls: `@Query` over `WorkoutSplit`, `WorkoutSplitDayView`, `WorkoutSplitListView` (sheet), `SplitBuilderView` (sheet), `TextEntryEditorView`, `WorkoutSplitEntity`, `IntentDonations.donateTrainingSummary`, `IntentDonations.donateCreateWorkoutSplit`, `Haptics.selection`, `saveContext`, `scheduleSave`, split model operations (`refreshRotationIfNeeded`, `missedDay`, `resetSplit`, `updateCurrentIndex`, `deleteDay`), internal swap/rotation helpers.

### `VillainArc/Views/WorkoutSplit/WorkoutSplitListView.swift`
- Does: Sheet presenting all splits (active + inactive sections). Active split tap dismisses the sheet; inactive split tap navigates into `WorkoutSplitView` within the sheet's own `NavigationStack`. Hosts "Create New Split" bottom bar via `SplitBuilderView`.
- Called by: `WorkoutSplitView` (sheet), SwiftUI preview.
- Calls: `@Query` over `WorkoutSplit`, `WorkoutSplitView` (navigation destination), `SplitBuilderView` (sheet), `Haptics.selection`, `saveContext`, split model operations (`isActive`, `rotationCurrentIndex`, `rotationLastUpdatedDate`).

### `VillainArc/Views/HomeSections/WorkoutSplitSectionView.swift`
- Does: Home split summary section that shows active/today state and routes users into split screens.
- Called by: `ContentView`, SwiftUI preview.
- Calls: `@Query` over `WorkoutSplit`, `SmallUnavailableView`, `AppRouter.navigate(to: .workoutSplit/.workoutPlanDetail)`, `IntentDonations.donateOpenWorkoutSplit`, `IntentDonations.donateCreateWorkoutSplit`, `IntentDonations.donateManageWorkoutSplits`, `IntentDonations.donateOpenTodaysPlan`, `WorkoutSplit.refreshRotationIfNeeded`.

### `VillainArc/Views/WorkoutSplit/SplitBuilderView.swift`
- Does: Multi-step split builder for preset-based or scratch split creation (type, schedule mode, training days, rest style).
- Called by: `WorkoutSplitView` (create split sheet), `WorkoutSplitListView` (create split sheet), SwiftUI preview.
- Calls: `onSplitCreated: (WorkoutSplit) -> Void` callback on completion, `ModelContext.fetch/insert`, `saveContext`, `Haptics.selection`, split/day model creation (`WorkoutSplit`, `WorkoutSplitDay`), internal generator/config types (`SplitBuilderConfig`, `SplitGenerator`).

### `VillainArc/Views/WorkoutSplit/WorkoutSplitDayView.swift`
- Does: Per-day editor used inside split editing flow; controls rest-day state, day name, assigned plan, and target muscles.
- Called by: `WorkoutSplitView` (tab pages), SwiftUI preview.
- Calls: `WorkoutPlanCardView`, `WorkoutPlanPickerView`, `MuscleFilterSheetView`, `saveContext`, `scheduleSave`, `Haptics.selection`.

### `VillainArc/Views/Components/Navbar.swift`
- Does: Shared safe-area navbar utilities (`InlineLargeTitle`, `CloseButton`, `SheetTitleBar`) and `View.navBar(...)` modifiers.
- Called by: `ContentView`, `TextEntryEditorView`, `RestTimeEditorView`, `RepRangeEditorView`.
- Calls: `Haptics.selection` (inside `CloseButton`) and `dismiss` environment action.

### `VillainArc/Views/Components/TimerDurationPicker.swift`
- Does: Drag-based duration picker (15-second ticks) used to choose rest/timer seconds with haptic stepping.
- Called by: `RestTimeEditorView`, `RestTimerView`, SwiftUI demo preview.
- Calls: `secondsToTime`, `Haptics.selection`.

### `VillainArc/Helpers/Accessibility.swift`
- Does: Central accessibility constants and helper builders (`AccessibilityIdentifiers`, `AccessibilityText`) for labels/values/hints/IDs across home/workout/plan/split UI.
- Called by: Most view files under `VillainArc/Views/*`.
- Calls: Internal string helpers (`slug(...)`) and typed ID/value builders using app domain entities.

### `VillainArc/Helpers/Haptics.swift`
- Does: Main-actor haptic wrapper with cached impact generators and selection/notification APIs.
- Called by: `AppRouter` and many interactive views across workout/plan/split flows.
- Calls: `UIImpactFeedbackGenerator`, `UISelectionFeedbackGenerator`, `UINotificationFeedbackGenerator`.

### `VillainArc/Helpers/TimeFormatting.swift`
- Does: Shared time/date formatting helpers (`secondsToTime`, `formattedDateRange`).
- Called by: `WorkoutDetailView`, `WorkoutSummaryView`, `RestTimerView`, `WorkoutView`, `ExerciseView`, `RestTimeEditorView`, `TimerDurationPicker`, `ExerciseSetRowView`, rest timer intents/snippet.
- Calls: `Calendar` and `Date.formatted` utilities for normalized date/time range rendering.

### `VillainArc/Helpers/WorkoutEffortFormatting.swift`
- Does: Shared effort-level description helper that maps numeric workout effort ratings (1-10) to localized display strings.
- Called by: `WorkoutSummaryView`, `WorkoutDetailView`.
- Calls: None (formatting helper only).

### `VillainArc/Data/Services/ExerciseHistoryUpdater.swift`
- Does: Rebuild/create/delete `ExerciseHistory` records from completed exercise performances after workout completion/deletion, including cached totals and progression-chart data.
- Called by: `WorkoutsListView`, `WorkoutDetailView`, `WorkoutSummaryView`.
- Calls: `ModelContext.fetch/insert/delete`, `ExercisePerformance.matching(...)`, `ExerciseHistory.forCatalogID(...)`, `ExerciseHistory.recalculate(using:)`, `saveContext`.

## 3) Intents

### Intent Inventory
- App Intents (Workout): `StartWorkoutIntent`, `OpenActiveWorkoutIntent`, `OpenPreWorkoutContextIntent`, `OpenRestTimerIntent`, `OpenWorkoutSettingsIntent`, `LastWorkoutSummaryIntent`, `FinishWorkoutIntent`, `CompleteActiveSetIntent`, `CancelWorkoutIntent`, `ViewLastWorkoutIntent`, `ShowWorkoutHistoryIntent`, `OpenWorkoutIntent`, `SaveWorkoutAsPlanIntent`, `DeleteWorkoutIntent`, `DeleteAllWorkoutsIntent`.
- App Intents (Workout Split): `StartTodaysWorkoutIntent`, `TrainingSummaryIntent`, `OpenWorkoutSplitIntent`, `CreateWorkoutSplitIntent`, `ManageWorkoutSplitsIntent`, `OpenTodaysPlanIntent`.
- App Intents (Workout Plan): `CreateWorkoutPlanIntent`, `StartWorkoutWithPlanIntent`, `OpenWorkoutPlanIntent`, `ShowWorkoutPlansIntent`, `DeleteWorkoutPlanIntent`, `DeleteAllWorkoutPlansIntent`, `ToggleWorkoutPlanFavoriteIntent`.
- App Intents (Exercise): `AddExerciseIntent`, `AddExercisesIntent`, `OpenExerciseIntent`, `OpenExercisesIntent`, `ReplaceExerciseIntent`, `ToggleExerciseFavoriteIntent`.
- App Intents (Rest Timer): `StartRestTimerIntent`, `PauseRestTimerIntent`, `ResumeRestTimerIntent`, `StopRestTimerIntent`, `RestTimerControlIntent`.
- App Intent (App shell): `OpenAppIntent`.
- Live Activity Intents: `LiveActivityAddExerciseIntent`, `LiveActivityCompleteSetIntent`, `LiveActivityPauseRestTimerIntent`, `LiveActivityResumeRestTimerIntent`.
- Snippet Intent: `RestTimerSnippetIntent`.
- Intent entities/queries: `WorkoutSessionEntity` + `WorkoutSessionEntityQuery`, `WorkoutPlanEntity` + `WorkoutPlanEntityQuery`, `ExerciseEntity` + `ExerciseEntityQuery`, `WorkoutSplitEntity` + `WorkoutSplitEntityQuery`.

### Shortcut Registration
- `VillainArc/Intents/VillainArcShortcuts.swift` currently registers: `StartWorkoutIntent`, `StartWorkoutWithPlanIntent`, `StartTodaysWorkoutIntent`, `TrainingSummaryIntent`, `LastWorkoutSummaryIntent`, `FinishWorkoutIntent`, `CompleteActiveSetIntent`, `AddExerciseIntent`, `StartRestTimerIntent`, `StopRestTimerIntent`.
- `OpenExerciseIntent` exists and is donated, but its explicit `AppShortcut` block is currently commented out to stay within the 10-shortcut cap.

### Donation Map (`IntentDonations`)
- `StartWorkoutIntent`: donated via `donateStartWorkout`; called from `VillainArc/Views/ContentView.swift`.
- `OpenWorkoutSplitIntent`: donated via `donateOpenWorkoutSplit`; called from `VillainArc/Views/HomeSections/WorkoutSplitSectionView.swift`.
- `CreateWorkoutSplitIntent`: donated via `donateCreateWorkoutSplit`; called from `VillainArc/Views/HomeSections/WorkoutSplitSectionView.swift`, `VillainArc/Views/WorkoutSplit/WorkoutSplitView.swift`.
- `ManageWorkoutSplitsIntent`: donated via `donateManageWorkoutSplits`; called from `VillainArc/Views/HomeSections/WorkoutSplitSectionView.swift`.
- `OpenTodaysPlanIntent`: donated via `donateOpenTodaysPlan`; called from `VillainArc/Views/HomeSections/WorkoutSplitSectionView.swift`.
- `StartTodaysWorkoutIntent`: donated via `donateStartTodaysWorkout`; called from `VillainArc/Views/WorkoutPlan/WorkoutPlanDetailView.swift` (when starting the active split's current-day plan).
- `ViewLastWorkoutIntent`: donated via `donateViewLastWorkout`; called from `VillainArc/Views/HomeSections/RecentWorkoutSectionView.swift`.
- `OpenWorkoutIntent`: donated via `donateOpenWorkout`; called from `VillainArc/Views/Components/WorkoutRowView.swift`.
- `SaveWorkoutAsPlanIntent`: donated via `donateSaveWorkoutAsPlan`; called from `VillainArc/Views/Workout/WorkoutSummaryView.swift`.
- `DeleteWorkoutIntent`: donated via `donateDeleteWorkout`; called from `VillainArc/Views/Workout/WorkoutDetailView.swift`, `VillainArc/Views/History/WorkoutsListView.swift` (single-delete path).
- `DeleteAllWorkoutsIntent`: donated via `donateDeleteAllWorkouts`; called from `VillainArc/Views/History/WorkoutsListView.swift`.
- `ShowWorkoutHistoryIntent`: donated via `donateShowWorkoutHistory`; called from `VillainArc/Views/HomeSections/RecentWorkoutSectionView.swift`.
- `ShowWorkoutPlansIntent`: donated via `donateShowWorkoutPlans`; called from `VillainArc/Views/HomeSections/RecentWorkoutPlanSectionView.swift`.
- `OpenWorkoutPlanIntent`: donated via `donateOpenWorkoutPlan`; called from `VillainArc/Views/Components/WorkoutPlanRowView.swift`, `VillainArc/Views/Workout/WorkoutDetailView.swift`.
- `DeleteWorkoutPlanIntent`: donated via `donateDeleteWorkoutPlan`; called from `VillainArc/Views/WorkoutPlan/WorkoutPlanDetailView.swift`, `VillainArc/Views/WorkoutPlan/WorkoutPlansListView.swift` (single-delete path).
- `DeleteAllWorkoutPlansIntent`: donated via `donateDeleteAllWorkoutPlans`; called from `VillainArc/Views/WorkoutPlan/WorkoutPlansListView.swift`.
- `ToggleWorkoutPlanFavoriteIntent`: donated via `donateToggleWorkoutPlanFavorite`; called from `VillainArc/Views/WorkoutPlan/WorkoutPlanDetailView.swift`, `VillainArc/Views/WorkoutPlan/WorkoutPlansListView.swift`.
- `LastWorkoutSummaryIntent`: donated via `donateLastWorkoutSummary`; called from `VillainArc/Views/Workout/WorkoutView.swift`.
- `TrainingSummaryIntent`: donated via `donateTrainingSummary`; called from `VillainArc/Views/WorkoutSplit/WorkoutSplitView.swift`.
- `CreateWorkoutPlanIntent`: donated via `donateCreateWorkoutPlan`; called from `VillainArc/Views/ContentView.swift`, `VillainArc/Views/WorkoutPlan/WorkoutPlanPickerView.swift`.
- `StartWorkoutWithPlanIntent`: donated via `donateStartWorkoutWithPlan`; called from `VillainArc/Views/WorkoutPlan/WorkoutPlanDetailView.swift`, `VillainArc/Intents/WorkoutSplit/StartTodaysWorkoutIntent.swift`.
- `AddExerciseIntent`: donated via `donateAddExercise`; called from `VillainArc/Views/Workout/AddExerciseView.swift`.
- `AddExercisesIntent`: donated via `donateAddExercises`; called from `VillainArc/Views/Workout/AddExerciseView.swift`.
- `OpenExerciseIntent`: donated via `donateOpenExercise`; called from `VillainArc/Views/Components/ExerciseSummaryRow.swift`.
- `OpenExercisesIntent`: donated via `donateOpenExercises`; called from `VillainArc/Views/HomeSections/RecentExercisesSectionView.swift`.
- `ReplaceExerciseIntent`: donated via `donateReplaceExercise`; called from `VillainArc/Views/Workout/ExerciseView.swift`.
- `ToggleExerciseFavoriteIntent`: donated via `donateToggleExerciseFavorite`; called from `VillainArc/Views/Workout/FilteredExerciseListView.swift`.
- `OpenWorkoutSettingsIntent`: donated via `donateOpenWorkoutSettings`; called from `VillainArc/Views/Workout/WorkoutView.swift`.
- `OpenRestTimerIntent`: donated via `donateOpenRestTimer`; called from `VillainArc/Views/Workout/WorkoutView.swift`.
- `OpenPreWorkoutContextIntent`: donated via `donateOpenPreWorkoutContext`; called from `VillainArc/Views/Workout/WorkoutView.swift`.
- `StartRestTimerIntent`: donated via `donateStartRestTimer`; called from `VillainArc/Views/Workout/RestTimerView.swift`, `VillainArc/Views/Components/ExerciseSetRowView.swift`, `VillainArc/Intents/Workout/CompleteActiveSetIntent.swift`.
- `PauseRestTimerIntent`: donated via `donatePauseRestTimer`; called from `VillainArc/Views/Workout/RestTimerView.swift`.
- `ResumeRestTimerIntent`: donated via `donateResumeRestTimer`; called from `VillainArc/Views/Workout/RestTimerView.swift`.
- `StopRestTimerIntent`: donated via `donateStopRestTimer`; called from `VillainArc/Views/Workout/RestTimerView.swift`.
- `FinishWorkoutIntent`: donated via `donateFinishWorkout`; called from `VillainArc/Views/Workout/WorkoutView.swift`.
- `CancelWorkoutIntent`: donated via `donateCancelWorkout`; called from `VillainArc/Views/Workout/WorkoutView.swift`.
- `CompleteActiveSetIntent`: donated via `donateCompleteActiveSet`; called from `VillainArc/Views/Workout/RestTimerView.swift`, `VillainArc/Views/Components/ExerciseSetRowView.swift`.

### Non-Donation Intent Paths
- `OpenAppIntent`: used as `opensIntent` return target from multiple foreground intents; not donated.
- `OpenActiveWorkoutIntent`: foreground deep link into the current active workout; currently not donated through `IntentDonations`.
- `RestTimerControlIntent`: invoked from `RestTimerSnippetView` button intents; not donated.
- `RestTimerSnippetIntent`: returned by rest timer intents and reloaded by `RestTimerControlIntent`; not donated.
- Live activity intents (`LiveActivity*`): invoked by live activity controls; not donated through `IntentDonations`.

## 4) Data Models

### Model Relationship Map
- `Exercise` is the canonical exercise catalog record used to create `ExercisePerformance` and `ExercisePrescription` rows.
- `WorkoutSession` owns one `PreWorkoutContext` and many `ExercisePerformance` rows.
- `ExercisePerformance` owns many `SetPerformance` rows, and can point back to its originating `ExercisePrescription`.
- `SetPerformance` can point back to its originating `SetPrescription`.
- `WorkoutPlan` owns many `ExercisePrescription` rows.
- `ExercisePrescription` owns many `SetPrescription` rows.
- `WorkoutSplit` owns many `WorkoutSplitDay` rows.
- `WorkoutSplitDay` may reference one assigned `WorkoutPlan` (or be a rest day).
- `PrescriptionChange` links source evidence (`sessionFrom`/`sourceExercisePerformance`/`sourceSetPerformance`) to targets (`targetPlan`/`targetExercisePrescription`/`targetSetPrescription`) and lifecycle state (`decision`, `outcome`).
- `ExerciseHistory` stores aggregate stats per `catalogID` and owns `ProgressionPoint` rows.
- `RestTimeHistory` stores reusable recent rest durations.
- `SharedModelContainer.schema` persists: `WorkoutSession`, `PreWorkoutContext`, `ExercisePerformance`, `SetPerformance`, `Exercise`, `AppSettings`, `ExerciseHistory`, `ProgressionPoint`, `RepRangePolicy`, `RestTimeHistory`, `WorkoutPlan`, `ExercisePrescription`, `SetPrescription`, `WorkoutSplit`, `WorkoutSplitDay`, `PrescriptionChange`, `UserProfile`.

### Data Model File Index

### `VillainArc/Data/Models/Exercise/Exercise.swift`
- Does: Persisted exercise catalog row (name/muscles/equipment/favorite/last-used) plus normalized search metadata, shared exercise subtitle formatting, and system alternate names for Spotlight/App Intents.
- Called by: `DataManager` seeding/dedupe, exercise picker/add/replace flows, session/plan model constructors.
- Calls: Search-token helpers (`exerciseSearchTokens`, `normalizedTokens`), fetch descriptors (`all`, `catalogExercises`).

### `VillainArc/Data/Models/Exercise/ExerciseCatalog.swift`
- Does: Static built-in exercise dataset (`all`) + lookup map (`byID`) + seed version (`catalogVersion`).
- Called by: `DataManager.seedExercisesIfNeeded`, `DataManager.dedupeCatalogExercisesIfNeeded`, `SampleData`.
- Calls: None (constant catalog data).

### `VillainArc/Data/Models/Exercise/RepRangePolicy.swift`
- Does: Reusable rep target/range policy object shared by performance and prescription models.
- Called by: `ExercisePerformance`, `ExercisePrescription`, `RepRangeEditorView`, suggestion engines.
- Calls: None (data and display text only).

### `VillainArc/Data/Models/Exercise/RestTimeDefaults.swift`
- Does: Default rest time constants/helpers for exercise types and equipment.
- Called by: `ExercisePerformance`, `ExercisePrescription`, rest time editor flows.
- Calls: None (constants only).

### `VillainArc/Data/Models/Exercise/ExerciseHistory.swift`
- Does: Derived per-exercise analytics cache (PRs, latest estimated 1RM, total sets/reps, cumulative volume, and progression points with reps).
- Called by: `ExerciseHistoryUpdater`, `WorkoutSummaryView` (history/PR display), schema registration.
- Calls: `ExercisePerformance` metric helpers, internal recalculation helpers, `forCatalogID` descriptor.

### `VillainArc/Data/Models/Exercise/ProgressionPoint.swift`
- Does: One timeseries point (date/weight/total reps/volume/estimated 1RM) for `ExerciseHistory` charts.
- Called by: `ExerciseHistory.recalculate`, schema registration.
- Calls: None.

### `VillainArc/Data/Models/Sessions/PreWorkoutContext.swift`
- Does: Session pre-checkin state (mood, pre-workout toggle, notes).
- Called by: `WorkoutSession.preWorkoutContext`, `PreWorkoutContextView`, schema registration.
- Calls: None.

### `VillainArc/Data/Models/Sessions/WorkoutSession.swift`
- Does: Root workout runtime/completion aggregate (status, provenance origin, plan link, exercises, finish workflow helpers). Finish flow resolves incomplete sets before summary and prunes empty exercises or the workout itself when needed.
- Called by: `AppRouter`, workout views, workout intents/entities, `SampleData`.
- Calls: `ExercisePerformance` constructors, session fetch descriptors, finish/prune helpers.

### `VillainArc/Data/Models/Sessions/ExercisePerformance.swift`
- Does: Per-exercise workout log entry with set rows and optional back-reference to originating plan prescription. Initializes with at least one set, stamps new performances with the parent workout's `startedAt`, restores a tail `SetPrescription` link when re-adding a deleted set in a plan session (only when no remaining set links to a higher-index prescription), can refresh copied catalog metadata (`name`/`musclesTargeted`/`equipmentType`) during catalog sync, and exposes best-weight/best-rep/volume helpers used by history and PR surfaces.
- Called by: `WorkoutView`, `ExerciseView`, suggestion engines, history updater, `SampleData`.
- Calls: `SetPerformance` constructors, rest helper (`effectiveRestSeconds`), descriptors (`lastCompleted`, `matching`, `withCatalogID`, `completedAll`).

### `VillainArc/Data/Models/Sessions/SetPerformance.swift`
- Does: Per-set logged data (type, weight, reps, rest, actual RPE, completion metadata). Does not inherit target RPE from plan prescriptions when plan-based workouts start.
- Called by: `ExerciseSetRowView`, `ExerciseView`, suggestion engines/outcome rules, `SampleData`.
- Calls: Computed helpers (`effectiveRestSeconds`, `estimated1RM`, `volume`).

### `VillainArc/Data/Models/RestTimeHistory.swift`
- Does: Recent rest durations cache for rest-timer quick picks.
- Called by: `RestTimerView`, `ExerciseSetRowView`, rest timer intents (`StartRestTimerIntent`, `CompleteActiveSetIntent`).
- Calls: `record(seconds:context:)` with `ModelContext.fetch/insert`.

### `VillainArc/Data/Models/AppSettings.swift`
- Does: Singleton app-settings model storing workout logging, rest timer, notification, and live-activity preferences with default values.
- Called by: `SystemState`, `WorkoutSettingsView`, workout/live-activity helpers and intents via fetches.
- Calls: `AppSettings.single` fetch descriptor helper.

### `VillainArc/Data/Models/UserProfile.swift`
- Does: User account data (name, birthday, height) collected during onboarding. Provides `isComplete` and `firstMissingStep` for onboarding flow.
- Called by: `OnboardingManager`, `OnboardingView`, schema registration.
- Calls: None (data model only).

### `VillainArc/Data/Models/Plans/WorkoutPlan.swift`
- Does: Root workout-plan aggregate (metadata, provenance origin, exercises, split-day links, create-from-session path).
- Called by: plan views/picker/detail flows, split assignment flows, plan intents, `AppRouter`, `SampleData`.
- Calls: `ExercisePrescription` constructors, exercise reorder/reindex helpers, fetch descriptors (`all`, `recent`, `incomplete`).

### `VillainArc/Data/Models/Plans/WorkoutPlan+Editing.swift`
- Does: Editing-copy workflow (`createEditingCopy`, `finishEditing`, `cancelEditing`) + change detection/synchronization to original plan.
- Called by: `WorkoutPlanDetailView` (editing copy setup), `WorkoutPlanView` (save/cancel/delete flows).
- Calls: `PrescriptionChange` creation, pending-change override marking, set/exercise sync helpers, `SpotlightIndexer.deleteWorkoutPlan` (delete-entirely path).

### `VillainArc/Data/Models/Plans/ExercisePrescription.swift`
- Does: Per-exercise plan prescription (rep/rest policy, notes, set targets, pending changes). Initializes with at least one set for new plan exercises and can refresh copied catalog metadata (`name`/`musclesTargeted`/`equipmentType`) during catalog sync.
- Called by: `WorkoutPlan`, `WorkoutSession` plan-start path, plan editors, suggestion engines.
- Calls: `SetPrescription` constructors/copy helpers, policy copy constructors, `matching(catalogID:)`.

### `VillainArc/Data/Models/Plans/SetPrescription.swift`
- Does: Per-set target prescription (type/target weight/reps/rest/target RPE) with change links. Target RPE is hidden for warmup sets and is copied from logged RPE when creating a plan from a finished workout.
- Called by: `ExercisePrescription`, plan editors, suggestion engines, performance conversion.
- Calls: Constructors from `SetPerformance`, copy helpers, `RestTimeEditableSet` adapter.

### `VillainArc/Data/Models/Plans/PrescriptionChange.swift`
- Does: Persisted suggestion/change lifecycle record from generation through decision and post-workout outcome.
- Called by: `RuleEngine`, `WorkoutPlan+Editing`, `SuggestionReviewView`, `DeferredSuggestionsView`, `WorkoutSummaryView`, `OutcomeResolver`.
- Calls: None (data model only).

### `VillainArc/Data/Models/Plans/SuggestionGrouping.swift`
- Does: Grouping/query helpers for rendering and resolving plan suggestions (`groupSuggestions`, `pendingSuggestions`). `pendingSuggestions` walks the plan's direct change relationships (`targetedChanges`, exercise changes, set changes) instead of issuing a separate SwiftData fetch.
- Called by: `DeferredSuggestionsView`, `WorkoutSummaryView`.
- Calls: In-memory grouping/sorting helpers plus plan relationship traversal.

### `VillainArc/Data/Models/WorkoutSplit/WorkoutSplit.swift`
- Does: Split schedule aggregate (weekly/rotation state, day resolution, current-day advancement logic).
- Called by: split views, `StartTodaysWorkoutIntent`, `TrainingSummaryIntent`, `OpenWorkoutSplitIntent`, `ManageWorkoutSplitsIntent`, `OpenTodaysPlanIntent`, `AppRouter` split routes, `SampleData`.
- Calls: day-resolution helpers (`dayIndex`, `splitDay`, `workoutPlan`), `saveContext` in rotation refresh.

### `VillainArc/Data/Models/WorkoutSplit/WorkoutSplitDay.swift`
- Does: One split day entry (name/index/weekday/rest flag/target muscles/assigned plan).
- Called by: split creation/detail/day views, split builder, plan picker assignment flows, `SampleData`.
- Calls: `resolvedMuscles` via `workoutPlan?.musclesArray`.

### `VillainArc/Data/Models/AIModels/AISuggestionModels.swift`
- Does: Foundation Models DTOs/enums for training-style classification prompts/results.
- Called by: `AITrainingStyleClassifier`, `RecentExercisePerformancesTool`.
- Calls: Mappers from `ExercisePerformance`/`SetPerformance`/`RepRangeMode`/`ExerciseSetType`.

### `VillainArc/Data/Models/AIModels/AIOutcomeModels.swift`
- Does: Foundation Models DTOs/enums for suggestion outcome evaluation prompts/results.
- Called by: `AIOutcomeInferrer`, `OutcomeResolver`.
- Calls: Mappers between app enums (`Outcome`) and AI enums, snapshot builders from prescription/set models.

### `VillainArc/Data/SampleData.swift`
- Does: In-memory preview fixture container for sessions, plans, splits, and suggestion scenarios.
- Called by: SwiftUI previews across workout/plan/split/suggestion flows.
- Calls: Core model constructors, `ExerciseCatalog.byID`, in-memory `ModelContainer` setup and seed helpers.

### Enums + Protocols (Model-Adjacent)
- `VillainArc/Data/Protocols/RestTimeEditable.swift`: protocol contracts for generic rest editor flows; conformed to by `ExercisePerformance`, `ExercisePrescription`, `SetPerformance`, `SetPrescription`.
- `VillainArc/Data/Models/Enums/Exercise/EquipmentType.swift`: equipment taxonomy used by `Exercise`, `ExercisePerformance`, `ExercisePrescription`, and catalog/search/filtering.
- `VillainArc/Data/Models/Enums/Exercise/ExerciseSetType.swift`: set taxonomy + display metadata used by set models, editors, and rule engines.
- `VillainArc/Data/Models/Enums/Exercise/Muscle.swift`: normalized muscle taxonomy with major/minor semantics used across exercise, plan, and split models.
- `VillainArc/Data/Models/Enums/Exercise/MuscleGroups.swift`: grouped muscle sets used by split/selection logic.
- `VillainArc/Data/Models/Enums/Exercise/RepRangeMode.swift`: rep-range mode enum used by `RepRangePolicy`.
- `VillainArc/Data/Models/Enums/Sessions/MoodLevel.swift`: pre-workout mood enum used by `PreWorkoutContext`.
- `VillainArc/Data/Models/Enums/Sessions/Origin.swift`: shared provenance enum (`user`/`plan`/`session`/`ai`) used by `WorkoutSession` and `WorkoutPlan`.
- `VillainArc/Data/Models/Enums/Sessions/SessionStatus.swift`: workout lifecycle enum (`pending`/`active`/`summary`/`done`) used by `WorkoutSession` and flow routing.
- `VillainArc/Data/Models/Enums/Suggestions/ChangeType.swift`: suggestion change taxonomy used by rules, review UI, and outcome logic.
- `VillainArc/Data/Models/Enums/Suggestions/Decision.swift`: user decision lifecycle for suggestions.
- `VillainArc/Data/Models/Enums/Suggestions/Outcome.swift`: post-workout suggestion outcome lifecycle.
- `VillainArc/Data/Models/Enums/Suggestions/SuggestionSource.swift`: suggestion provenance enum (`rules`/`ai`/`user`).
- `VillainArc/Data/Models/Enums/Suggestions/TrainingStyle.swift`: detected exercise pattern enum (`straightSets`/`ascending`/`descendingPyramid`/`ascendingPyramid`/`topSetBackoffs`/`unknown`) used by `MetricsCalculator`, `RuleEngine`, and AI classifiers.
- `VillainArc/Data/Models/Enums/SplitMode.swift`: split schedule mode enum (`weekly`/`rotation`) used by `WorkoutSplit`.

## 5) Runtime Support Files

### `VillainArc/Data/Services/RestTimerState.swift`
- Does: App-wide singleton rest timer state machine (run/pause/resume/stop/adjust) with persisted state and optional completion alert.
- Called by: `RestTimerView`, `ExerciseSetRowView`, `WorkoutView`, `AppRouter`, rest timer intents, live activity intents, and workout completion intents.
- Calls: `RestTimerNotifications.schedule/cancel`, `WorkoutActivityManager.update`, `UserDefaults` persistence, `AudioServicesPlayAlertSound`.

### `VillainArc/Data/LiveActivity/WorkoutActivityAttributes.swift`
- Does: ActivityKit attribute and content-state model for workout live activity UI.
- Called by: `WorkoutActivityManager`, `VillainArcWidgetExtension/VillainArcWidgetExtension.swift`.
- Calls: Internal state helpers (`isTimerRunning`, `isTimerPaused`, `hasActiveSet`).

### `VillainArc/Data/LiveActivity/WorkoutActivityManager.swift`
- Does: Live activity lifecycle manager (start/update/end/restore/restart) for active workouts, gated by singleton `AppSettings`.
- Called by: `WorkoutView`, `ExerciseSetRowView`, `RestTimerView`, `RestTimerState`, workout/live-activity intents, `AppRouter`.
- Calls: `Activity.request/update/end`, `AppSettings.single` fetch, `WorkoutActivityAttributes.ContentState` builder, `SharedModelContainer.container.mainContext`, `WorkoutSession.incomplete`.

### `VillainArc/Helpers/ExerciseSearch.swift`
- Does: Search scoring and tokenization helpers for exercise lookup (exact/prefix/phrase weighting).
- Called by: `FilteredExerciseListView`, `ExerciseEntityQuery`.
- Calls: `normalizedTokens`, `exerciseSearchTokens`, phrase/token scoring helpers.

### `VillainArc/Helpers/KeyboardDismiss.swift`
- Does: UIKit bridge helper to dismiss current keyboard focus from SwiftUI flows.
- Called by: `TextEntryEditorView`, `PreWorkoutContextView`, `WorkoutPlanView`, and other text-entry screens.
- Calls: `UIApplication.shared.sendAction(...resignFirstResponder...)`.

### `VillainArc/Helpers/RestTimerNotifications.swift`
- Does: Local notification scheduler/canceler for rest timer completion reminders, gated by singleton `AppSettings`.
- Called by: `RestTimerState`.
- Calls: `ModelContext(SharedModelContainer.container)`, `AppSettings.single` fetch, `UNUserNotificationCenter` auth/settings APIs, notification request creation.

### `VillainArc/Helpers/TextNormalization.swift`
- Does: Text normalization + fuzzy-match helpers (tokenization, max distance, Levenshtein distance).
- Called by: `ExerciseSearch` helpers and `ExerciseEntityQuery`.
- Calls: Internal string-distance/token utilities.

### `VillainArc/Helpers/CloudKitStatusChecker.swift`
- Does: Checks iCloud sign-in status and CloudKit container availability.
- Called by: `OnboardingManager`.
- Calls: `FileManager.default.ubiquityIdentityToken`, `CKContainer.default().accountStatus()`.

### `VillainArc/Helpers/NetworkMonitor.swift`
- Does: Continuous network connectivity monitoring via NWPathMonitor. Observable singleton exposing `isConnected`.
- Called by: `OnboardingManager`.
- Calls: `NWPathMonitor`, `NWPath.status`.

## 6) Intents File Index (Complete Paths)

### `VillainArc/Intents/IntentDonations.swift`
- Does: Centralized typed donation helpers for app-intent donation from UI/workflow events.
- Called by: `ContentView`, workout/plan/split views, `CompleteActiveSetIntent`, `StartTodaysWorkoutIntent`.
- Calls: `.donate()` on intent types with resolved entities/parameters.

### `VillainArc/Intents/OpenAppIntent.swift`
- Does: Foreground app open target intent used as `opensIntent` return value.
- Called by: Foreground intents (`Start*`, `Open*`, `FinishWorkoutIntent`, etc.).
- Calls: None (returns `.result()`).

### `VillainArc/Intents/Workout/StartWorkoutIntent.swift`
- Does: Starts empty workout after active-session/active-plan guards.
- Called by: Siri/Shortcuts (`VillainArcShortcuts`) and donation flow.
- Calls: `SharedModelContainer` fetch checks, `AppRouter.startWorkoutSession`, `OpenAppIntent`.

### `VillainArc/Intents/Workout/CompleteActiveSetIntent.swift`
- Does: Background intent that marks the current active set as complete, optionally starts rest timer, and prewarms the generic Foundation Models session when that set is the final incomplete set in a plan workout.
- Called by: Siri/Shortcuts (`VillainArcShortcuts`), donation flow, Live Activity.
- Calls: `WorkoutSession.incomplete`, `activeExerciseAndSet`, `WorkoutSession.isFinalIncompleteSet`, `RestTimerState.start`, `RestTimeHistory.record`, `FoundationModelPrewarmer`, `WorkoutActivityManager.update`, `IntentDonations.donateStartRestTimer`, `saveContext`.

### `VillainArc/Intents/Workout/CancelWorkoutIntent.swift`
- Does: Cancels/deletes current incomplete workout session.
- Called by: Siri/Shortcuts, donation flow.
- Calls: `WorkoutSession.incomplete`, `RestTimerState.stop`, `saveContext`, `WorkoutActivityManager.end`, `AppRouter.activeWorkoutSession`.

### `VillainArc/Intents/Workout/FinishWorkoutIntent.swift`
- Does: Guided finish workflow for incomplete sets with choice prompts and finish actions. Plan-backed finishes also prewarm the generic Foundation Models session before summary handoff.
- Called by: Siri/Shortcuts, donation flow.
- Calls: `WorkoutSession.finish`, `requestChoice`, `FoundationModelPrewarmer`, `RestTimerState.stop`, `SpotlightIndexer.index(workoutSession:)`, `WorkoutActivityManager.end`, `OpenAppIntent`.

### `VillainArc/Intents/Workout/LastWorkoutSummaryIntent.swift`
- Does: Background summary dialog for most recent completed workout.
- Called by: Siri/Shortcuts, donation flow.
- Calls: `WorkoutSession.recent` fetch + `exerciseSummary`.

### `VillainArc/Intents/Workout/OpenWorkoutIntent.swift`
- Does: Opens selected completed workout detail route after setup/bootstrap and no-active-flow checks.
- Called by: Siri/Shortcuts, donations (`donateOpenWorkout`).
- Calls: `SetupGuard.requireReadyAndNoActiveFlow`, `WorkoutSessionEntity` resolution fetch, `AppRouter.navigate(.workoutSessionDetail)`, `OpenAppIntent`.

### `VillainArc/Intents/Workout/OpenActiveWorkoutIntent.swift`
- Does: Foregrounds the app when an active workout exists so the normal resume flow can present it.
- Called by: direct App Intent execution.
- Calls: `WorkoutSession.incomplete`, `OpenAppIntent`.

### `VillainArc/Intents/Workout/OpenPreWorkoutContextIntent.swift`
- Does: Foregrounds the current active workout and flips the router flag that opens the pre-workout context sheet.
- Called by: Siri/Shortcuts/App Intent execution, donations (`donateOpenPreWorkoutContext`).
- Calls: `WorkoutSession.incomplete`, `AppRouter.shared.showPreWorkoutContextFromIntent`, `OpenAppIntent`.

### `VillainArc/Intents/Workout/OpenRestTimerIntent.swift`
- Does: Foregrounds the current active workout and flips the router flag that opens the rest timer sheet.
- Called by: Siri/Shortcuts/App Intent execution, donations (`donateOpenRestTimer`).
- Calls: `WorkoutSession.incomplete`, `AppRouter.shared.showRestTimerFromIntent`, `OpenAppIntent`.

### `VillainArc/Intents/Workout/OpenWorkoutSettingsIntent.swift`
- Does: Foregrounds the current active workout and flips the router flag that opens the workout settings sheet.
- Called by: Siri/Shortcuts/App Intent execution, donations (`donateOpenWorkoutSettings`).
- Calls: `WorkoutSession.incomplete`, `AppRouter.shared.showWorkoutSettingsFromIntent`, `OpenAppIntent`.

### `VillainArc/Intents/Workout/SaveWorkoutAsPlanIntent.swift`
- Does: Creates a completed workout plan from a completed workout, links it back to that workout, and opens the created plan.
- Called by: Siri/Shortcuts/App Intent execution, donations (`donateSaveWorkoutAsPlan`).
- Calls: `WorkoutSessionEntity` resolution fetch, guards for existing linked plan and completed status, `WorkoutPlan(from:completed:)`, `SpotlightIndexer.index(workoutPlan:)`, `AppRouter.popToRoot`, `AppRouter.navigate(.workoutPlanDetail)`, `OpenAppIntent`.

### `VillainArc/Intents/Workout/DeleteWorkoutIntent.swift`
- Does: Deletes one selected completed workout after explicit destructive confirmation.
- Called by: Siri/Shortcuts/App Intent execution, donations (`donateDeleteWorkout`).
- Calls: `WorkoutSessionEntity` resolution fetch, `requestChoice` confirmation, `SpotlightIndexer.deleteWorkoutSession`, `ExerciseHistoryUpdater.updateHistory`, `ModelContext.delete`, `saveContext`.

### `VillainArc/Intents/Workout/DeleteAllWorkoutsIntent.swift`
- Does: Deletes all completed workouts after explicit destructive confirmation.
- Called by: Siri/Shortcuts/App Intent execution, donations (`donateDeleteAllWorkouts`).
- Calls: `WorkoutSession.completedSession` fetch, `requestChoice` confirmation, `SpotlightIndexer.deleteWorkoutSessions`, `ExerciseHistoryUpdater.updateHistory`, `ModelContext.delete`, `saveContext`.

### `VillainArc/Intents/Workout/ShowWorkoutHistoryIntent.swift`
- Does: Opens workout history after setup/bootstrap, no-active-flow, and data-availability validation.
- Called by: Siri/Shortcuts, donations (`donateShowWorkoutHistory`).
- Calls: `SetupGuard.requireReadyAndNoActiveFlow`, `WorkoutSession.recent`, `AppRouter.popToRoot`, `AppRouter.navigate(.workoutSessionsList)`, `OpenAppIntent`.

### `VillainArc/Intents/Workout/ViewLastWorkoutIntent.swift`
- Does: Opens the most recent completed workout detail screen after setup/bootstrap and no-active-flow checks.
- Called by: Siri/Shortcuts, donations (`donateViewLastWorkout`).
- Calls: `SetupGuard.requireReadyAndNoActiveFlow`, `WorkoutSession.recent`, `AppRouter.popToRoot`, `AppRouter.navigate(.workoutSessionDetail)`, `OpenAppIntent`.

### `VillainArc/Intents/Workout/WorkoutSessionEntity.swift`
- Does: AppEntity + queries + transfer payload for workout sessions (used by Siri/Shortcuts/Spotlight).
- Called by: `OpenWorkoutIntent`, `SpotlightIndexer.associateAppEntity`, donation mapping, `userActivity` integration.
- Calls: `SharedModelContainer` queries, `WorkoutSession` mapping, JSON transfer encoding.

### `VillainArc/Intents/WorkoutSplit/StartTodaysWorkoutIntent.swift`
- Does: Starts today's workout from the active split after setup/bootstrap and active-flow guards.
- Called by: Siri/Shortcuts (`VillainArcShortcuts`) and donation flow.
- Calls: `SetupGuard.requireReady`, `WorkoutSplit.active`, `WorkoutSplit.refreshRotationIfNeeded`, `IntentDonations.donateStartWorkoutWithPlan`, `AppRouter.startWorkoutSession(from:)`, `OpenAppIntent`.

### `VillainArc/Intents/WorkoutSplit/TrainingSummaryIntent.swift`
- Does: Returns split-day training summary for requested day enum.
- Called by: Siri/Shortcuts, donations (`donateTrainingSummary`).
- Calls: `WorkoutSplit.active`, `WorkoutSplit.refreshRotationIfNeeded`, `splitDay(for:)`, plan/rest-day summary formatting.

### `VillainArc/Intents/WorkoutSplit/OpenWorkoutSplitIntent.swift`
- Does: Opens the active workout split after setup/bootstrap, no-active-flow, and active-split validation.
- Called by: Siri/Shortcuts, donations (`donateOpenWorkoutSplit`).
- Calls: `SetupGuard.requireReadyAndNoActiveFlow`, `WorkoutSplit.active`, `WorkoutSplit.refreshRotationIfNeeded`, `AppRouter.popToRoot`, `AppRouter.navigate(.workoutSplit)`, `OpenAppIntent`.

### `VillainArc/Intents/WorkoutSplit/CreateWorkoutSplitIntent.swift`
- Does: Opens the workout split screen and auto-presents the builder immediately after setup/bootstrap and no-active-flow checks.
- Called by: Siri/Shortcuts, donations (`donateCreateWorkoutSplit`).
- Calls: `SetupGuard.requireReadyAndNoActiveFlow`, `AppRouter.popToRoot`, `AppRouter.navigate(.workoutSplit(autoPresentBuilder: true))`, `OpenAppIntent`.

### `VillainArc/Intents/WorkoutSplit/ManageWorkoutSplitsIntent.swift`
- Does: Opens workout split management after setup/bootstrap, no-active-flow, and split-availability validation.
- Called by: Siri/Shortcuts, donations (`donateManageWorkoutSplits`).
- Calls: `SetupGuard.requireReadyAndNoActiveFlow`, `FetchDescriptor<WorkoutSplit>`, `WorkoutSplit.active`, `WorkoutSplit.refreshRotationIfNeeded`, `AppRouter.popToRoot`, `AppRouter.navigate(.workoutSplit)`, `OpenAppIntent`.

### `VillainArc/Intents/WorkoutSplit/OpenTodaysPlanIntent.swift`
- Does: Opens today's assigned split plan after setup/bootstrap, no-active-flow, rotation refresh, and plan-availability validation.
- Called by: Siri/Shortcuts, donations (`donateOpenTodaysPlan`).
- Calls: `SetupGuard.requireReadyAndNoActiveFlow`, `WorkoutSplit.active`, `WorkoutSplit.refreshRotationIfNeeded`, `AppRouter.popToRoot`, `AppRouter.navigate(.workoutPlanDetail)`, `OpenAppIntent`.

### `VillainArc/Intents/WorkoutSplit/WorkoutSplitEntity.swift`
- Does: Split AppEntity/IndexedEntity definition with JSON transfer support and nested day/plan reference payloads for user activity and future export/share flows.
- Called by: `WorkoutSplitView` and any future split-specific App Intents or transfer surfaces.
- Calls: `SharedModelContainer.container.mainContext`, `FetchDescriptor<WorkoutSplit>`, split/day/plan mapping helpers.

### `VillainArc/Intents/WorkoutPlan/CreateWorkoutPlanIntent.swift`
- Does: Opens create-plan flow with active-workout/plan guard checks.
- Called by: Siri/Shortcuts, donation flow.
- Calls: `WorkoutSession.incomplete`, `WorkoutPlan.incomplete`, `AppRouter.createWorkoutPlan`, `OpenAppIntent`.

### `VillainArc/Intents/WorkoutPlan/OpenWorkoutPlanIntent.swift`
- Does: Opens selected completed workout plan detail route after setup/bootstrap and no-active-flow checks.
- Called by: Siri/Shortcuts, donations (`donateOpenWorkoutPlan`).
- Calls: `SetupGuard.requireReadyAndNoActiveFlow`, `WorkoutPlanEntity` resolution fetch, `AppRouter.navigate(.workoutPlanDetail)`, `OpenAppIntent`.

### `VillainArc/Intents/WorkoutPlan/DeleteWorkoutPlanIntent.swift`
- Does: Deletes one selected completed workout plan after explicit destructive confirmation.
- Called by: Siri/Shortcuts/App Intent execution, donations (`donateDeleteWorkoutPlan`).
- Calls: `WorkoutPlanEntity` resolution fetch, `requestChoice` confirmation, `SpotlightIndexer.deleteWorkoutPlan`, `ModelContext.delete`, `saveContext`.

### `VillainArc/Intents/WorkoutPlan/DeleteAllWorkoutPlansIntent.swift`
- Does: Deletes all completed workout plans after explicit destructive confirmation.
- Called by: Siri/Shortcuts/App Intent execution, donations (`donateDeleteAllWorkoutPlans`).
- Calls: `WorkoutPlan.all` fetch, `requestChoice` confirmation, `SpotlightIndexer.deleteWorkoutPlans`, `ModelContext.delete`, `saveContext`.

### `VillainArc/Intents/WorkoutPlan/ToggleWorkoutPlanFavoriteIntent.swift`
- Does: Toggles favorite status on a selected completed workout plan.
- Called by: Siri/Shortcuts/App Intent execution, donations (`donateToggleWorkoutPlanFavorite`).
- Calls: `WorkoutPlanEntity` resolution fetch, `ModelContext` mutation, `saveContext`.

### `VillainArc/Intents/WorkoutPlan/ShowWorkoutPlansIntent.swift`
- Does: Opens workout plans after setup/bootstrap, no-active-flow, and data-availability validation.
- Called by: Siri/Shortcuts, donations (`donateShowWorkoutPlans`).
- Calls: `SetupGuard.requireReadyAndNoActiveFlow`, `WorkoutPlan.recent`, `AppRouter.popToRoot`, `AppRouter.navigate(.workoutPlansList)`, `OpenAppIntent`.

### `VillainArc/Intents/WorkoutPlan/StartWorkoutWithPlanIntent.swift`
- Does: Starts workout from selected completed plan.
- Called by: Siri/Shortcuts, donations (`donateStartWorkoutWithPlan`), split/day actions.
- Calls: `WorkoutPlanEntity` resolution fetch, `AppRouter.startWorkoutSession(from:)`, `OpenAppIntent`.

### `VillainArc/Intents/WorkoutPlan/WorkoutPlanEntity.swift`
- Does: AppEntity + queries + transfer payload for workout plans.
- Called by: `StartWorkoutWithPlanIntent`, `OpenWorkoutPlanIntent`, `SpotlightIndexer.associateAppEntity`, donations.
- Calls: `SharedModelContainer` queries, `WorkoutPlan` mapping, JSON transfer encoding.

### `VillainArc/Intents/Exercise/AddExerciseIntent.swift`
- Does: Adds one selected exercise to active workout or active editing plan.
- Called by: Siri/Shortcuts, donations (`donateAddExercise`).
- Calls: `DataManager.dedupeCatalogExercisesIfNeeded`, `WorkoutSession.addExercise`/`WorkoutPlan.addExercise`, `WorkoutActivityManager.update`.

### `VillainArc/Intents/Exercise/AddExercisesIntent.swift`
- Does: Adds multiple selected exercises to active workout or active editing plan, updating the workout live activity when applicable.
- Called by: Siri/Shortcuts, donations (`donateAddExercises`).
- Calls: Exercise resolution fetch, add/update/save helpers.

### `VillainArc/Intents/Exercise/OpenExercisesIntent.swift`
- Does: Opens the full exercises list after setup/bootstrap, no-active-flow, and exercise-catalog availability validation.
- Called by: Siri/Shortcuts, donations (`donateOpenExercises`).
- Calls: `SetupGuard.requireReadyAndNoActiveFlow`, `Exercise.all`, `AppRouter.popToRoot`, `AppRouter.navigate(.exercisesList)`, `OpenAppIntent`.

### `VillainArc/Intents/Exercise/OpenExerciseIntent.swift`
- Does: Opens the exercise detail/progress screen for a selected exercise after setup/bootstrap and no-active-flow checks.
- Called by: Siri/Shortcuts, donations (`donateOpenExercise`).
- Calls: `SetupGuard.requireReadyAndNoActiveFlow`, `Exercise` resolution fetch, `AppRouter.popToRoot`, `AppRouter.navigate(.exerciseDetail)`, `OpenAppIntent`.

### `VillainArc/Intents/Exercise/ExerciseEntity.swift`
- Does: AppEntity + queries + fuzzy search support for exercise selection in intents, with shared system alternate names and boosted exact phrase scoring for disambiguation.
- Called by: Exercise intents, `SpotlightIndexer.associateAppEntity`, donations.
- Calls: `ExerciseSearch` + `TextNormalization` helpers, `SharedModelContainer` queries.

### `VillainArc/Intents/Exercise/ReplaceExerciseIntent.swift`
- Does: Replaces active workout exercise, optionally preserving sets.
- Called by: Siri/Shortcuts, donations (`donateReplaceExercise`).
- Calls: `requestChoice`, `ExercisePerformance.replaceWith`, `WorkoutActivityManager.update`.

### `VillainArc/Intents/Exercise/ToggleExerciseFavoriteIntent.swift`
- Does: Toggles favorite status for a selected exercise.
- Called by: Siri/Shortcuts/App Intent execution, donations (`donateToggleExerciseFavorite`).
- Calls: `ExerciseEntity` resolution fetch, `Exercise.toggleFavorite`, `saveContext`.

### `VillainArc/Intents/RestTimer/StartRestTimerIntent.swift`
- Does: Starts rest timer for duration parameter and returns snippet.
- Called by: Siri/Shortcuts, donations (`donateStartRestTimer`).
- Calls: `RestTimerState.start`, `RestTimeHistory.record`, `saveContext`, `RestTimerSnippetIntent`.

### `VillainArc/Intents/RestTimer/PauseRestTimerIntent.swift`
- Does: Pauses running rest timer and returns snippet.
- Called by: Siri/Shortcuts, donations (`donatePauseRestTimer`).
- Calls: `RestTimerState.pause`, `RestTimerIntentError`, `RestTimerSnippetIntent`.

### `VillainArc/Intents/RestTimer/ResumeRestTimerIntent.swift`
- Does: Resumes paused rest timer and returns snippet.
- Called by: Siri/Shortcuts, donations (`donateResumeRestTimer`).
- Calls: `RestTimerState.resume`, `RestTimerIntentError`, `RestTimerSnippetIntent`.

### `VillainArc/Intents/RestTimer/StopRestTimerIntent.swift`
- Does: Stops active rest timer.
- Called by: Siri/Shortcuts, donations (`donateStopRestTimer`).
- Calls: `RestTimerState.stop`, `RestTimerIntentError`.

### `VillainArc/Intents/RestTimer/RestTimerIntentError.swift`
- Does: Shared localized errors for rest timer intent flows.
- Called by: Start/pause/resume/stop/control rest timer intents.
- Calls: None (error enum only).

### `VillainArc/Intents/RestTimer/RestTimerControlIntent.swift`
- Does: Internal non-discoverable action intent for snippet button controls (pause/resume/stop).
- Called by: `RestTimerSnippetView` button intents.
- Calls: `RestTimerState` actions, `RestTimerSnippetIntent.reload`.

### `VillainArc/Intents/RestTimer/RestTimerSnippetView.swift`
- Does: Snippet intent + snippet view UI for live rest timer controls/status.
- Called by: Rest timer intents (`Start/Pause/Resume`) and control intent reload path.
- Calls: `RestTimerControlIntent` button actions, `secondsToTime`.

### `VillainArc/Intents/LiveActivity/LiveActivityAddExerciseIntent.swift`
- Does: Foreground live-activity action to open add-exercise sheet in app.
- Called by: Widget live activity buttons.
- Calls: `AppRouter.showAddExerciseFromLiveActivity`.

### `VillainArc/Intents/LiveActivity/LiveActivityCompleteSetIntent.swift`
- Does: Live-activity action to complete current set, optionally start rest timer, and prewarm the generic Foundation Models session when that set is the final incomplete set in a plan workout.
- Called by: Widget live activity buttons.
- Calls: `WorkoutSession.incomplete`, `WorkoutSession.isFinalIncompleteSet`, set completion mutation, `RestTimerState.start`, `FoundationModelPrewarmer`, `WorkoutActivityManager.update`.

### `VillainArc/Intents/LiveActivity/LiveActivityPauseRestTimerIntent.swift`
- Does: Live-activity action to pause running rest timer.
- Called by: Widget live activity buttons.
- Calls: `RestTimerState.pause`.

### `VillainArc/Intents/LiveActivity/LiveActivityResumeRestTimerIntent.swift`
- Does: Live-activity action to resume paused rest timer.
- Called by: Widget live activity buttons.
- Calls: `RestTimerState.resume`.

## 7) Extension Targets

### `VillainArcWidgetExtension/VillainArcWidgetExtensionBundle.swift`
- Does: Widget extension entry point (`@main`) bundling workout live activity widget.
- Called by: `VillainArcWidgetExtensionExtension` target runtime.
- Calls: `WorkoutLiveActivity`.

### `VillainArcWidgetExtension/VillainArcWidgetExtension.swift`
- Does: Lock-screen/dynamic-island live activity widget UI for workout state and controls.
- Called by: Widget extension runtime via bundle registration.
- Calls: `WorkoutActivityAttributes`, live activity intents (`LiveActivity*`), local formatting helpers.

### `VillainArcIntentsExtension/IntentHandler.swift`
- Does: Legacy SiriKit intent router for `INStartWorkoutIntent`, `INCancelWorkoutIntent`, `INEndWorkoutIntent`.
- Called by: `VillainArcIntentsExtension` target runtime.
- Calls: `StartWorkoutSiriHandler`, `CancelWorkoutSiriHandler`, `EndWorkoutSiriHandler`.

### `VillainArcIntentsExtension/StartWorkoutSiriHandler.swift`
- Does: SiriKit start-workout handler that returns `continueInApp` user activity.
- Called by: `IntentHandler`.
- Calls: `NSUserActivity(activityType: "com.villainarc.siri.startWorkout")`.

### `VillainArcIntentsExtension/CancelWorkoutSiriHandler.swift`
- Does: SiriKit cancel-workout handler that returns `continueInApp` user activity.
- Called by: `IntentHandler`.
- Calls: `NSUserActivity(activityType: "com.villainarc.siri.cancelWorkout")`.

### `VillainArcIntentsExtension/EndWorkoutSiriHandler.swift`
- Does: SiriKit end-workout handler that returns `continueInApp` user activity.
- Called by: `IntentHandler`.
- Calls: `NSUserActivity(activityType: "com.villainarc.siri.endWorkout")`.

## 8) Tests Target

### `VillainArcTests/VillainArcTests.swift`
- Does: Plan-editing behavior tests for `WorkoutPlan+Editing` and suggestion override semantics.
- Called by: `VillainArcTests` target test runner.
- Calls: `TestModelContainer.make`, `makePlanWithRuleSuggestions`, model/editing APIs under test.

### `VillainArcTests/WorkoutFinishTests.swift`
- Does: Workout finish action and pruning behavior tests for `WorkoutSession.finish`.
- Called by: `VillainArcTests` target test runner.
- Calls: Test data builders plus `WorkoutSession.finish(action:context:)`.

### `VillainArcTests/SuggestionSystemTests.swift`
- Does: Rule-engine/training-style/outcome/deduplicator behavior tests.
- Called by: `VillainArcTests` target test runner.
- Calls: `TestDataFactory`, `MetricsCalculator`, `RuleEngine`, `OutcomeRuleEngine`, `SuggestionDeduplicator`.

### `VillainArcTests/ExerciseReplacementTests.swift`
- Does: Exercise swap mechanics tests covering set value copying, prescription clearing, and historical lookup after replacement.
- Called by: `VillainArcTests` target test runner.
- Calls: `WorkoutSession(from: plan)`, `ExercisePerformance.replaceWith`, `ExercisePerformance.lastCompleted`.

### `VillainArcTests/SpotlightSummaryTests.swift`
- Does: Spotlight summary string formatting tests ensuring no "Optional()" leakage and correct set counts.
- Called by: `VillainArcTests` target test runner.
- Calls: `WorkoutSession` and `WorkoutPlan` summary properties.

### `VillainArcTests/ExerciseEntitySearchTests.swift`
- Does: Verifies system alternate-name generation for exercises and exact phrase preference in exercise entity search scoring.
- Called by: `VillainArcTests` target test runner.
- Calls: `Exercise.systemAlternateNames`, `exerciseEntitySearchScore`.

### `VillainArcTests/ExerciseHistoryMetricsTests.swift`
- Does: Verifies rep-based exercise history aggregates and progression points for bodyweight/no-load exercises.
- Called by: `VillainArcTests` target test runner.
- Calls: `ExerciseHistory.recalculate`, `ExercisePerformance.totalCompletedReps`, `ProgressionPoint.totalReps`.

### `VillainArcTests/DataManagerCatalogSyncTests.swift`
- Does: Verifies catalog metadata sync updates matching plan/session exercise snapshots without mutating unrelated exercises.
- Called by: `VillainArcTests` target test runner.
- Calls: `DataManager.syncExerciseSnapshots`, `WorkoutSession(from: plan)`, core exercise/plan/session model constructors.

### `VillainArcTests/TestSupport/TestDataFactory.swift`
- Does: Shared test-only factory helpers for creating model contexts, plans, sessions, and performances.
- Called by: `SuggestionSystemTests`, `DataManagerCatalogSyncTests`.
- Calls: `TestModelContainer.make`, core model constructors.

### `VillainArcTests/TestSupport/PlanEditingTestData.swift`
- Does: Shared fixture builder for plan-editing tests with seeded rule suggestions.
- Called by: `VillainArcTests.swift`.
- Calls: Core plan/prescription/change model constructors.

### `VillainArcTests/TestSupport/WorkoutPlan+TestSupport.swift`
- Does: Shared test model-container setup + `WorkoutPlan` convenience builders.
- Called by: test suites and test data factories.
- Calls: `ModelContainer(for: SharedModelContainer.schema, isStoredInMemoryOnly: true)`.

## 9) Entry Template

Use this for each new file:

```md
### `path/to/File.swift`
- Does:
- Called by:
- Calls:
```

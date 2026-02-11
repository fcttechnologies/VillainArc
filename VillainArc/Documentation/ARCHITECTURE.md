# VillainArc Architecture Map

**Status**: Draft  
**Last updated**: 2026-02-11  
**Scope**: Root app/navigation + persistence/Spotlight + intent/shortcuts/donations + workout history/detail + workout session/suggestions + suggestion rules/AI pipeline + workout plan list/detail + split planning/editing + exercise selection/editor slice + helper utility slice + data model layer (session/plan/split/history/suggestions).

## 1) Architecture Map

- `VillainArcApp`
  - Creates root `ContentView`
  - Injects `SharedModelContainer.container`
  - Forwards Spotlight/Siri user activities to `AppRouter.shared`
- `ContentView`
  - Binds root navigation and modal state to `AppRouter.shared`
  - Runs startup bootstrap via `DataManager.seedExercisesIfNeeded`
  - Hosts home sections including `RecentWorkoutSectionView`
  - Uses shared UI helpers (`navBar`, accessibility labels/ids)
- `AppRouter.shared`
  - Owns app navigation/workflow state (`path`, active workout/plan)
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
- `Exercise` + catalog/search metadata + `ExerciseHistory`/`ProgressionPoint`
  - Canonical exercise identity/search + derived longitudinal performance cache
- `RepRangePolicy` / `RestTimePolicy` / `RestTimeHistory` / `PreWorkoutStatus`
  - Reusable policy and session-adjacent models shared by workout and plan flows
- `DataManager` (`saveContext` / `scheduleSave`)
  - Seeds and dedupes exercise catalog data
  - Provides shared save helpers used by router/views/models
- `SpotlightIndexer`
  - Indexes/deletes workout sessions, workout plans, and exercises in Spotlight
  - Prefix constants are consumed by `AppRouter.handleSpotlight`
- `IntentDonations`
  - Central donation adapter from UI/workflow events to App Intents
- `VillainArcShortcuts`
  - Declares the discoverable App Shortcuts surface
- `App Intents` (`Workout*`, `WorkoutPlan*`, `Exercise*`, `RestTimer*`, `OpenAppIntent`)
  - Handle Siri/Shortcuts actions and foreground/background routing
- `LiveActivity Intents` + `RestTimerSnippetIntent`
  - Support lock-screen/live activity controls and snippet interactions
- `RecentWorkoutSectionView`
  - Queries the latest workout for home summary
  - Navigates to workout history via `AppRouter.navigate(.workoutSessionsList)`
- `WorkoutRowView`
  - Reusable workout summary card row
  - Navigates to workout detail via `AppRouter.navigate(.workoutSessionDetail)`
- `ExerciseSetRowView`
  - Editable set row used in active workout exercises
  - Handles set type, reps/weight logging, completion, timer start, and per-set quick actions
- `RPEPickerView`
  - Quick sheet picker for set RPE values
- `WorkoutsListView`
  - Shows completed workouts list
  - Handles bulk/single delete with Spotlight cleanup + exercise history recompute
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
- `PreWorkoutStatusView`
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
  - Handles split actions (rotation/offset), split activation, and per-day plan selection
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
- Calls: `AppRouter.startWorkoutSession`, `AppRouter.createWorkoutPlan`, `AppRouter.checkForUnfinishedData`, `DataManager.seedExercisesIfNeeded`, home sections (`WorkoutSplitSectionView`, `RecentWorkoutSectionView`, `RecentWorkoutPlanSectionView`), destination views (`WorkoutsListView`, `WorkoutDetailView`, `WorkoutPlansListView`, `WorkoutPlanDetailView`, `WorkoutSplitView`, `WorkoutSplitCreationView`), full-screen views (`WorkoutSessionContainer`, `WorkoutPlanView`), `IntentDonations.*`.

### `VillainArc/Data/Classes/AppRouter.swift`
- Does: App-wide navigation/workflow coordinator. Owns `path`, `activeWorkoutSession`, `activeWorkoutPlan`, and Spotlight/Siri routing behavior.
- Called by: `VillainArcApp`, `ContentView`, many feature views under `VillainArc/Views/*`, and app intents under `VillainArc/Intents/*`.
- Calls: SwiftData context (`insert/fetch/delete` via `SharedModelContainer.container.mainContext`), `saveContext`, `Haptics.selection`, `pendingSuggestions`, `RestTimerState.shared.stop`, `WorkoutActivityManager.end`, `SpotlightIndexer.workoutSessionIdentifierPrefix`, `SpotlightIndexer.workoutPlanIdentifierPrefix`.

### `VillainArc/Data/SharedModelContainer.swift`
- Does: Defines app-wide SwiftData schema and creates the shared `ModelContainer`.
- Called by: `VillainArcApp` (`.modelContainer`), `AppRouter` (`mainContext`), `WorkoutActivityManager`, and many app intent/entity files.
- Calls: `Schema(...)` with model types, `FileManager.default.containerURL(...)`, `ModelConfiguration(...)`, `ModelContainer(for:configurations:)`.

### `VillainArc/Data/Classes/DataManager.swift`
- Does: Catalog bootstrap/dedupe (`DataManager`) plus shared persistence helpers (`saveContext`, `scheduleSave`).
- Called by: `ContentView` (`seedExercisesIfNeeded`), `AddExerciseView` (`dedupeCatalogExercisesIfNeeded`), exercise intents, and many views/models/router through `saveContext`/`scheduleSave`.
- Calls: `UserDefaults.standard` (`exerciseCatalogVersion`), `ExerciseCatalog` (`catalogVersion`, `all`, `byID`), `ModelContext.fetch/insert/delete/save`.

### `VillainArc/Data/Classes/Suggestions/SuggestionGenerator.swift`
- Does: Generates `PrescriptionChange` suggestions for completed plan-based sessions by combining deterministic rules with optional AI style inference.
- Called by: `WorkoutSummaryView` (`generateSuggestionsIfNeeded`).
- Calls: `MetricsCalculator.detectTrainingStyle`, `AITrainingStyleClassifier.infer`, `RuleEngine.evaluate`, `SuggestionDeduplicator.process`, `ExercisePerformance.matching(...)`, `ModelContext.fetch`.

### `VillainArc/Data/Classes/Suggestions/RuleEngine.swift`
- Does: Main deterministic suggestion engine (progression/safety/rest/set-type rules) that emits candidate `PrescriptionChange` values.
- Called by: `SuggestionGenerator`.
- Calls: `MetricsCalculator.selectProgressionSets`, `MetricsCalculator.weightIncrement`, `MetricsCalculator.roundToNearestPlate`, model helpers (`ExercisePerformance.effectiveRestSeconds`, `repRange`, set/prescription linkage), `PrescriptionChange` initializers.

### `VillainArc/Data/Classes/Suggestions/MetricsCalculator.swift`
- Does: Shared training metrics helper for style detection, progression set selection, increment sizing, and plate rounding.
- Called by: `SuggestionGenerator`, `RuleEngine`, `OutcomeResolver`, `OutcomeRuleEngine`.
- Calls: Internal heuristics only (`detectTrainingStyle`, `setsForStyle`, `weightIncrement`, `roundToNearestPlate`).

### `VillainArc/Data/Classes/Suggestions/SuggestionDeduplicator.swift`
- Does: Conflict resolver for generated suggestions (strategy conflicts, policy conflicts, same-target property collisions).
- Called by: `SuggestionGenerator`.
- Calls: Internal grouping/priority helpers (`resolveLogicalConflicts`, `resolveConflicts`).

### `VillainArc/Data/Classes/Suggestions/OutcomeResolver.swift`
- Does: Resolves outcomes for prior suggestions in the next workout by combining deterministic rule results with optional AI inference at group level.
- Called by: `WorkoutSummaryView` (`generateSuggestionsIfNeeded` pre-step).
- Calls: `OutcomeRuleEngine.evaluate`, `AIOutcomeInferrer.inferApplied`, `AIOutcomeInferrer.inferRejected`, `MetricsCalculator.detectTrainingStyle`, change outcome mutation helpers, `ModelContext.save`.

### `VillainArc/Data/Classes/Suggestions/OutcomeRuleEngine.swift`
- Does: Deterministic per-change outcome evaluator (`good` / `tooAggressive` / `tooEasy` / `ignored`) using actual set performance.
- Called by: `OutcomeResolver`.
- Calls: `MetricsCalculator.weightIncrement`, change-type-specific evaluation helpers.

### `VillainArc/Data/Classes/Suggestions/AITrainingStyleClassifier.swift`
- Does: On-device Foundation Models classifier for exercise training style when deterministic style detection is inconclusive.
- Called by: `SuggestionGenerator` (for `.unknown` style cases).
- Calls: `SystemLanguageModel.default`, `LanguageModelSession`, `RecentExercisePerformancesTool`, `AIInferenceOutput` generation/validation.

### `VillainArc/Data/Classes/Suggestions/AITrainingStyleTools.swift`
- Does: Defines `RecentExercisePerformancesTool` used by the style classifier to fetch recent exercise history snapshots.
- Called by: `AITrainingStyleClassifier` (tool-enabled `LanguageModelSession`).
- Calls: `ModelContext(SharedModelContainer.container)`, `ExercisePerformance.matching(...)`, `ModelContext.fetch`, `AIExercisePerformanceSnapshot`.

### `VillainArc/Data/Classes/Suggestions/AIOutcomeInferrer.swift`
- Does: On-device Foundation Models evaluator that infers grouped suggestion outcomes for applied vs rejected paths.
- Called by: `OutcomeResolver`.
- Calls: `SystemLanguageModel.default`, `LanguageModelSession`, `AIOutcomeGroupInput` prompts, `AIOutcomeInferenceOutput` validation.

### `VillainArc/Data/Classes/SpotlightIndexer.swift`
- Does: Central Spotlight indexing/deindexing for `WorkoutSession`, `WorkoutPlan`, and `Exercise`; defines reusable identifier prefixes.
- Called by: workout/plan/exercise views for index/delete actions, `AppRouter` (Spotlight identifier parsing), and related intent/editing flows.
- Calls: `CSSearchableItemAttributeSet`, `CSSearchableItem`, `CSSearchableIndex.default().indexSearchableItems`, `CSSearchableIndex.default().deleteSearchableItems`, `associateAppEntity(...)` using `WorkoutSessionEntity`, `WorkoutPlanEntity`, `ExerciseEntity`.

### `VillainArc/Views/Components/RecentWorkoutSectionView.swift`
- Does: Home "Workouts" section; shows empty state or latest workout card and provides quick navigation to workout history.
- Called by: `ContentView`, SwiftUI preview.
- Calls: `@Query(WorkoutSession.recent)`, `HomeSectionHeaderButton`, `AppRouter.navigate(to: .workoutSessionsList)`, `WorkoutRowView`, `IntentDonations.donateShowWorkoutHistory`, `IntentDonations.donateViewLastWorkout`.

### `VillainArc/Views/Components/WorkoutRowView.swift`
- Does: Reusable workout summary row/card that opens workout detail when tapped.
- Called by: `RecentWorkoutSectionView`, `WorkoutsListView`, SwiftUI preview.
- Calls: `AppRouter.navigate(to: .workoutSessionDetail(...))`, `IntentDonations.donateOpenWorkout`, `AccessibilityText.workoutRowLabel/workoutRowValue/workoutRowHint`.

### `VillainArc/Views/Components/ExerciseSetRowView.swift`
- Does: Editable set row used during active workout logging (set type, reps/weight fields, reference apply, complete/uncomplete, optional RPE).
- Called by: `ExerciseView`, SwiftUI preview via `ExerciseView`.
- Calls: `RPEPickerView`, `RestTimerState.shared`, `RestTimeHistory.record`, `WorkoutActivityManager.update`, `IntentDonations.donateStartRestTimer`, `IntentDonations.donateCompleteActiveSet`, `Haptics.selection`, `saveContext`, `scheduleSave`, `secondsToTime`.

### `VillainArc/Views/Components/RPEPickerView.swift`
- Does: Compact sheet picker for selecting/clearing RPE values and showing effort descriptions.
- Called by: `ExerciseSetRowView`, SwiftUI preview.
- Calls: `Haptics.selection`, `dismiss` environment action.

### `VillainArc/Views/Components/HomeSectionHeaderButton.swift`
- Does: Reusable home section header button with title + chevron styling and accessibility wiring.
- Called by: `RecentWorkoutSectionView`, `RecentWorkoutPlanSectionView`, `WorkoutSplitSectionView`.
- Calls: Provided `action` closure.

### `VillainArc/Views/Components/SmallUnavailableView.swift`
- Does: Compact unavailable/empty-state presentational component.
- Called by: `WorkoutSplitSectionView`, SwiftUI preview.
- Calls: None (display-only component).

### `VillainArc/Views/Components/TextEntryEditorView.swift`
- Does: Reusable single-text-field sheet editor (title/notes style) with auto-focus and trim-on-close behavior.
- Called by: `WorkoutPlanView`, `WorkoutView`, `WorkoutSummaryView`, `WorkoutSplitCreationView`, SwiftUI preview.
- Calls: `dismissKeyboard`, `.navBar(title:)`, `CloseButton`, bound text mutation (`trimmingCharacters`).

### `VillainArc/Views/WorkoutsListView.swift`
- Does: List of completed workouts with edit mode, per-item delete, and delete-all workflow.
- Called by: `ContentView` navigation destination for `.workoutSessionsList`, SwiftUI preview.
- Calls: `@Query(WorkoutSession.completedSession)`, `WorkoutRowView`, `Haptics.selection`, `SpotlightIndexer.deleteWorkoutSessions`, `ModelContext.delete`, `ExerciseHistoryUpdater.updateHistory`, `IntentDonations.donateDeleteWorkout`, `IntentDonations.donateDeleteAllWorkouts`.

### `VillainArc/Views/Workout/WorkoutDetailView.swift`
- Does: Detailed readout for one completed workout (notes, exercises, sets) with actions to delete the workout, save as plan when no linked plan exists, and open linked plan when present.
- Called by: `ContentView` navigation destination for `.workoutSessionDetail`, SwiftUI preview.
- Calls: `formattedDateRange`, `WorkoutPlanView` (fullScreenCover), `AppRouter.popToRoot`, `AppRouter.navigate(to: .workoutPlanDetail(...))`, `IntentDonations.donateOpenWorkoutPlan`, `IntentDonations.donateDeleteWorkout`, `userActivity` with `WorkoutSessionEntity`, `Haptics.selection`, `SpotlightIndexer.deleteWorkoutSession`, `ModelContext.delete/insert`, `ExerciseHistoryUpdater.updateHistory`, `saveContext`.

### `VillainArc/Views/Workout/WorkoutSessionContainer.swift`
- Does: Status-driven workout flow container that switches between suggestion review, active logging, and summary stages.
- Called by: `ContentView` fullScreenCover for `activeWorkoutSession`, SwiftUI previews.
- Calls: `DeferredSuggestionsView`, `WorkoutView`, `WorkoutSummaryView`.

### `VillainArc/Views/Workout/WorkoutView.swift`
- Does: Primary active-workout screen (exercise pager/list, add exercise, timer access, title/notes/pre-checkin sheets, finish/cancel actions).
- Called by: `WorkoutSessionContainer`, SwiftUI previews.
- Calls: `ExerciseView`, `AddExerciseView`, `RestTimerView`, `PreWorkoutStatusView`, `TextEntryEditorView`, `WorkoutSession.finish`, `SpotlightIndexer.index(workoutSession:)`, `WorkoutActivityManager.start/update/end`, `IntentDonations` workout actions, `RestTimerState.shared.stop`, `saveContext`, `scheduleSave`, `Haptics.selection`.

### `VillainArc/Views/Workout/ExerciseView.swift`
- Does: Per-exercise workout page with set logging grid, notes, rep/rest editors, replace action, and set reference handling.
- Called by: `WorkoutView`, SwiftUI preview.
- Calls: `ExerciseSetRowView`, `RepRangeEditorView`, `RestTimeEditorView`, `ReplaceExerciseView`, `WorkoutActivityManager.update`, `IntentDonations.donateReplaceExercise`, `saveContext`, `scheduleSave`, `Haptics.selection`, `secondsToTime`.

### `VillainArc/Views/Workout/PreWorkoutStatusView.swift`
- Does: Sheet for recording pre-workout status (mood, pre-workout drink toggle, optional notes).
- Called by: `WorkoutView`, SwiftUI preview.
- Calls: `Haptics.selection`, `dismissKeyboard`, `saveContext`, `scheduleSave`, `dismiss` environment action.

### `VillainArc/Views/Workout/RestTimerView.swift`
- Does: Rest timer control screen with picker/start-pause-resume-stop, recent durations, and next-set completion shortcut.
- Called by: `WorkoutView`, SwiftUI preview.
- Calls: `TimerDurationPicker`, `RestTimerState.shared` (`start/pause/resume/stop/adjust`), `RestTimeHistory.record`, `WorkoutSession.activeExerciseAndSet`, `WorkoutActivityManager.update`, `IntentDonations` rest-timer actions, `saveContext`, `secondsToTime`, `Haptics.selection`.

### `VillainArc/Views/Workout/WorkoutSummaryView.swift`
- Does: Post-workout summary and finalization screen (stats, PR detection, effort rating, notes/title edits, suggestion review, save as plan).
- Called by: `WorkoutSessionContainer`, SwiftUI previews.
- Calls: `formattedDateRange`, `TextEntryEditorView`, `SuggestionReviewView`, `OutcomeResolver.resolveOutcomes`, `SuggestionGenerator.generateSuggestions`, `groupSuggestions`, `acceptGroup/rejectGroup/deferGroup`, `ExerciseHistoryUpdater.createIfNeeded/fetchHistory/updateHistoriesForCompletedWorkout`, `SpotlightIndexer.index(workoutPlan:)`, `IntentDonations.donateSaveWorkoutAsPlan`, `saveContext`, `scheduleSave`, `Haptics.selection`.

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
- Calls: `FilteredExerciseListView`, `MuscleFilterSheetView`, `DataManager.dedupeCatalogExercisesIfNeeded`, `WorkoutSession.addExercise`, `WorkoutPlan.addExercise`, `Exercise.updateLastUsed`, `SpotlightIndexer.index(exercise:)`, `saveContext`, `IntentDonations.donateAddExercise/donateAddExercises`, `Haptics.selection`.

### `VillainArc/Views/Workout/FilteredExerciseListView.swift`
- Does: Reusable exercise list for search/filter/sort/select with favorite toggling and optional single-selection mode.
- Called by: `AddExerciseView`, `ReplaceExerciseView`, SwiftUI preview.
- Calls: `@Query(Exercise...)` with dynamic filter/sort, search helpers (`normalizedTokens`, `exerciseSearchMatches`, fuzzy matching), `Haptics.selection`, `SpotlightIndexer.index(exercise:)`, `IntentDonations.donateToggleExerciseFavorite`, `saveContext`, `AccessibilityIdentifiers`, `AccessibilityText`.

### `VillainArc/Views/Workout/ReplaceExerciseView.swift`
- Does: Sheet flow for replacing one workout exercise with another (single selection plus keep/clear sets confirmation).
- Called by: `ExerciseView`, SwiftUI preview.
- Calls: `FilteredExerciseListView`, `MuscleFilterSheetView`, provided `onReplace` callback, `Haptics.selection`, `dismiss` environment action.

### `VillainArc/Views/Workout/MuscleFilterSheetView.swift`
- Does: Reusable sheet for selecting major/minor muscle filters and returning the chosen set through `onConfirm`.
- Called by: `AddExerciseView`, `ReplaceExerciseView`, `WorkoutSplitDayView`, SwiftUI previews.
- Calls: `Haptics.selection`, `AccessibilityIdentifiers.muscleFilterChip`, provided `onConfirm` callback, `dismiss` environment action.

### `VillainArc/Views/Workout/RepRangeEditorView.swift`
- Does: Editor for an exercise's rep-range policy (`notSet` / `target` / `range`) with suggestion from recent history.
- Called by: `WorkoutPlanView` (`WorkoutPlanExerciseView`), `ExerciseView`, SwiftUI preview.
- Calls: `RepRangeMode`/`RepRangePolicy` mutations, history fetch via `ExercisePerformance.matching/completedAll`, `Haptics.selection`, `saveContext`, `scheduleSave`, `.navBar(title:)`, `CloseButton`.

### `VillainArc/Views/Workout/RestTimeEditorView.swift`
- Does: Generic rest-time editor for exercises with mode-specific rest controls, copy/paste seconds, and per-row picker expansion.
- Called by: `WorkoutPlanView` (`WorkoutPlanExerciseView`), `ExerciseView`, SwiftUI preview.
- Calls: `TimerDurationPicker`, `secondsToTime`, `Haptics.selection`, `saveContext`, `scheduleSave`, `.navBar(title:)`, `CloseButton`.

### `VillainArc/Views/Components/RecentWorkoutPlanSectionView.swift`
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
- Does: Detailed view for a single workout plan with actions to select/start/edit/delete and favorite the plan.
- Called by: `ContentView` navigation destination for `.workoutPlanDetail`, `WorkoutPlanPickerView`, SwiftUI preview.
- Calls: `WorkoutPlan.musclesTargeted()`, `plan.createEditingCopy(context:)`, `WorkoutPlanView` (fullScreenCover), `@Query` over `WorkoutSplit`, `AppRouter.startWorkoutSession(from:)`, `IntentDonations.donateStartWorkoutWithPlan`, `IntentDonations.donateStartTodaysWorkout` (when the started plan matches active split's current day), `IntentDonations.donateToggleWorkoutPlanFavorite`, `IntentDonations.donateDeleteWorkoutPlan`, `userActivity` with `WorkoutPlanEntity`, `Haptics.selection`, `SpotlightIndexer.deleteWorkoutPlan`, `ModelContext.delete`, `saveContext`.

### `VillainArc/Views/WorkoutPlan/WorkoutPlanView.swift`
- Does: Full-screen editor for creating or editing a workout plan, including exercise list editing, set editing, notes/title editing, and save/cancel logic.
- Called by: `ContentView` (`activeWorkoutPlan` fullScreenCover), `WorkoutPlanDetailView` (editing copy flow), `WorkoutPlanPickerView` (new plan flow), `WorkoutDetailView` (save workout as plan), SwiftUI preview.
- Calls: `AddExerciseView`, `TextEntryEditorView`, `WorkoutPlan.finishEditing`, `WorkoutPlan.cancelEditing`, `WorkoutPlan.deletePlanEntirely`, `WorkoutPlan.deleteExercise`, `WorkoutPlan.moveExercise`, `SpotlightIndexer.index(workoutPlan:)`, `saveContext`, `scheduleSave`, `dismissKeyboard`, nested editors (`RepRangeEditorView`, `RestTimeEditorView`), `WorkoutPlanEntity` via `userActivity`.

### `VillainArc/Views/WorkoutPlan/WorkoutPlanPickerView.swift`
- Does: Plan selection screen for assigning/clearing a selected plan, with ability to create a new plan inline.
- Called by: `WorkoutSplitView` (`SplitDayPlanPickerSheet`), `WorkoutSplitDayView`, SwiftUI preview.
- Calls: `@Query(WorkoutPlan.all)`, `WorkoutPlanDetailView` (with select callback), `WorkoutPlanCardView`, `WorkoutPlanView` (new plan fullScreenCover), `ModelContext.insert/fetch`, `saveContext`, `IntentDonations.donateCreateWorkoutPlan`, `Haptics.selection`.

### `VillainArc/Views/WorkoutSplit/WorkoutSplitView.swift`
- Does: Main split management screen showing active/inactive splits, split actions, and today's plan assignment summary.
- Called by: `ContentView` navigation destination for `.splitList`, SwiftUI preview.
- Calls: `@Query` over `WorkoutSplit`, `SplitBuilderView`, `WorkoutPlanPickerView` (`SplitDayPlanPickerSheet`), `WorkoutPlanRowView`, `AppRouter.navigate(to: .splitDettail(...))`, `IntentDonations.donateTrainingSummary`, `Haptics.selection`, `saveContext`, split model operations (`refreshRotationIfNeeded`, `missedDay`, `resetSplit`, `updateCurrentIndex`).

### `VillainArc/Views/Components/WorkoutSplitSectionView.swift`
- Does: Home split summary section that shows active/today state and routes users into split screens.
- Called by: `ContentView`, SwiftUI preview.
- Calls: `@Query` over `WorkoutSplit`, `HomeSectionHeaderButton`, `SmallUnavailableView`, `AppRouter.navigate(to: .splitList/.workoutPlanDetail)`, `IntentDonations.donateStartTodaysWorkout`, `IntentDonations.donateOpenWorkoutPlan`, `WorkoutSplit.refreshRotationIfNeeded`.

### `VillainArc/Views/WorkoutSplit/SplitBuilderView.swift`
- Does: Multi-step split builder for preset-based or scratch split creation (type, schedule mode, training days, rest style).
- Called by: `WorkoutSplitView` (create split sheet), SwiftUI preview.
- Calls: `AppRouter.navigate(to: .splitDettail(...))`, `ModelContext.fetch/insert`, `saveContext`, `Haptics.selection`, split/day model creation (`WorkoutSplit`, `WorkoutSplitDay`), internal generator/config types (`SplitBuilderConfig`, `SplitGenerator`).

### `VillainArc/Views/WorkoutSplit/WorkoutSplitCreationView.swift`
- Does: Split detail editing screen for an existing split, including day paging, rename, swap mode, day rotation/reorder, and delete actions.
- Called by: `ContentView` navigation destination for `.splitDettail`, SwiftUI preview.
- Calls: `WorkoutSplitDayView`, `TextEntryEditorView`, `WorkoutSplit.deleteDay`, `ModelContext.delete`, `saveContext`, `scheduleSave`, `Haptics.selection`, internal helpers for swap/rotation (`swapDays`, `rotateSplit`, `setCurrentRotationDay`).

### `VillainArc/Views/WorkoutSplit/WorkoutSplitDayView.swift`
- Does: Per-day editor used inside split creation/detail flow; controls rest-day state, day name, assigned plan, and target muscles.
- Called by: `WorkoutSplitCreationView` (tab pages), SwiftUI preview via `WorkoutSplitCreationView`.
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

### `VillainArc/Data/Classes/ExerciseHistoryUpdater.swift`
- Does: Rebuild/create/delete `ExerciseHistory` records from completed exercise performances after workout completion/deletion.
- Called by: `WorkoutsListView`, `WorkoutDetailView`, `WorkoutSummaryView`.
- Calls: `ModelContext.fetch/insert/delete`, `ExercisePerformance.matching(...)`, `ExerciseHistory.forCatalogID(...)`, `ExerciseHistory.recalculate(using:)`, `saveContext`.

## 3) Intents

### Intent Inventory
- App Intents (Workout): `StartWorkoutIntent`, `StartTodaysWorkoutIntent`, `TrainingSummaryIntent`, `LastWorkoutSummaryIntent`, `FinishWorkoutIntent`, `CompleteActiveSetIntent`, `CancelWorkoutIntent`, `ViewLastWorkoutIntent`, `ShowWorkoutHistoryIntent`, `OpenWorkoutIntent`, `SaveWorkoutAsPlanIntent`, `DeleteWorkoutIntent`, `DeleteAllWorkoutsIntent`.
- App Intents (Workout Plan): `CreateWorkoutPlanIntent`, `StartWorkoutWithPlanIntent`, `OpenWorkoutPlanIntent`, `ShowWorkoutPlansIntent`, `DeleteWorkoutPlanIntent`, `DeleteAllWorkoutPlansIntent`, `ToggleWorkoutPlanFavoriteIntent`.
- App Intents (Exercise): `AddExerciseIntent`, `AddExercisesIntent`, `ReplaceExerciseIntent`, `ToggleExerciseFavoriteIntent`.
- App Intents (Rest Timer): `StartRestTimerIntent`, `PauseRestTimerIntent`, `ResumeRestTimerIntent`, `StopRestTimerIntent`, `RestTimerControlIntent`.
- App Intent (App shell): `OpenAppIntent`.
- Live Activity Intents: `LiveActivityAddExerciseIntent`, `LiveActivityCompleteSetIntent`, `LiveActivityPauseRestTimerIntent`, `LiveActivityResumeRestTimerIntent`.
- Snippet Intent: `RestTimerSnippetIntent`.
- Intent entities/queries: `WorkoutSessionEntity` + `WorkoutSessionEntityQuery`, `WorkoutPlanEntity` + `WorkoutPlanEntityQuery`, `ExerciseEntity` + `ExerciseEntityQuery`.

### Shortcut Registration
- `VillainArc/Intents/VillainArcShortcuts.swift` currently registers: `StartWorkoutIntent`, `StartWorkoutWithPlanIntent`, `StartTodaysWorkoutIntent`, `TrainingSummaryIntent`, `LastWorkoutSummaryIntent`, `FinishWorkoutIntent`, `CompleteActiveSetIntent`, `AddExerciseIntent`, `StartRestTimerIntent`, `StopRestTimerIntent`.

### Donation Map (`IntentDonations`)
- `StartWorkoutIntent`: donated via `donateStartWorkout`; called from `VillainArc/Views/ContentView.swift`.
- `StartTodaysWorkoutIntent`: donated via `donateStartTodaysWorkout`; called from `VillainArc/Views/Components/WorkoutSplitSectionView.swift`, `VillainArc/Views/WorkoutPlan/WorkoutPlanDetailView.swift` (when starting the active split's current-day plan).
- `ViewLastWorkoutIntent`: donated via `donateViewLastWorkout`; called from `VillainArc/Views/Components/RecentWorkoutSectionView.swift`.
- `OpenWorkoutIntent`: donated via `donateOpenWorkout`; called from `VillainArc/Views/Components/WorkoutRowView.swift`.
- `SaveWorkoutAsPlanIntent`: donated via `donateSaveWorkoutAsPlan`; called from `VillainArc/Views/Workout/WorkoutSummaryView.swift`.
- `DeleteWorkoutIntent`: donated via `donateDeleteWorkout`; called from `VillainArc/Views/Workout/WorkoutDetailView.swift`, `VillainArc/Views/WorkoutsListView.swift` (single-delete path).
- `DeleteAllWorkoutsIntent`: donated via `donateDeleteAllWorkouts`; called from `VillainArc/Views/WorkoutsListView.swift`.
- `ShowWorkoutHistoryIntent`: donated via `donateShowWorkoutHistory`; called from `VillainArc/Views/Components/RecentWorkoutSectionView.swift`.
- `ShowWorkoutPlansIntent`: donated via `donateShowWorkoutPlans`; called from `VillainArc/Views/Components/RecentWorkoutPlanSectionView.swift`.
- `OpenWorkoutPlanIntent`: donated via `donateOpenWorkoutPlan`; called from `VillainArc/Views/Components/WorkoutPlanRowView.swift`, `VillainArc/Views/Components/WorkoutSplitSectionView.swift`, `VillainArc/Views/Workout/WorkoutDetailView.swift`.
- `DeleteWorkoutPlanIntent`: donated via `donateDeleteWorkoutPlan`; called from `VillainArc/Views/WorkoutPlan/WorkoutPlanDetailView.swift`, `VillainArc/Views/WorkoutPlan/WorkoutPlansListView.swift` (single-delete path).
- `DeleteAllWorkoutPlansIntent`: donated via `donateDeleteAllWorkoutPlans`; called from `VillainArc/Views/WorkoutPlan/WorkoutPlansListView.swift`.
- `ToggleWorkoutPlanFavoriteIntent`: donated via `donateToggleWorkoutPlanFavorite`; called from `VillainArc/Views/WorkoutPlan/WorkoutPlanDetailView.swift`, `VillainArc/Views/WorkoutPlan/WorkoutPlansListView.swift`.
- `LastWorkoutSummaryIntent`: donated via `donateLastWorkoutSummary`; called from `VillainArc/Views/Workout/WorkoutView.swift`.
- `TrainingSummaryIntent`: donated via `donateTrainingSummary`; called from `VillainArc/Views/WorkoutSplit/WorkoutSplitView.swift`.
- `CreateWorkoutPlanIntent`: donated via `donateCreateWorkoutPlan`; called from `VillainArc/Views/ContentView.swift`, `VillainArc/Views/WorkoutPlan/WorkoutPlanPickerView.swift`.
- `StartWorkoutWithPlanIntent`: donated via `donateStartWorkoutWithPlan`; called from `VillainArc/Views/WorkoutPlan/WorkoutPlanDetailView.swift`, `VillainArc/Intents/Workout/StartTodaysWorkoutIntent.swift`.
- `AddExerciseIntent`: donated via `donateAddExercise`; called from `VillainArc/Views/Workout/AddExerciseView.swift`.
- `AddExercisesIntent`: donated via `donateAddExercises`; called from `VillainArc/Views/Workout/AddExerciseView.swift`.
- `ReplaceExerciseIntent`: donated via `donateReplaceExercise`; called from `VillainArc/Views/Workout/ExerciseView.swift`.
- `ToggleExerciseFavoriteIntent`: donated via `donateToggleExerciseFavorite`; called from `VillainArc/Views/Workout/FilteredExerciseListView.swift`.
- `StartRestTimerIntent`: donated via `donateStartRestTimer`; called from `VillainArc/Views/Workout/RestTimerView.swift`, `VillainArc/Views/Components/ExerciseSetRowView.swift`, `VillainArc/Intents/Workout/CompleteActiveSetIntent.swift`.
- `PauseRestTimerIntent`: donated via `donatePauseRestTimer`; called from `VillainArc/Views/Workout/RestTimerView.swift`.
- `ResumeRestTimerIntent`: donated via `donateResumeRestTimer`; called from `VillainArc/Views/Workout/RestTimerView.swift`.
- `StopRestTimerIntent`: donated via `donateStopRestTimer`; called from `VillainArc/Views/Workout/RestTimerView.swift`.
- `FinishWorkoutIntent`: donated via `donateFinishWorkout`; called from `VillainArc/Views/Workout/WorkoutView.swift`.
- `CancelWorkoutIntent`: donated via `donateCancelWorkout`; called from `VillainArc/Views/Workout/WorkoutView.swift`.
- `CompleteActiveSetIntent`: donated via `donateCompleteActiveSet`; called from `VillainArc/Views/Workout/RestTimerView.swift`, `VillainArc/Views/Components/ExerciseSetRowView.swift`.

### Non-Donation Intent Paths
- `OpenAppIntent`: used as `opensIntent` return target from multiple foreground intents; not donated.
- `RestTimerControlIntent`: invoked from `RestTimerSnippetView` button intents; not donated.
- `RestTimerSnippetIntent`: returned by rest timer intents and reloaded by `RestTimerControlIntent`; not donated.
- Live activity intents (`LiveActivity*`): invoked by live activity controls; not donated through `IntentDonations`.

## 4) Data Models

### Model Relationship Map
- `Exercise` is the canonical exercise catalog record used to create `ExercisePerformance` and `ExercisePrescription` rows.
- `WorkoutSession` owns one `PreWorkoutStatus` and many `ExercisePerformance` rows.
- `ExercisePerformance` owns many `SetPerformance` rows, and can point back to its originating `ExercisePrescription`.
- `SetPerformance` can point back to its originating `SetPrescription`.
- `WorkoutPlan` owns many `ExercisePrescription` rows.
- `ExercisePrescription` owns many `SetPrescription` rows.
- `WorkoutSplit` owns many `WorkoutSplitDay` rows.
- `WorkoutSplitDay` may reference one assigned `WorkoutPlan` (or be a rest day).
- `PrescriptionChange` links source evidence (`sessionFrom`/`sourceExercisePerformance`/`sourceSetPerformance`) to targets (`targetPlan`/`targetExercisePrescription`/`targetSetPrescription`) and lifecycle state (`decision`, `outcome`).
- `ExerciseHistory` stores aggregate stats per `catalogID` and owns `ProgressionPoint` rows.
- `RestTimeHistory` stores reusable recent rest durations.
- `SharedModelContainer.schema` persists: `WorkoutSession`, `PreWorkoutStatus`, `ExercisePerformance`, `SetPerformance`, `Exercise`, `ExerciseHistory`, `ProgressionPoint`, `RepRangePolicy`, `RestTimePolicy`, `RestTimeHistory`, `WorkoutPlan`, `ExercisePrescription`, `SetPrescription`, `WorkoutSplit`, `WorkoutSplitDay`, `PrescriptionChange`.

### Data Model File Index

### `VillainArc/Data/Models/Exercise/Exercise.swift`
- Does: Persisted exercise catalog row (name/muscles/equipment/favorite/last-used) plus normalized search metadata.
- Called by: `DataManager` seeding/dedupe, exercise picker/add/replace flows, session/plan model constructors.
- Calls: Search-token helpers (`exerciseSearchTokens`), fetch descriptors (`all`, `catalogExercises`).

### `VillainArc/Data/Models/Exercise/ExerciseCatalog.swift`
- Does: Static built-in exercise dataset (`all`) + lookup map (`byID`) + seed version (`catalogVersion`).
- Called by: `DataManager.seedExercisesIfNeeded`, `DataManager.dedupeCatalogExercisesIfNeeded`, `SampleData`.
- Calls: None (constant catalog data).

### `VillainArc/Data/Models/Exercise/RepRangePolicy.swift`
- Does: Reusable rep target/range policy object shared by performance and prescription models.
- Called by: `ExercisePerformance`, `ExercisePrescription`, `RepRangeEditorView`, suggestion engines.
- Calls: None (data and display text only).

### `VillainArc/Data/Models/Exercise/RestTimePolicy.swift`
- Does: Reusable rest policy (`allSame`, `individual`, `byType`) and per-set effective rest resolution.
- Called by: `ExercisePerformance`, `ExercisePrescription`, `RestTimeEditorView`, suggestion engines.
- Calls: `seconds(for:)` using `SetPerformance.type`.

### `VillainArc/Data/Models/Exercise/ExerciseHistory.swift`
- Does: Derived per-exercise analytics cache (PRs, recents, trends, progression points).
- Called by: `ExerciseHistoryUpdater`, `WorkoutSummaryView` (history/PR display), schema registration.
- Calls: `ExercisePerformance` metric helpers, internal recalculation helpers, `forCatalogID` descriptor.

### `VillainArc/Data/Models/Exercise/ProgressionPoint.swift`
- Does: One timeseries point (date/weight/volume) for `ExerciseHistory` charts.
- Called by: `ExerciseHistory.recalculate`, schema registration.
- Calls: None.

### `VillainArc/Data/Models/Sessions/PreWorkoutStatus.swift`
- Does: Session pre-checkin state (mood, pre-workout toggle, notes).
- Called by: `WorkoutSession.preStatus`, `PreWorkoutStatusView`, schema registration.
- Calls: None.

### `VillainArc/Data/Models/Sessions/WorkoutSession.swift`
- Does: Root workout runtime/completion aggregate (status, plan origin, exercises, finish workflow helpers).
- Called by: `AppRouter`, workout views, workout intents/entities, `SampleData`.
- Calls: `ExercisePerformance` constructors, session fetch descriptors, finish/prune helpers.

### `VillainArc/Data/Models/Sessions/ExercisePerformance.swift`
- Does: Per-exercise workout log entry with set rows and optional back-reference to originating plan prescription.
- Called by: `WorkoutView`, `ExerciseView`, suggestion engines, history updater, `SampleData`.
- Calls: `SetPerformance` constructors, rest helper (`effectiveRestSeconds`), descriptors (`lastCompleted`, `matching`, `completedAll`).

### `VillainArc/Data/Models/Sessions/SetPerformance.swift`
- Does: Per-set logged data (type, weight, reps, rest, completion metadata).
- Called by: `ExerciseSetRowView`, `ExerciseView`, suggestion engines/outcome rules, `SampleData`.
- Calls: Computed helpers (`effectiveRestSeconds`, `estimated1RM`, `volume`).

### `VillainArc/Data/Models/RestTimeHistory.swift`
- Does: Recent rest durations cache for rest-timer quick picks.
- Called by: `RestTimerView`, `ExerciseSetRowView`, rest timer intents (`StartRestTimerIntent`, `CompleteActiveSetIntent`).
- Calls: `record(seconds:context:)` with `ModelContext.fetch/insert`.

### `VillainArc/Data/Models/Plans/WorkoutPlan.swift`
- Does: Root workout-plan aggregate (metadata, exercises, split-day links, create-from-session path).
- Called by: plan views/picker/detail flows, split assignment flows, plan intents, `AppRouter`, `SampleData`.
- Calls: `ExercisePrescription` constructors, exercise reorder/reindex helpers, fetch descriptors (`all`, `recent`, `incomplete`).

### `VillainArc/Data/Models/Plans/WorkoutPlan+Editing.swift`
- Does: Editing-copy workflow (`createEditingCopy`, `finishEditing`, `cancelEditing`) + change detection/synchronization to original plan.
- Called by: `WorkoutPlanDetailView` (editing copy setup), `WorkoutPlanView` (save/cancel/delete flows).
- Calls: `PrescriptionChange` creation, pending-change override marking, set/exercise sync helpers, `SpotlightIndexer.deleteWorkoutPlan` (delete-entirely path).

### `VillainArc/Data/Models/Plans/ExercisePrescription.swift`
- Does: Per-exercise plan prescription (rep/rest policy, notes, set targets, pending changes).
- Called by: `WorkoutPlan`, `WorkoutSession` plan-start path, plan editors, suggestion engines.
- Calls: `SetPrescription` constructors/copy helpers, policy copy constructors.

### `VillainArc/Data/Models/Plans/SetPrescription.swift`
- Does: Per-set target prescription (type/target weight/reps/rest) with change links.
- Called by: `ExercisePrescription`, plan editors, suggestion engines, performance conversion.
- Calls: Constructors from `SetPerformance`, copy helpers, `RestTimeEditableSet` adapter.

### `VillainArc/Data/Models/Plans/PrescriptionChange.swift`
- Does: Persisted suggestion/change lifecycle record from generation through decision and post-workout outcome.
- Called by: `RuleEngine`, `WorkoutPlan+Editing`, `SuggestionReviewView`, `DeferredSuggestionsView`, `WorkoutSummaryView`, `OutcomeResolver`.
- Calls: None (data model only).

### `VillainArc/Data/Models/Plans/SuggestionGrouping.swift`
- Does: Grouping/query helpers for rendering and resolving plan suggestions (`groupSuggestions`, `pendingSuggestions`).
- Called by: `DeferredSuggestionsView`, `WorkoutSummaryView`.
- Calls: `ModelContext.fetch` for pending suggestion scans.

### `VillainArc/Data/Models/WorkoutSplit/WorkoutSplit.swift`
- Does: Split schedule aggregate (weekly/rotation state, day resolution, current-day advancement logic).
- Called by: split views, `StartTodaysWorkoutIntent`, `TrainingSummaryIntent`, `AppRouter` split routes, `SampleData`.
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
- Calls: Mappers between app enums (`Outcome`, `RestTimeMode`) and AI enums, snapshot builders from prescription/set models.

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
- `VillainArc/Data/Models/Enums/Exercise/ProgressionTrend.swift`: history trend states used by `ExerciseHistory`.
- `VillainArc/Data/Models/Enums/Exercise/RepRangeMode.swift`: rep-range mode enum used by `RepRangePolicy`.
- `VillainArc/Data/Models/Enums/Exercise/RestTimeMode.swift`: rest-policy mode enum used by `RestTimePolicy`.
- `VillainArc/Data/Models/Enums/Sessions/MoodLevel.swift`: pre-workout mood enum used by `PreWorkoutStatus`.
- `VillainArc/Data/Models/Enums/Sessions/SessionOrigin.swift`: session source enum (`plan`/`freeform`) used by `WorkoutSession`.
- `VillainArc/Data/Models/Enums/Sessions/SessionStatus.swift`: workout lifecycle enum (`pending`/`active`/`summary`/`done`) used by `WorkoutSession` and flow routing.
- `VillainArc/Data/Models/Enums/Sessions/PlanCreator.swift`: creator origin enum (`user`/`ai`) for plan provenance.
- `VillainArc/Data/Models/Enums/Suggestions/ChangeType.swift` + `ChangePolicy`: suggestion change taxonomy and grouping policy used by rules, review UI, and outcome logic.
- `VillainArc/Data/Models/Enums/Suggestions/Decision.swift`: user decision lifecycle for suggestions.
- `VillainArc/Data/Models/Enums/Suggestions/Outcome.swift`: post-workout suggestion outcome lifecycle.
- `VillainArc/Data/Models/Enums/Suggestions/SuggestionSource.swift`: suggestion provenance enum (`rules`/`ai`/`user`).
- `VillainArc/Data/Models/Enums/SplitMode.swift`: split schedule mode enum (`weekly`/`rotation`) used by `WorkoutSplit`.

## 5) Runtime Support Files

### `VillainArc/Data/Classes/RestTimerState.swift`
- Does: App-wide singleton rest timer state machine (run/pause/resume/stop/adjust) with persisted state and optional completion alert.
- Called by: `RestTimerView`, `ExerciseSetRowView`, `WorkoutView`, `AppRouter`, rest timer intents, live activity intents, and workout completion intents.
- Calls: `RestTimerNotifications.schedule/cancel`, `WorkoutActivityManager.update`, `UserDefaults` persistence, `AudioServicesPlayAlertSound`.

### `VillainArc/Data/LiveActivity/WorkoutActivityAttributes.swift`
- Does: ActivityKit attribute and content-state model for workout live activity UI.
- Called by: `WorkoutActivityManager`, `VillainArcWidgetExtension/VillainArcWidgetExtension.swift`.
- Calls: Internal state helpers (`isTimerRunning`, `isTimerPaused`, `hasActiveSet`).

### `VillainArc/Data/LiveActivity/WorkoutActivityManager.swift`
- Does: Live activity lifecycle manager (start/update/end/restore) for active workouts.
- Called by: `WorkoutView`, `ExerciseSetRowView`, `RestTimerView`, `RestTimerState`, workout/live-activity intents, `AppRouter`.
- Calls: `Activity.request/update/end`, `WorkoutActivityAttributes.ContentState` builder, `SharedModelContainer.container.mainContext`, `WorkoutSession.incomplete`.

### `VillainArc/Helpers/ExerciseSearch.swift`
- Does: Search scoring and tokenization helpers for exercise lookup (exact/prefix/phrase weighting).
- Called by: `FilteredExerciseListView`, `ExerciseEntityQuery`.
- Calls: `normalizedTokens`, `exerciseSearchTokens`, phrase/token scoring helpers.

### `VillainArc/Helpers/KeyboardDismiss.swift`
- Does: UIKit bridge helper to dismiss current keyboard focus from SwiftUI flows.
- Called by: `TextEntryEditorView`, `PreWorkoutStatusView`, `WorkoutPlanView`, and other text-entry screens.
- Calls: `UIApplication.shared.sendAction(...resignFirstResponder...)`.

### `VillainArc/Helpers/RestTimerNotifications.swift`
- Does: Local notification scheduler/canceler for rest timer completion reminders.
- Called by: `RestTimerState`.
- Calls: `UNUserNotificationCenter` auth/settings APIs, notification request creation.

### `VillainArc/Helpers/TextNormalization.swift`
- Does: Text normalization + fuzzy-match helpers (tokenization, max distance, Levenshtein distance).
- Called by: `ExerciseSearch` helpers and `ExerciseEntityQuery`.
- Calls: Internal string-distance/token utilities.

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

### `VillainArc/Intents/Workout/CancelWorkoutIntent.swift`
- Does: Cancels/deletes current incomplete workout session.
- Called by: Siri/Shortcuts, donation flow.
- Calls: `WorkoutSession.incomplete`, `RestTimerState.stop`, `saveContext`, `WorkoutActivityManager.end`, `AppRouter.activeWorkoutSession`.

### `VillainArc/Intents/Workout/FinishWorkoutIntent.swift`
- Does: Guided finish workflow for incomplete sets with choice prompts and finish actions.
- Called by: Siri/Shortcuts, donation flow.
- Calls: `WorkoutSession.finish`, `requestChoice`, `RestTimerState.stop`, `SpotlightIndexer.index(workoutSession:)`, `WorkoutActivityManager.end`, `OpenAppIntent`.

### `VillainArc/Intents/Workout/LastWorkoutSummaryIntent.swift`
- Does: Background summary dialog for most recent completed workout.
- Called by: Siri/Shortcuts, donation flow.
- Calls: `WorkoutSession.recent` fetch + `exerciseSummary`.

### `VillainArc/Intents/Workout/OpenWorkoutIntent.swift`
- Does: Opens selected completed workout detail route.
- Called by: Siri/Shortcuts, donations (`donateOpenWorkout`).
- Calls: `WorkoutSessionEntity` resolution fetch, `AppRouter.navigate(.workoutSessionDetail)`, `OpenAppIntent`.

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
- Does: Navigates app to workout history list.
- Called by: Siri/Shortcuts, donations (`donateShowWorkoutHistory`).
- Calls: `AppRouter.popToRoot`, `AppRouter.navigate(.workoutSessionsList)`.

### `VillainArc/Intents/Workout/TrainingSummaryIntent.swift`
- Does: Returns split-day training summary for requested day enum.
- Called by: Siri/Shortcuts, donations (`donateTrainingSummary`).
- Calls: `WorkoutSplit.active`, `splitDay(for:)`, plan/rest-day summary formatting.

### `VillainArc/Intents/Workout/ViewLastWorkoutIntent.swift`
- Does: Opens most recent completed workout detail screen.
- Called by: Siri/Shortcuts, donations (`donateViewLastWorkout`).
- Calls: `WorkoutSession.recent`, `AppRouter.navigate(.workoutSessionDetail)`, `OpenAppIntent`.

### `VillainArc/Intents/Workout/WorkoutSessionEntity.swift`
- Does: AppEntity + queries + transfer payload for workout sessions (used by Siri/Shortcuts/Spotlight).
- Called by: `OpenWorkoutIntent`, `SpotlightIndexer.associateAppEntity`, donation mapping, `userActivity` integration.
- Calls: `SharedModelContainer` queries, `WorkoutSession` mapping, JSON transfer encoding.

### `VillainArc/Intents/WorkoutPlan/CreateWorkoutPlanIntent.swift`
- Does: Opens create-plan flow with active-workout/plan guard checks.
- Called by: Siri/Shortcuts, donation flow.
- Calls: `WorkoutSession.incomplete`, `WorkoutPlan.incomplete`, `AppRouter.createWorkoutPlan`, `OpenAppIntent`.

### `VillainArc/Intents/WorkoutPlan/OpenWorkoutPlanIntent.swift`
- Does: Opens selected completed workout plan detail route.
- Called by: Siri/Shortcuts, donations (`donateOpenWorkoutPlan`).
- Calls: `WorkoutPlanEntity` resolution fetch, `AppRouter.navigate(.workoutPlanDetail)`, `OpenAppIntent`.

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
- Does: Navigates app to workout plans list.
- Called by: Siri/Shortcuts, donations (`donateShowWorkoutPlans`).
- Calls: `AppRouter.popToRoot`, `AppRouter.navigate(.workoutPlansList)`.

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
- Calls: `DataManager.dedupeCatalogExercisesIfNeeded`, `WorkoutSession.addExercise`/`WorkoutPlan.addExercise`, `SpotlightIndexer.index(exercise:)`, `WorkoutActivityManager.update`.

### `VillainArc/Intents/Exercise/AddExercisesIntent.swift`
- Does: Adds multiple selected exercises to active workout or active editing plan.
- Called by: Siri/Shortcuts, donations (`donateAddExercises`).
- Calls: Exercise resolution fetch, add/update/index/save helpers.

### `VillainArc/Intents/Exercise/ExerciseEntity.swift`
- Does: AppEntity + queries + fuzzy search support for exercise selection in intents.
- Called by: Exercise intents, `SpotlightIndexer.associateAppEntity`, donations.
- Calls: `ExerciseSearch` + `TextNormalization` helpers, `SharedModelContainer` queries.

### `VillainArc/Intents/Exercise/ReplaceExerciseIntent.swift`
- Does: Replaces active workout exercise, optionally preserving sets.
- Called by: Siri/Shortcuts, donations (`donateReplaceExercise`).
- Calls: `requestChoice`, `ExercisePerformance.replaceWith`, `SpotlightIndexer.index(exercise:)`, `WorkoutActivityManager.update`.

### `VillainArc/Intents/Exercise/ToggleExerciseFavoriteIntent.swift`
- Does: Toggles favorite status for a selected exercise.
- Called by: Siri/Shortcuts/App Intent execution, donations (`donateToggleExerciseFavorite`).
- Calls: `ExerciseEntity` resolution fetch, `Exercise.toggleFavorite`, `SpotlightIndexer.index(exercise:)` (when favorited), `saveContext`.

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
- Does: Live-activity action to complete current set and optionally start rest timer.
- Called by: Widget live activity buttons.
- Calls: `WorkoutSession.incomplete`, set completion mutation, `RestTimerState.start`, `WorkoutActivityManager.update`.

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

### `VillainArcTests/TestSupport/TestDataFactory.swift`
- Does: Shared test-only factory helpers for creating model contexts, plans, sessions, and performances.
- Called by: `SuggestionSystemTests`.
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

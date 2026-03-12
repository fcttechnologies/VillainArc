# VillainArc Project Guide

> Give this file to any AI agent to understand the entire project.
> For the full file-by-file index, see ARCHITECTURE.md.
> For the suggestion engine deep dive, see WORKOUT_PLAN_SUGGESTION_FLOW.md.
> For session lifecycle details, see SESSION_LIFECYCLE_FLOW.md.
> For plan editing mechanics, see PLAN_EDITING_FLOW.md.
> For exercise history system, see EXERCISE_HISTORY_FLOW.md.

## What Is VillainArc?

A gym workout tracking iOS app built with SwiftUI + SwiftData. Users plan workouts, log sets/reps/weight in real-time, track progression, and get AI-powered suggestions to improve their training. The app integrates deeply with iOS (Siri, Shortcuts, Live Activities, Spotlight, iCloud sync).

**Tech stack:** Swift, SwiftUI, SwiftData (CloudKit-backed), ActivityKit, AppIntents, CoreSpotlight, Foundation Models (on-device AI).

---

## How Users Use the App

### First Launch (Onboarding)
1. App checks WiFi, iCloud, CloudKit availability
2. Syncs any existing data from iCloud
3. Seeds exercise catalog (200+ built-in exercises)
4. Collects user profile: name, birthday, height
5. Drops user onto home screen

### Home Screen
Four sections: **Splits** (today's schedule), **Recent Workout** (last completed), **Recent Plan** (last used plan), and **Exercises** (most recently used exercises). Plus a "+" menu to start a workout or create a plan.

### Core User Flows

**Freeform Workout:** Start empty workout > add exercises > log sets (reps/weight) > mark sets complete > finish > review summary > done.

**Plan-Based Workout:** Open plan > "Start Workout" > review pending suggestions (accept/reject/defer) > log sets with target references > finish > system generates new suggestions > review > done.

**Creating a Plan:** "Create Plan" > add exercises from catalog > set rep ranges, rest times, target weight/reps per set > save. Plans can also be created from completed workouts ("Save as Plan").

**Editing a Plan:** Open plan > "Edit" > creates a temporary editing copy > make changes > "Done" applies changes back to original atomically, reconciling any pending suggestions.

**Training Splits:** Create a split (PPL, Upper/Lower, etc.) > assign plans to each day > split tracks which day you're on (weekly or rotation mode) > home screen shows "today's workout."

**Rest Timer:** Auto-starts after completing a set (configurable). Runs globally, persists across views, survives app kills. Shows on lock screen via Live Activity.

**Suggestion Cycle:** After a plan-based workout, the rule engine + optional AI analyze your performance and suggest changes (increase weight, adjust reps, modify rest times). You review these before your next workout. After that workout, the system evaluates whether the suggestions worked (good/too aggressive/too easy/ignored).

### Flow Invariants

- If an unfinished workout session exists at launch, the app immediately resumes it in the full-screen workout flow. The user cannot start another workout or workout-plan flow until that session is finished or canceled.
- If no unfinished workout exists but an incomplete non-editing workout plan exists, the app resumes that plan in the full-screen plan editor. The user stays in that flow until the plan is saved/completed or canceled.
- `AppRouter` enforces a single active flow across the app: at most one workout session or one workout plan can be active at a time, never both.
- `ExercisePerformance` and `ExercisePrescription` are initialized with at least one set. The editing UI only exposes set deletion when more than one set remains.
- Built-in exercise catalog metadata is canonical for `name`, `musclesTargeted`, and `equipmentType`. When catalog seeding updates those fields, matching `ExercisePrescription` and `ExercisePerformance` snapshots are refreshed by `catalogID`.
- Finishing a workout resolves incomplete sets before summary: logged unfinished sets can be marked complete, unfinished sets can be deleted, and any exercise left with zero sets is pruned. If every exercise is pruned, the workout itself is deleted instead of reaching summary.
- `Exercise.lastAddedAt` tracks catalog-selection recency for add/replace flows. `ExerciseHistory.lastCompletedAt` tracks actual completed-workout recency for user-facing "used" ordering. When the last completed performance is removed, the history record is deleted and the exercise is removed from Spotlight.

---

## Architecture Overview

```
VillainArcApp (@main)
  └─ ContentView (NavigationStack + home sections)
       ├─ Stack destinations: WorkoutsListView, WorkoutDetailView,
       │   WorkoutPlansListView, WorkoutPlanDetailView,
       │   ExercisesListView, ExerciseDetailView,
       │   ExerciseHistoryView, WorkoutSplitView
       ├─ Full-screen cover: WorkoutSessionContainer (active workout)
       │   └─ Routes by status: DeferredSuggestionsView (.pending)
       │       → WorkoutView (.active) → WorkoutSummaryView (.summary/.done)
       └─ Full-screen cover: WorkoutPlanView (plan editing)
```

**AppRouter** (singleton, `@Observable`): Owns `NavigationPath`, `activeWorkoutSession`, `activeWorkoutPlan`. Enforces one active flow at a time, auto-resumes unfinished workout sessions first, then resumable incomplete plans, and blocks Spotlight/Siri/new-flow entry points while a flow is already active.

**SharedModelContainer**: SwiftData container with 17 model types, CloudKit-backed, app-group store.

**Data flow:** Views use `@Query` for reads, `@Bindable` for mutations, `saveContext()`/`scheduleSave()` for persistence. No separate view model layer.

---

## Data Model

### Entity Relationships
```
Exercise (catalog)
  ├─ used to create → ExercisePerformance (in session)
  └─ used to create → ExercisePrescription (in plan)

AppSettings (singleton)
  └─ stores → app-wide workout/timer/live-activity preferences

WorkoutPlan (blueprint)
  ├─ owns → ExercisePrescription[] → SetPrescription[]
  ├─ assigned to → WorkoutSplitDay[]
  └─ creates → WorkoutSession (when started)

WorkoutSession (actual workout)
  ├─ owns → ExercisePerformance[] → SetPerformance[]
  ├─ has one → PreWorkoutContext
  ├─ links back to → WorkoutPlan (if plan-based)
  ├─ generates → PrescriptionChange[] (via createdPrescriptionChanges)
  └─ evaluates → PrescriptionChange[] (via evaluatedPrescriptionChanges)

WorkoutSplit (schedule)
  └─ owns → WorkoutSplitDay[] → each references one WorkoutPlan

PrescriptionChange (suggestion)
  ├─ source: which performance triggered it
  ├─ target: which prescription to change
  ├─ decision: pending/accepted/rejected/deferred/userOverride
  └─ outcome: pending/good/tooAggressive/tooEasy/ignored/userModified

ExerciseHistory (analytics cache)
  └─ owns → ProgressionPoint[] (weight/volume/estimated-1RM charting data)
```

### Session Status Lifecycle
`pending` (has deferred suggestions to review) → `active` (logging workout) → `summary` (reviewing stats/suggestions) → `done` (locked).

### Plan Editing Pattern
Never edit the original directly. `createEditingCopy()` makes a temporary clone. User edits the clone. `applyEditingCopy()` merges changes back, marking conflicting suggestions as `userOverride`.

---

## Feature → File Map

Use this to find where logic lives for any feature.

### Starting/Finishing Workouts
| What | Where |
|------|-------|
| Start empty workout | `Data/Services/AppRouter.swift` → `startWorkoutSession()` |
| Start from plan | `Data/Services/AppRouter.swift` → `startWorkoutSession(from:)` |
| Single active flow guard | `Data/Services/AppRouter.swift` → `hasActiveFlow()` |
| Active workout UI | `Views/Workout/WorkoutView.swift` |
| Per-exercise logging | `Views/Workout/ExerciseView.swift` |
| Set row (reps/weight input) | `Views/Components/ExerciseSetRowView.swift` |
| Finish logic (incomplete-set resolution + pruning) | `Data/Models/Sessions/WorkoutSession.swift` → `finish()` |
| Post-workout summary | `Views/Workout/WorkoutSummaryView.swift` |
| Resume unfinished workout / plan on launch | `Data/Services/AppRouter.swift` → `checkForUnfinishedData()` |
| Workout status routing | `Views/Workout/WorkoutSessionContainer.swift` |
| Pre-workout context (mood/notes) | `Views/Workout/PreWorkoutContextView.swift` |
| Workout settings | `Views/Workout/WorkoutSettingsView.swift` |
| Intent-driven workout sheet routing | `Data/Services/AppRouter.swift` + `Views/Workout/WorkoutView.swift` + `Intents/Workout/OpenActiveWorkoutIntent.swift` / `OpenPreWorkoutContextIntent.swift` / `OpenRestTimerIntent.swift` / `OpenWorkoutSettingsIntent.swift` |

### Workout Plans
| What | Where |
|------|-------|
| Create/edit plan UI | `Views/WorkoutPlan/WorkoutPlanView.swift` |
| Plan detail (read-only) | `Views/WorkoutPlan/WorkoutPlanDetailView.swift` |
| Plan list | `Views/WorkoutPlan/WorkoutPlansListView.swift` |
| Plan picker (for splits) | `Views/WorkoutPlan/WorkoutPlanPickerView.swift` |
| Editing copy workflow | `Data/Models/Plans/WorkoutPlan+Editing.swift` |
| Intent-driven plan edit flow | `Data/Services/AppRouter.swift` + `Views/ContentView.swift` + `Intents/WorkoutPlan/EditWorkoutPlanIntent.swift` |
| Resumable incomplete plan query | `Data/Models/Plans/WorkoutPlan.swift` → `resumableIncomplete` |
| Plan model | `Data/Models/Plans/WorkoutPlan.swift` |
| Exercise prescription | `Data/Models/Plans/ExercisePrescription.swift` |
| Set prescription (weight/reps/rest/target RPE) | `Data/Models/Plans/SetPrescription.swift` |

### Training Splits
| What | Where |
|------|-------|
| Split editor (main screen, active split) | `Views/WorkoutSplit/WorkoutSplitView.swift` |
| Split list sheet (all splits management) | `Views/WorkoutSplit/WorkoutSplitListView.swift` |
| Split builder (presets) | `Views/WorkoutSplit/SplitBuilderView.swift` |
| Per-day editor | `Views/WorkoutSplit/WorkoutSplitDayView.swift` |
| Split model | `Data/Models/WorkoutSplit/WorkoutSplit.swift` |
| Split day model | `Data/Models/WorkoutSplit/WorkoutSplitDay.swift` |
| Split entity + transfer payload | `Intents/WorkoutSplit/WorkoutSplitEntity.swift` |
| Today's workout logic | `WorkoutSplit.todaysSplitDay` / `todaysWorkoutPlan` |
| Rotation advancement | `WorkoutSplit.refreshRotationIfNeeded()` |

### Suggestion Engine
| What | Where |
|------|-------|
| Entry point | `Data/Services/Suggestions/SuggestionGenerator.swift` |
| Deterministic rules (15 rules) | `Data/Services/Suggestions/RuleEngine.swift` |
| Training style detection | `Data/Services/Suggestions/MetricsCalculator.swift` |
| Conflict resolution | `Data/Services/Suggestions/SuggestionDeduplicator.swift` |
| Post-workout outcome eval | `Data/Services/Suggestions/OutcomeResolver.swift` |
| Outcome scoring | `Data/Services/Suggestions/OutcomeRuleEngine.swift` |
| AI style classifier | `Data/Services/Suggestions/AITrainingStyleClassifier.swift` |
| AI outcome evaluator | `Data/Services/Suggestions/AIOutcomeInferrer.swift` |
| Foundation model prewarm | `Data/Services/Suggestions/FoundationModelPrewarmer.swift` |
| AI tool (history access) | `Data/Services/Suggestions/AITrainingStyleTools.swift` |
| Suggestion model | `Data/Models/Plans/PrescriptionChange.swift` |
| Grouping/query helpers | `Data/Models/Plans/SuggestionGrouping.swift` |
| Pre-workout review UI | `Views/Suggestions/DeferredSuggestionsView.swift` |
| Shared review component | `Views/Suggestions/SuggestionReviewView.swift` |

### Exercise System
| What | Where |
|------|-------|
| Exercise catalog model | `Data/Models/Exercise/Exercise.swift` |
| Built-in exercise data | `Data/Models/Exercise/ExerciseCatalog.swift` |
| Search/scoring | `Helpers/ExerciseSearch.swift` |
| Fuzzy matching | `Helpers/TextNormalization.swift` |
| Add exercise sheet | `Views/Workout/AddExerciseView.swift` |
| Searchable list | `Views/Workout/FilteredExerciseListView.swift` |
| Replace exercise | `Views/Workout/ReplaceExerciseView.swift` |
| Muscle filter | `Views/Workout/Editors/MuscleFilterSheetView.swift` |
| Home exercise section | `Views/HomeSections/RecentExercisesSectionView.swift` |
| Exercises list (search + favorites filter/toggle) | `Views/Exercise/ExercisesListView.swift` |
| Exercise detail / progress UI | `Views/Exercise/ExerciseDetailView.swift` |
| Exercise performance history UI | `Views/Exercise/ExerciseHistoryView.swift` |
| Contextual workout/plan history sheet entry point | `Views/Exercise/ExerciseHistoryView.swift` initializers |
| Exercise history stats + cached progress metrics | `Data/Models/Exercise/ExerciseHistory.swift` |
| Exercise navigation/history intents | `Intents/Exercise/ViewLastUsedExerciseIntent.swift` + `Intents/Exercise/ShowExerciseHistoryIntent.swift` + `Intents/Exercise/OpenExerciseIntent.swift` |
| History rebuild | `Data/Services/ExerciseHistoryUpdater.swift` |
| Exercise Spotlight eligibility | `Data/Services/ExerciseHistoryUpdater.swift` + `Data/Services/SpotlightIndexer.swift` |
| Catalog metadata propagation into plan/workout snapshots | `Data/Services/DataManager.swift` → `syncExerciseSnapshots()` |
| Rep range policy | `Data/Models/Exercise/RepRangePolicy.swift` |
| Rep range editor | `Views/Workout/Editors/RepRangeEditorView.swift` |
| Rest time editor | `Views/Workout/Editors/RestTimeEditorView.swift` |

### Rest Timer
| What | Where |
|------|-------|
| State machine (singleton) | `Data/Services/RestTimerState.swift` |
| Timer UI | `Views/Workout/RestTimerView.swift` |
| Notifications | `Helpers/RestTimerNotifications.swift` |
| Recent durations | `Data/Models/RestTimeHistory.swift` |
| Auto-start on set complete | `Views/Components/ExerciseSetRowView.swift` |
| Workout timer/live-activity preferences UI | `Views/Workout/WorkoutSettingsView.swift` |
| Workout timer/live-activity preferences data | `Data/Models/AppSettings.swift` + `Data/Services/SystemState.swift` |

### Siri / Shortcuts / Intents
| What | Where |
|------|-------|
| Shortcut registration | `Intents/VillainArcShortcuts.swift` |
| Donation hub | `Intents/IntentDonations.swift` |
| Workout intents | `Intents/Workout/*.swift` (16 files) |
| Workout split intents + entity | `Intents/WorkoutSplit/*.swift` (7 files) |
| Plan intents | `Intents/WorkoutPlan/*.swift` (10 files) |
| Exercise intents | `Intents/Exercise/*.swift` (9 files) |
| Rest timer intents | `Intents/RestTimer/*.swift` (7 files) |
| Legacy SiriKit | `VillainArcIntentsExtension/*.swift` |

### Live Activities
| What | Where |
|------|-------|
| Attributes/state model | `Data/LiveActivity/WorkoutActivityAttributes.swift` |
| Lifecycle manager | `Data/LiveActivity/WorkoutActivityManager.swift` |
| Widget UI | `VillainArcWidgetExtension/VillainArcWidgetExtension.swift` |
| Lock screen intents | `Intents/LiveActivity/*.swift` (4 files) |

### Spotlight Search
| What | Where |
|------|-------|
| Index/delete | `Data/Services/SpotlightIndexer.swift` |
| Spotlight routing (workouts, plans, exercises) | `Data/Services/AppRouter.swift` → `handleSpotlight()` |
| Entity associations | `Intents/Workout/WorkoutSessionEntity.swift`, `Intents/WorkoutPlan/WorkoutPlanEntity.swift`, `Intents/Exercise/ExerciseEntity.swift`, `Intents/WorkoutSplit/WorkoutSplitEntity.swift` |

### Onboarding & Setup
| What | Where |
|------|-------|
| Onboarding state machine | `Data/Services/OnboardingManager.swift` |
| Setup guard (gate) | `Data/Services/SetupGuard.swift` |
| System singleton bootstrap | `Data/Services/SystemState.swift` |
| Onboarding UI | `Views/Onboarding/OnboardingView.swift` |
| User profile model | `Data/Models/UserProfile.swift` |
| App settings model | `Data/Models/AppSettings.swift` |
| iCloud check | `Helpers/CloudKitStatusChecker.swift` |
| Network check | `Helpers/NetworkMonitor.swift` |

### Shared UI Components
| What | Where |
|------|-------|
| Navigation bar helpers | `Views/Components/Navbar.swift` |
| Text editor sheet | `Views/Components/TextEntryEditorView.swift` |
| Timer duration picker | `Views/Components/TimerDurationPicker.swift` |
| Exercise summary row | `Views/Components/ExerciseSummaryRow.swift` |
| Summary stat card | `Views/Components/SummaryStatCard.swift` |
| Section header button | `Views/HomeSections/HomeSectionHeaderButton.swift` |
| Empty state | `Views/Components/SmallUnavailableView.swift` |
| Workout card row | `Views/Components/WorkoutRowView.swift` |
| Plan card (display) | `Views/Components/WorkoutPlanCardView.swift` |
| Plan row (navigable) | `Views/Components/WorkoutPlanRowView.swift` |
| RPE badge (compact) | `Views/Components/RPEBadge.swift` |

### Utilities
| What | Where |
|------|-------|
| Persistence helpers | `Data/Services/DataManager.swift` → `saveContext()`, `scheduleSave()` |
| Exercise catalog seeding | `Data/Services/DataManager.swift` → `seedExercisesIfNeeded()` |
| Exercise snapshot metadata sync | `Data/Services/DataManager.swift` → `syncExerciseSnapshots()` |
| Haptic feedback | `Helpers/Haptics.swift` |
| Time formatting | `Helpers/TimeFormatting.swift` |
| Keyboard dismiss | `Helpers/KeyboardDismiss.swift` |
| Accessibility IDs | `Helpers/Accessibility.swift` |
| Sample/preview data | `Data/SampleData.swift` |
| Workout effort formatting | `Helpers/WorkoutEffortFormatting.swift` |

---

## Suggestion Engine Summary

> For the full implementation details, see `Documentation/WORKOUT_PLAN_SUGGESTION_FLOW.md`.

The suggestion system is a closed-loop learning pipeline:

**Generation + Outcome Resolution** (during summary screen): When `WorkoutSummaryView` appears, it runs in sequence: (1) `OutcomeResolver` evaluates older suggestions against the just-finished workout, then (2) `SuggestionGenerator` detects training style (deterministic via `MetricsCalculator`, with `AITrainingStyleClassifier` as fallback for `.unknown`) → `RuleEngine` evaluates 15 rules across 4 buckets (progression, safety/cleanup, plateau, set-type hygiene) → `SuggestionDeduplicator` resolves conflicts → produces `PrescriptionChange` records.

**Review — two stages:**
- *Immediately after workout* (`WorkoutSummaryView`): user can accept, reject, or defer newly generated suggestions. Any still-pending at dismissal are auto-converted to `deferred`.
- *Before next plan workout* (`DeferredSuggestionsView`): deferred/pending suggestions from prior sessions are reviewed before the workout begins. Accepting mutates the live plan immediately.

**Outcome Evaluation**: `OutcomeRuleEngine` scores deterministically for both accepted *and* rejected suggestions (rejected are evaluated to detect whether the user effectively followed them anyway). `AIOutcomeInferrer` overrides only when rule confidence < 0.7 AND AI confidence >= 0.75.

**Key rules:** Progression — immediate (1 session: large overshoot, hit top of range/target) or confirmed (2 sessions near top). Safety — weight decreases when struggling or when the user consistently trains lighter. Plateau — rest increases when stagnating or short-rest causes rep drops. Set-type hygiene — fixes misclassified warmup/working/drop sets.

---

## Key Patterns & Conventions

1. **AppRouter singleton** manages all navigation. Views call `AppRouter.shared.navigate(to:)` or set `activeWorkoutSession`/`activeWorkoutPlan` for full-screen flows.

2. **One active flow at a time.** Can't start a workout if one is active. Can't edit a plan if one is being edited. `hasActiveFlow()` enforces this.

3. **SwiftData direct.** No view model layer. Views use `@Query` for reads, `@Bindable` for writes, `saveContext()`/`scheduleSave()` for persistence.

4. **Editing copy pattern** for plans. Never modify the original directly. Create copy, edit, apply back atomically.

5. **Rest timer is global.** `RestTimerState.shared` persists to UserDefaults. Survives app kills. Syncs with Live Activity.

6. **Exercise history is rebuilt from scratch** after each workout. `ExerciseHistory.recalculate()` recomputes all stats from all performances. Safe but not incremental.

7. **Suggestions link source evidence to targets.** Each `PrescriptionChange` has both `sourceExercisePerformance` (what triggered it) and `targetSetPrescription` (what to change).

8. **Intent donations** happen at contextually relevant moments (e.g., donate "Start Rest Timer" when a set is completed).

9. **Accessibility-first.** Centralized `AccessibilityIdentifiers` and `AccessibilityText` in `Helpers/Accessibility.swift`. 365+ IDs defined.

10. **All dates/times** formatted through `Helpers/TimeFormatting.swift`.

---

## Common Tasks Guide

### "I want to add a new screen"
1. Create view in appropriate `Views/` subfolder
2. Add navigation destination enum case to `AppRouter.Destination`
3. Add `case` handler in `ContentView`'s `navigationDestination(for:)`
4. Navigate via `AppRouter.shared.navigate(to: .yourDestination)`

### "I want to add a new data model"
1. Create `@Model` class in `Data/Models/`
2. Add to `SharedModelContainer.schema` array
3. Create a SwiftData `VersionedSchema` migration if modifying existing models

### "I want to add a new exercise property"
1. Add property to `Exercise.swift` (catalog), `ExercisePerformance.swift` (session), and/or `ExercisePrescription.swift` (plan)
2. Update `ExerciseCatalog.swift` if it's a catalog-level property
3. Update `DataManager.seedExercisesIfNeeded()` if it needs seeding

### "I want to add a new suggestion rule"
1. Add rule method to `Data/Services/Suggestions/RuleEngine.swift`
2. Call it from `evaluate()` in the appropriate priority section
3. Add test in `VillainArcTests/SuggestionSystemTests.swift`
4. Update `WORKOUT_PLAN_SUGGESTION_FLOW.md`

### "I want to add a Siri shortcut"
1. Create intent in `Intents/` appropriate subfolder
2. Add donation method to `IntentDonations.swift`
3. Call donation from relevant UI flow
4. Optionally register in `VillainArcShortcuts.swift` for discoverability

### "Something is broken with workout logging"
Look at: `WorkoutView.swift` (overall), `ExerciseView.swift` (per-exercise), `ExerciseSetRowView.swift` (per-set), `SetPerformance.swift` (data model).

### "Something is broken with suggestions"
Look at: `SuggestionGenerator.swift` (generation), `RuleEngine.swift` (rules), `PrescriptionChange.swift` (model), `SuggestionReviewView.swift` (UI), `OutcomeResolver.swift` (evaluation).

### "Something is broken with the rest timer"
Look at: `RestTimerState.swift` (state machine), `RestTimerView.swift` (UI), `RestTimerNotifications.swift` (notifications), `ExerciseSetRowView.swift` (auto-start trigger).

### "Something is broken with splits"
Look at: `WorkoutSplit.swift` (model + day resolution), `WorkoutSplitView.swift` (main editor, active split), `WorkoutSplitListView.swift` (all-splits sheet).

---

## Enums Reference

| Enum | Cases | Used For |
|------|-------|----------|
| `SessionStatus` | pending, active, summary, done | Workout lifecycle |
| `Origin` | user, plan, session, ai | Provenance for plans and sessions |
| `ExerciseSetType` | warmup, working, dropSet | Set classification |
| `RepRangeMode` | notSet, target, range | Rep goal strategy |
| `MoodLevel` | notSet, sick, tired, okay, good, great | Pre-workout feeling |
| `SplitMode` | weekly, rotation | Schedule type |
| `ChangeType` | 14 variants (weight/reps/rest/setType/repRange changes) | What a suggestion modifies |
| `Decision` | pending, accepted, rejected, deferred, userOverride | User's choice on suggestion |
| `Outcome` | pending, good, tooAggressive, tooEasy, ignored, userModified | How suggestion played out |
| `TrainingStyle` | straightSets, ascending, descendingPyramid, ascendingPyramid, topSetBackoffs, unknown | Detected exercise pattern |
| `SuggestionSource` | rules, ai, user | Where suggestion came from |
| `Muscle` | 36 variants (10 major, 26 minor) | Muscle targeting |
| `EquipmentType` | 18 variants | Equipment classification |

---

## Test Coverage

**43 tests across 7 files:**
- Plan editing & suggestion lifecycle (14 tests)
- Workout finish logic (11 tests)
- Suggestion system / training style (10 tests)
- Exercise replacement (3 tests)
- Spotlight summaries (2 tests)
- Exercise entity search / alternate names (2 tests)
- Exercise history rep metrics (1 test)

**Notable gaps:** No tests for RuleEngine individual rules, OutcomeRuleEngine evaluation, WorkoutSplit logic, RestTimerState, UI views, or onboarding flow.

---

## File Structure

```
VillainArc/
  Root/                          App entry point
  Resources/                     Asset catalogs (app icon, accent color)
  Views/
    ContentView.swift            Home screen (NavigationStack root)
    Onboarding/                  First-run onboarding UI
    HomeSections/                Home screen section views (5 files)
    Exercise/                    Exercise list, detail, and history surfaces
    Workout/                     Active workout views (11 files)
      Editors/                   Shared editors: RepRange, RestTime, MuscleFilter
    History/                     Workout history list
    WorkoutPlan/                 Plan CRUD views (4 files)
    WorkoutSplit/                Split management views (4 files)
    Suggestions/                 Suggestion review UI (2 files)
    Components/                  Reusable UI components (12 files)
  Data/
    SharedModelContainer.swift   SwiftData schema + container
    SampleData.swift             Preview fixtures
    Services/                    Service/coordinator classes
      AppRouter.swift            Navigation coordinator (singleton)
      DataManager.swift          Catalog seeding + snapshot sync + save helpers
      OnboardingManager.swift    First-run state machine
      SetupGuard.swift           Intent pre-condition guard
      SystemState.swift          Singleton bootstrap + settings migration helper
      RestTimerState.swift       Global rest timer (singleton)
      SpotlightIndexer.swift     CoreSpotlight integration
      ExerciseHistoryUpdater.swift  Analytics rebuild
      Suggestions/               Suggestion engine (10 files)
    Models/
      Sessions/                  WorkoutSession, ExercisePerformance, SetPerformance, PreWorkoutContext
      Plans/                     WorkoutPlan, ExercisePrescription, SetPrescription, PrescriptionChange, SuggestionGrouping, WorkoutPlan+Editing
      Exercise/                  Exercise, ExerciseCatalog, ExerciseHistory, ProgressionPoint, RepRangePolicy, RestTimeDefaults
      WorkoutSplit/              WorkoutSplit, WorkoutSplitDay
      AIModels/                  Shared AI snapshots + feature-specific inference/outcome DTOs
      Enums/                     All domain enums (14 files)
      AppSettings.swift
      UserProfile.swift
      RestTimeHistory.swift
    LiveActivity/                ActivityKit attributes + manager
    Protocols/                   RestTimeEditable protocol
  Intents/                       App Intents for Siri/Shortcuts (56 files)
    Workout/                     Workout session/history intents + entity
    WorkoutSplit/                Split navigation/start/summary intents + entity
    WorkoutPlan/                 Workout plan intents + entity
    Exercise/                    Exercise intents + entity
    RestTimer/                   Rest timer intents + snippet UI
    LiveActivity/                Live Activity control intents
  Helpers/                       Utility functions (10 files)
  Documentation/                 This file + ARCHITECTURE.md + flow docs (7 files)

VillainArcWidgetExtension/       Live Activity widget UI
VillainArcIntentsExtension/      Legacy SiriKit handlers
VillainArcTests/                 Test suite (8 test files + 3 support files)
```

# VillainArc Project Guide

> Give this file to any AI agent to understand the entire project.
> For the full file-by-file index, see ARCHITECTURE.md.
> For the suggestion engine deep dive, see WORKOUT_PLAN_SUGGESTION_FLOW.md.

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
Three sections: **Splits** (today's schedule), **Recent Workout** (last completed), **Recent Plan** (last used plan). Plus a "+" menu to start a workout or create a plan.

### Core User Flows

**Freeform Workout:** Start empty workout > add exercises > log sets (reps/weight) > mark sets complete > finish > review summary > done.

**Plan-Based Workout:** Open plan > "Start Workout" > review pending suggestions (accept/reject/defer) > log sets with target references > finish > system generates new suggestions > review > done.

**Creating a Plan:** "Create Plan" > add exercises from catalog > set rep ranges, rest times, target weight/reps per set > save. Plans can also be created from completed workouts ("Save as Plan").

**Editing a Plan:** Open plan > "Edit" > creates a temporary editing copy > make changes > "Done" applies changes back to original atomically, reconciling any pending suggestions.

**Training Splits:** Create a split (PPL, Upper/Lower, etc.) > assign plans to each day > split tracks which day you're on (weekly or rotation mode) > home screen shows "today's workout."

**Rest Timer:** Auto-starts after completing a set (configurable). Runs globally, persists across views, survives app kills. Shows on lock screen via Live Activity.

**Suggestion Cycle:** After a plan-based workout, the rule engine + optional AI analyze your performance and suggest changes (increase weight, adjust reps, modify rest times). You review these before your next workout. After that workout, the system evaluates whether the suggestions worked (good/too aggressive/too easy/ignored).

---

## Architecture Overview

```
VillainArcApp (@main)
  └─ ContentView (NavigationStack + home sections)
       ├─ Stack destinations: WorkoutsListView, WorkoutDetailView,
       │   WorkoutPlansListView, WorkoutPlanDetailView,
       │   WorkoutSplitView, WorkoutSplitCreationView
       ├─ Full-screen cover: WorkoutSessionContainer (active workout)
       │   └─ Routes by status: DeferredSuggestionsView (.pending)
       │       → WorkoutView (.active) → WorkoutSummaryView (.summary/.done)
       └─ Full-screen cover: WorkoutPlanView (plan editing)
```

**AppRouter** (singleton, `@Observable`): Owns `NavigationPath`, `activeWorkoutSession`, `activeWorkoutPlan`. Enforces one active flow at a time. Handles Spotlight/Siri routing. Auto-resumes incomplete workouts on launch.

**SharedModelContainer**: SwiftData container with 16 model types, CloudKit-backed, app-group store.

**Data flow:** Views use `@Query` for reads, `@Bindable` for mutations, `saveContext()`/`scheduleSave()` for persistence. No separate view model layer.

---

## Data Model

### Entity Relationships
```
Exercise (catalog)
  ├─ used to create → ExercisePerformance (in session)
  └─ used to create → ExercisePrescription (in plan)

WorkoutPlan (blueprint)
  ├─ owns → ExercisePrescription[] → SetPrescription[]
  ├─ assigned to → WorkoutSplitDay[]
  └─ creates → WorkoutSession (when started)

WorkoutSession (actual workout)
  ├─ owns → ExercisePerformance[] → SetPerformance[]
  ├─ has one → PreWorkoutStatus
  └─ links back to → WorkoutPlan (if plan-based)

WorkoutSplit (schedule)
  └─ owns → WorkoutSplitDay[] → each references one WorkoutPlan

PrescriptionChange (suggestion)
  ├─ source: which performance triggered it
  ├─ target: which prescription to change
  ├─ decision: pending/accepted/rejected/deferred/userOverride
  └─ outcome: pending/good/tooAggressive/tooEasy/ignored/userModified

ExerciseHistory (analytics cache)
  └─ owns → ProgressionPoint[] (charting data)
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
| Active workout UI | `Views/Workout/WorkoutView.swift` |
| Per-exercise logging | `Views/Workout/ExerciseView.swift` |
| Set row (reps/weight input) | `Views/Components/ExerciseSetRowView.swift` |
| Finish logic (set cleanup) | `Data/Models/Sessions/WorkoutSession.swift` → `finish()` |
| Post-workout summary | `Views/Workout/WorkoutSummaryView.swift` |
| Resume after app kill | `Data/Services/AppRouter.swift` → `checkForUnfinishedData()` |
| Workout status routing | `Views/Workout/WorkoutSessionContainer.swift` |

### Workout Plans
| What | Where |
|------|-------|
| Create/edit plan UI | `Views/WorkoutPlan/WorkoutPlanView.swift` |
| Plan detail (read-only) | `Views/WorkoutPlan/WorkoutPlanDetailView.swift` |
| Plan list | `Views/WorkoutPlan/WorkoutPlansListView.swift` |
| Plan picker (for splits) | `Views/WorkoutPlan/WorkoutPlanPickerView.swift` |
| Editing copy workflow | `Data/Models/Plans/WorkoutPlan+Editing.swift` |
| Plan model | `Data/Models/Plans/WorkoutPlan.swift` |
| Exercise prescription | `Data/Models/Plans/ExercisePrescription.swift` |
| Set prescription | `Data/Models/Plans/SetPrescription.swift` |

### Training Splits
| What | Where |
|------|-------|
| Split management | `Views/WorkoutSplit/WorkoutSplitView.swift` |
| Split builder (presets) | `Views/WorkoutSplit/SplitBuilderView.swift` |
| Split detail editor | `Views/WorkoutSplit/WorkoutSplitCreationView.swift` |
| Per-day editor | `Views/WorkoutSplit/WorkoutSplitDayView.swift` |
| Split model | `Data/Models/WorkoutSplit/WorkoutSplit.swift` |
| Split day model | `Data/Models/WorkoutSplit/WorkoutSplitDay.swift` |
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
| Exercise history stats | `Data/Models/Exercise/ExerciseHistory.swift` |
| History rebuild | `Data/Services/ExerciseHistoryUpdater.swift` |
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

### Siri / Shortcuts / Intents
| What | Where |
|------|-------|
| Shortcut registration | `Intents/VillainArcShortcuts.swift` |
| Donation hub | `Intents/IntentDonations.swift` |
| Workout intents | `Intents/Workout/*.swift` (13 files) |
| Plan intents | `Intents/WorkoutPlan/*.swift` (8 files) |
| Exercise intents | `Intents/Exercise/*.swift` (5 files) |
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
| Spotlight routing | `Data/Services/AppRouter.swift` → `handleSpotlight()` |
| Entity associations | `Intents/Workout/WorkoutSessionEntity.swift` etc. |

### Onboarding & Setup
| What | Where |
|------|-------|
| Onboarding state machine | `Data/Services/OnboardingManager.swift` |
| Setup guard (gate) | `Data/Services/SetupGuard.swift` |
| Onboarding UI | `Views/Onboarding/OnboardingView.swift` |
| User profile model | `Data/Models/UserProfile.swift` |
| iCloud check | `Helpers/CloudKitStatusChecker.swift` |
| Network check | `Helpers/NetworkMonitor.swift` |

### Shared UI Components
| What | Where |
|------|-------|
| Navigation bar helpers | `Views/Components/Navbar.swift` |
| Text editor sheet | `Views/Components/TextEntryEditorView.swift` |
| Timer duration picker | `Views/Components/TimerDurationPicker.swift` |
| RPE picker | `Views/Components/RPEPickerView.swift` |
| Section header button | `Views/HomeSections/HomeSectionHeaderButton.swift` |
| Empty state | `Views/Components/SmallUnavailableView.swift` |
| Workout card row | `Views/Components/WorkoutRowView.swift` |
| Plan card (display) | `Views/Components/WorkoutPlanCardView.swift` |
| Plan row (navigable) | `Views/Components/WorkoutPlanRowView.swift` |

### Utilities
| What | Where |
|------|-------|
| Persistence helpers | `Data/Services/DataManager.swift` → `saveContext()`, `scheduleSave()` |
| Exercise catalog seeding | `Data/Services/DataManager.swift` → `seedExercisesIfNeeded()` |
| Haptic feedback | `Helpers/Haptics.swift` |
| Time formatting | `Helpers/TimeFormatting.swift` |
| Keyboard dismiss | `Helpers/KeyboardDismiss.swift` |
| Accessibility IDs | `Helpers/Accessibility.swift` |
| Sample/preview data | `Data/SampleData.swift` |

---

## Suggestion Engine Summary

The suggestion system is a closed-loop learning pipeline:

**Generation** (after workout): `SuggestionGenerator` → detects training style (deterministic, with AI fallback for ambiguous cases) → `RuleEngine` evaluates 15 rules (progression, safety, plateau, set-type hygiene) → `SuggestionDeduplicator` resolves conflicts → produces `PrescriptionChange` records.

**Review** (before next workout): User sees pending suggestions grouped by exercise. Can accept (applies to plan), reject (ignores), or defer (review later).

**Outcome Evaluation** (after next workout): `OutcomeResolver` checks whether accepted suggestions worked. `OutcomeRuleEngine` scores deterministically. `AIOutcomeInferrer` provides optional AI override (only when AI confidence >= 0.75 AND rule confidence < 0.7).

**Key rules:** Progression (weight/rep increases when targets hit for 2+ sessions), safety (weight decreases when struggling), plateau (rest increases when stagnating), set-type cleanup (misclassified set types).

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
Look at: `WorkoutSplit.swift` (model + day resolution), `WorkoutSplitView.swift` (management UI), `WorkoutSplitCreationView.swift` (editor).

---

## Enums Reference

| Enum | Cases | Used For |
|------|-------|----------|
| `SessionStatus` | pending, active, summary, done | Workout lifecycle |
| `SessionOrigin` | plan, freeform | How workout started |
| `ExerciseSetType` | working, warmup, dropSet | Set classification |
| `RepRangeMode` | notSet, target, range | Rep goal strategy |
| `MoodLevel` | notSet, sick, tired, okay, good, great | Pre-workout feeling |
| `SplitMode` | weekly, rotation | Schedule type |
| `ChangeType` | 16 variants (weight/reps/rest/repRange changes) | What a suggestion modifies |
| `Decision` | pending, accepted, rejected, deferred, userOverride | User's choice on suggestion |
| `Outcome` | pending, good, tooAggressive, tooEasy, ignored, userModified | How suggestion played out |
| `TrainingStyle` | straightSets, ascending, descendingPyramid, ascendingPyramid, topSetBackoffs, unknown | Detected exercise pattern |
| `SuggestionSource` | rules, ai, user | Where suggestion came from |
| `Muscle` | 43 variants (10 major, 33 minor) | Muscle targeting |
| `EquipmentType` | 18 variants | Equipment classification |
| `ProgressionTrend` | improving, stable, declining, insufficient | Performance trajectory |
| `PlanCreator` | user, ai | Plan origin |

---

## Test Coverage

**42 tests across 5 files:**
- Plan editing & suggestion lifecycle (18 tests)
- Workout finish logic (11 tests)
- Suggestion system / training style (8 tests)
- Exercise replacement (3 tests)
- Spotlight summaries (2 tests)

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
    HomeSections/                Home screen section views (4 files)
    Workout/                     Active workout views (11 files)
      Editors/                   Shared editors: RepRange, RestTime, MuscleFilter
    History/                     Workout history list
    WorkoutPlan/                 Plan CRUD views (4 files)
    WorkoutSplit/                Split management views (4 files)
    Suggestions/                 Suggestion review UI (2 files)
    Components/                  Reusable UI components (9 files)
  Data/
    SharedModelContainer.swift   SwiftData schema + container
    SampleData.swift             Preview fixtures
    Services/                    Service/coordinator classes
      AppRouter.swift            Navigation coordinator (singleton)
      DataManager.swift          Catalog seeding + save helpers
      OnboardingManager.swift    First-run state machine
      SetupGuard.swift           Onboarding gate
      RestTimerState.swift       Global rest timer (singleton)
      SpotlightIndexer.swift     CoreSpotlight integration
      ExerciseHistoryUpdater.swift  Analytics rebuild
      Suggestions/               Suggestion engine (8 files)
    Models/
      Sessions/                  WorkoutSession, ExercisePerformance, SetPerformance, PreWorkoutStatus
      Plans/                     WorkoutPlan, ExercisePrescription, SetPrescription, PrescriptionChange, SuggestionGrouping, WorkoutPlan+Editing
      Exercise/                  Exercise, ExerciseCatalog, ExerciseHistory, ProgressionPoint, RepRangePolicy, RestTimeDefaults
      WorkoutSplit/              WorkoutSplit, WorkoutSplitDay
      AIModels/                  AI DTOs for suggestion/outcome inference
      Enums/                     All domain enums (14 files)
      UserProfile.swift
      RestTimeHistory.swift
    LiveActivity/                ActivityKit attributes + manager
    Protocols/                   RestTimeEditable protocol
  Intents/                       App Intents for Siri/Shortcuts (24 files)
  Helpers/                       Utility functions (8 files)
  Documentation/                 This file + ARCHITECTURE.md + suggestion flow doc

VillainArcWidgetExtension/       Live Activity widget UI
VillainArcIntentsExtension/      Legacy SiriKit handlers
VillainArcTests/                 Test suite (5 test files + 3 support files)
```

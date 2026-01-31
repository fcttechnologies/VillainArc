# Schema Overhaul Implementation Plan

## Overview

Replace 6 existing models with renamed/restructured versions, add 9 new models and 8 new enums, and update all 47 dependent files across views, intents, and infrastructure. All relationships are optional for CloudKit compatibility.

**Migration:** None needed — user will delete and reinstall the app.

---

## Key Design Decisions

| Decision | Choice |
|----------|--------|
| ExercisePerformance policies | No own repRange/restTimePolicy — reads through `exercisePrescriptionUsed` |
| WorkoutPlan.complete | Keep `complete: Bool` (same pattern as current WorkoutTemplate) |
| SetPrescription rest property | `restSeconds: Int` (for RestTimeEditableSet conformance) |
| RestTimeEditable conformance | ExercisePrescription + SetPrescription conform. Performance side does not — no rest data on SetPerformance |
| RestTimePolicy.seconds(for:) | Generalize to `some RestTimeEditableSet` instead of `ExerciseSet` |
| Future models | Create stubs now (PlanSuggestion, SuggestedChange, SessionOverride, OverrideAdjustment), no UI |

---

## Phase 1: Create New Enums (8 files)

All in `Data/Models/Enums/`. Simple `enum: String, Codable, CaseIterable` types, zero dependencies.

| File | Cases |
|------|-------|
| `PlanCreator.swift` | user, rules, ai |
| `SessionOrigin.swift` | plan, freeform |
| `MoodLevel.swift` | great, good, okay, tired, sick |
| `SuggestionSource.swift` | rules, ai, user |
| `ChangeType.swift` | increaseWeight, decreaseWeight, increaseReps, decreaseReps, increaseRest, decreaseRest, addSet, removeSet, changeSetType |
| `Decision.swift` | accepted, rejected, deferred |
| `Outcome.swift` | good, tooAggressive, tooEasy, ignored |
| `AdjustmentType.swift` | percentWeight, percentVolume, skipExercise |

---

## Phase 2: Create All New Model Files (13 files)

### Plan-Layer Models (4 files in `Data/Models/Plans/`)

**SetPrescription.swift**
```
@Model class SetPrescription
- id: UUID, index: Int, type: ExerciseSetType
- targetWeight: Double?, targetReps: Int?, restSeconds: Int
- exercisePrescription: ExercisePrescription?
```

**ExercisePrescription.swift**
```
@Model class ExercisePrescription
- id: UUID, index: Int, catalogID: String, name: String, notes: String
- musclesTargeted: [Muscle]
- @Relationship(cascade) repRange: RepRangePolicy, restTimePolicy: RestTimePolicy
- planSnapshot: PlanSnapshot?
- @Relationship(cascade, inverse) setPrescriptions: [SetPrescription]
```

**PlanSnapshot.swift**
```
@Model class PlanSnapshot
- id: UUID, versionNumber: Int, createdAt: Date, createdBy: PlanCreator, notes: String
- @Relationship(nullify) sourceVersion: PlanSnapshot?
- workoutPlan: WorkoutPlan?
- @Relationship(cascade, inverse) exercisePrescriptions: [ExercisePrescription]
```

**WorkoutPlan.swift**
```
@Model class WorkoutPlan
- id: UUID, name: String, favorite: Bool, complete: Bool, lastUsed: Date?
- @Relationship(nullify) currentVersion: PlanSnapshot?
- @Relationship(cascade, inverse) versions: [PlanSnapshot]
Static FetchDescriptors: all, recents, incomplete
```

### Session-Layer Models (5 files in `Data/Models/Sessions/`)

**PreWorkoutMood.swift**
```
@Model — id: UUID, feeling: MoodLevel, notes: String?, workoutSession: WorkoutSession?
```

**PostWorkoutEffort.swift**
```
@Model — id: UUID, rpe: Int, notes: String?, workoutSession: WorkoutSession?
```

**SetPerformance.swift**
```
@Model class SetPerformance
- id: UUID, index: Int, type: ExerciseSetType
- weight: Double, reps: Int, complete: Bool, completedAt: Date?
- exercisePerformance: ExercisePerformance?
- @Relationship(nullify) setPrescriptionUsed: SetPrescription?
```

**ExercisePerformance.swift**
```
@Model class ExercisePerformance
- id: UUID, index: Int, catalogID: String, name: String, notes: String, musclesTargeted: [Muscle]
- workoutSession: WorkoutSession?
- @Relationship(nullify) exercisePrescription: ExercisePrescription?
- @Relationship(cascade, inverse) setPerformances: [SetPerformance]
Static: lastCompleted(for:) FetchDescriptor
```

**WorkoutSession.swift**
```
@Model class WorkoutSession
- id: UUID, title: String, notes: String, completed: Bool
- startedAt: Date, endedAt: Date?, origin: SessionOrigin
- @Relationship(cascade) preMood: PreWorkoutMood?, postEffort: PostWorkoutEffort?
- @Relationship(nullify) planSnapshotUsed: PlanSnapshot?
- @Relationship(cascade, inverse) exercisePerformances: [ExercisePerformance]
Static FetchDescriptors: completedWorkouts, incomplete, recentWorkout
```

### Future Models (stubs, 4 files)

**`Data/Models/Suggestions/PlanSuggestion.swift`** — All properties, relationships to WorkoutSession? and PlanSnapshot?.

**`Data/Models/Suggestions/SuggestedChange.swift`** — All properties, UUID references for source/target, parent `planSuggestion: PlanSuggestion?`.

**`Data/Models/Overrides/SessionOverride.swift`** — All properties, `workoutSession: WorkoutSession?`, cascade `adjustments: [OverrideAdjustment]`.

**`Data/Models/Overrides/OverrideAdjustment.swift`** — `@Model` with id, type, value, targetExercisePrescriptionID, `sessionOverride: SessionOverride?`.

---

## Phase 3: Delete Old Model Files (6 files)

- `Data/Models/Workout/Workout.swift`
- `Data/Models/Workout/WorkoutExercise.swift`
- `Data/Models/Workout/ExerciseSet.swift`
- `Data/Models/Templates/WorkoutTemplate.swift`
- `Data/Models/Templates/TemplateExercise.swift`
- `Data/Models/Templates/TemplateSet.swift`

Move `Data/Models/Workout/Exercise.swift` → `Data/Models/Exercise/Exercise.swift`.
Delete empty `Data/Models/Workout/` and `Data/Models/Templates/` directories.

---

## Phase 4: Update Infrastructure — Schema, Seeding, Indexing (3 files)

### 4a. `Data/SharedModelContainer.swift`
Replace schema with all new models (~20 total):
```
WorkoutSession, ExercisePerformance, SetPerformance,
WorkoutPlan, PlanSnapshot, ExercisePrescription, SetPrescription,
Exercise, RepRangePolicy, RestTimePolicy, RestTimeHistory,
PreWorkoutMood, PostWorkoutEffort,
PlanSuggestion, SuggestedChange,
SessionOverride, OverrideAdjustment,
WorkoutSplit, WorkoutSplitDay
```

### 4b. `Data/Classes/DataManager.swift`
- Exercise seeding logic stays largely the same (Exercise model unchanged)
- Update any references to old model types if present

### 4c. `Data/Classes/SpotlightIndexer.swift`
- `index(workout: Workout)` → `index(session: WorkoutSession)`
- `index(template: WorkoutTemplate)` → `index(plan: WorkoutPlan)`
- Property access updates (startTime→startedAt, etc.)
- `WorkoutTemplateEntity` references → `WorkoutPlanEntity`

---

## Phase 5: Update WorkoutSplit Models (2 files)

### `Data/Models/WorkoutSplit/WorkoutSplitDay.swift`
- `template: WorkoutTemplate?` → `plan: WorkoutPlan?` (nullify)
- `split: WorkoutSplit` → `split: WorkoutSplit?` (optional for CloudKit)

### `Data/Models/WorkoutSplit/WorkoutSplit.swift`
- `todaysTemplate: WorkoutTemplate?` → `todaysPlan: WorkoutPlan?`
- Return `day.plan` instead of `day.template`

---

## Phase 6: Update Sample Data (1 file)

### `Data/SampleData.swift`
Complete rewrite of all sample data factories:
- `sampleCompletedWorkout()` → creates WorkoutSession + PlanSnapshot + performances
- `sampleIncompleteWorkout()` → same but incomplete
- `sampleTemplate()` → creates WorkoutPlan + PlanSnapshot + prescriptions
- `PreviewDataContainer` schema updated with all new models
- Sample WorkoutSplit data updated

---

## Phase 7: Update Routing (1 file)

### `Data/Classes/AppRouter.swift`
- `activeWorkout: Workout?` → `activeWorkout: WorkoutSession?`
- `activeTemplate: WorkoutTemplate?` → `activePlan: WorkoutPlan?`
- `Destination` enum: `.workoutDetail(WorkoutSession)`, `.templateDetail(WorkoutPlan)` (or rename)
- `startWorkout(from:)` → adapted for WorkoutSession
- `startWorkout(from template:)` → `startWorkout(from plan: WorkoutPlan)` using `plan.currentVersion`
- `createTemplate()` → `createPlan()` or similar
- `checkForUnfinishedData()` uses new fetch descriptors

---

## Phase 8: Update Intents (13+ files)

Same mechanical type renames:
- **WorkoutTemplateEntity.swift** → **WorkoutPlanEntity.swift**
- All 11 workout intent files: Workout → WorkoutSession
- 3 template intent files: WorkoutTemplate → WorkoutPlan
- IntentDonations.swift, VillainArcShortcuts.swift

---

## Phase 9: Update Helpers (1 file)

### `Helpers/Accessibility.swift`
- All type parameters updated
- Optional back-refs use `?.id ?? UUID()` pattern

---

## Phase 10: Update Detail/List Views (easier views)

These views display data but don't involve complex editing flows:

- **WorkoutDetailView.swift** — WorkoutSession display, save-as-plan
- **TemplateDetailView.swift** → rename, WorkoutPlan display
- **TemplatesListView.swift** — @Query with WorkoutPlan.all
- **WorkoutsListView.swift** — @Query with WorkoutSession.completedWorkouts
- **ContentView.swift** — Navigation destination types
- **WorkoutRowView.swift** — WorkoutSession in list
- **TemplateRowView.swift** — WorkoutPlan in list
- **RecentWorkoutSectionView.swift** — Query type change
- **RecentTemplatesSectionView.swift** — Query type change
- **WorkoutSplitView.swift** — todaysPlan reference
- **WorkoutSplitDayView.swift** — plan reference
- **WorkoutSplitCreationView.swift** — plan references

---

## Phase 11: Update Active Editing Views (last — user will change significantly)

These are the complex editing views the user plans to rework:

- **WorkoutView.swift** — Active workout with WorkoutSession + ExercisePerformance
- **ExerciseView.swift** — Exercise editing, accesses repRange/restTimePolicy through prescription
- **TemplateView.swift** → rename — Plan editing with WorkoutPlan + PlanSnapshot + prescriptions
- **ExerciseSetRowView.swift** — SetPerformance display/editing
- **AddExerciseView.swift** — Dual mode for WorkoutSession vs PlanSnapshot
- **RestTimerView.swift** — WorkoutSession reference
- **WorkoutTitleEditorView.swift** — WorkoutSession reference
- **WorkoutNotesEditorView.swift** — WorkoutSession reference

### Protocol/Policy updates (part of this phase):
- **RestTimePolicy.swift** — `seconds(for: ExerciseSet)` → `seconds(for: some RestTimeEditableSet)`
- **RestTimeEditable.swift** — No changes needed (already generic)
- **RestTimeEditorView.swift** — May need to accept ExercisePrescription instead of ExercisePerformance
- **RepRangeEditorView.swift** — Works with RepRangePolicy directly, minimal changes

---

## Phase 12: Build & Verify

1. Build project — fix remaining compile errors
2. Verify SwiftUI previews compile and render
3. Build and run on simulator — app launches, exercises seed
4. Test core flows: create plan, start workout from plan, freeform workout, save as plan, complete workout
5. Verify Spotlight indexing
6. Verify intents/shortcuts compile

---

## File Count Summary

| Category | Count |
|----------|-------|
| New files to create | 21 (8 enums + 13 models) |
| Files to modify | 47 (infra + views + intents + helpers + splits) |
| Files to delete | 6 (old models) |
| Files to move | 1 (Exercise.swift) |
| **Total files touched** | **~75** |

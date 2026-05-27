# Plan Templates Flow

This document explains how shipped workout-program templates work in VillainArc and how they feed both the "Create Plan" and "Create Split" flows.

## Main Files

- `Data/Models/Plans/PlanTemplate.swift`
- `Data/Models/Plans/PlanTemplateMaterializer.swift`
- `Data/Models/AIModels/Plans/AIGeneratedPlanModels.swift`
- `Data/Services/AI/Plans/AIWorkoutPlanGenerator.swift`
- `Views/WorkoutPlan/PlanBuilderSheet.swift`
- `Views/WorkoutPlan/PlanTemplateDetailView.swift`
- `Views/WorkoutPlan/GeneratePlanAIPromptView.swift`
- `Views/WorkoutSplit/SplitBuilderView.swift`

## What a Template Is

`PlanTemplate` is an immutable static struct shipped inside the binary. Each template carries a multi-day program: training days plus optional rest days, with per-day exercise lists, set/rep/RPE prescriptions, rest seconds, and a notes string. Templates live in `PlanTemplateRegistry.all` — six programs ship in v1.3:

- Push / Pull / Legs (6-day)
- Upper / Lower (4-day)
- Full Body (3-day)
- Stronglifts 5x5 (3-day)
- 5/3/1 BBB (4-day)
- Bro Split (5-day)

Templates are content, not user data. Picking one materializes user-owned `WorkoutPlan` (and optionally `WorkoutSplit`) rows that the user owns and edits afterward.

## Materializer

`PlanTemplateMaterializer` is the only place templates turn into SwiftData rows. It supports three shapes:

- `makeIncompletePlan(template:day:context:)` — one editable WorkoutPlan from one template day. Used when the user picks a single day from `PlanTemplateDetailView`.
- `materializeProgram(template:activate:context:)` — every training day becomes a completed WorkoutPlan plus a rotation `WorkoutSplit` whose days link the plans. When `activate` is true, any existing active split is deactivated and the new split is activated.
- `makeIncompletePlan(aiDay:...)` and `materializeProgram(aiResult:...)` — same idea for AI-generated content.

All materialized plans have `targetWeight = 0` on every set — the user fills in loads based on their own training maxes.

## "Create Plan" Sheet

The entry points to plan creation now all go through `PlanBuilderSheet`. Both `ContentView` (the Home tab's expanded action) and `WorkoutPlanPickerView` (split day plan assignment) present the same sheet.

`PlanBuilderSheet` shows three sections:

- **Start from Scratch** — calls `AppRouter.createWorkoutPlan()`, which inserts an empty draft and routes into `WorkoutPlanView` (unchanged from earlier behavior).
- **Generate with AI** — opens `GeneratePlanAIPromptView` if `AIWorkoutPlanGenerator.isAvailable` is true. Hidden on devices where Apple Intelligence isn't available.
- **Templates** — lists the registry. Tapping a template pushes `PlanTemplateDetailView`.

`PlanTemplateDetailView` shows the template description, then a card per training day with the day's notes and exercise list. The user can:

- tap a single day to drop one editable plan into the editor (`makeIncompletePlan(template:day:)` → `AppRouter.activatePreBuiltPlan`)
- tap "Build Full Program" to materialize all training days plus an active rotation split (`materializeProgram(template:activate:true:)`). No editor opens — the user gets a success toast and the new split takes over the Home today's-workout flow.

## "Create Split" Sheet

`SplitBuilderView`'s first screen (`SelectTypeView`) now has three sections:

1. **Start from Scratch** — empty weekly or rotation split (unchanged).
2. **Or pick a full program** — same template list as the plan builder. Tapping a program calls `materializeProgram(template:activate:true:)` and shows the success toast.
3. **Or pick a schedule shape** — the existing `SplitPresetType` templates (PPL, Upper/Lower, etc.) that build the schedule structure without exercises. Pick this when you want the shape only and plan on wiring up plans yourself.

This is what "templates apply to both plans and splits" means in practice: one `PlanTemplateRegistry` feeds both surfaces.

## AI Plan Generation

`AIWorkoutPlanGenerator` calls the on-device system language model through FoundationModels. The user prompt is combined with `AIPlanProfileContext` (fitness level, training goal, weight unit) and sent as a `Prompt` block. The model returns a `@Generable AIGeneratedPlan` whose nested `AIGeneratedPlanDay` and `AIGeneratedPlanExercise` carry the structured shape.

After generation, the service fuzzy-matches each suggested exercise name to a real `ExerciseCatalogItem` via five strategies:

1. exact normalized name + equipment match
2. exact normalized name (any equipment)
3. alias match
4. equipment-prefixed name match (e.g. "Barbell Bench Press" → `barbell_bench_press`)
5. token-overlap score with equipment tiebreak

Unresolved names are logged and surfaced as `AIGeneratedPlanResult.unresolvedExerciseNames` but don't block the rest of the plan from being built.

UX after generation mirrors templates:

- single-day result → drop into editor as one incomplete plan
- multi-day result → materialize as a program (all plans completed + active split), show success toast

Availability is gated on `SystemLanguageModel.default.availability == .available`. When it isn't, the "Generate with AI" section is hidden entirely and existing flows are unaffected.

## Relationship to Existing Flows

- `AppRouter.createWorkoutPlan()` still exists and still creates an empty draft. Templates use `activatePreBuiltPlan` for the editable path and bypass the editor for the program path.
- Materialized plans go through the same `WorkoutPlanView` and `WorkoutPlanDeletionCoordinator` paths as any other plan after creation.
- `PlanTemplateMaterializer.attach` mirrors `ExercisePrescription.init(exercise:workoutPlan:)` semantics so suggestion generation, Spotlight indexing, and exercise history all work with materialized plans without special-casing.
- The split builder's program section is a peer of the existing schedule shape templates — it does not replace them.

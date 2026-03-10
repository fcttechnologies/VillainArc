# Plan Editing Flow

This document describes the workout plan editing lifecycle in VillainArc, covering the copy-merge pattern, how edits are applied atomically, and how the editing system interacts with the suggestion engine.

It is based on the current code in:

- `Data/Models/Plans/WorkoutPlan.swift`
- `Data/Models/Plans/WorkoutPlan+Editing.swift`
- `Data/Models/Plans/ExercisePrescription.swift`
- `Data/Models/Plans/SetPrescription.swift`
- `Data/Models/Plans/PrescriptionChange.swift`
- `Views/WorkoutPlan/WorkoutPlanView.swift`
- `Views/WorkoutPlan/WorkoutPlanDetailView.swift`
- `Views/Suggestions/SuggestionReviewView.swift`
- `Data/Services/AppRouter.swift`

## Core Principle

Plans are never edited in place. Every edit goes through a **copy-merge pattern**:

1. Create a temporary editing copy of the plan
2. User modifies the copy freely
3. On save, diff the copy against the original and apply changes atomically
4. On cancel, delete the copy — the original is untouched

This pattern exists for three reasons:

- **Atomicity**: Partial edits never corrupt the live plan. Users can abandon mid-edit without damage.
- **Suggestion safety**: Pending suggestions target specific prescriptions on the original plan. The reconciliation step detects when manual edits conflict with pending suggestions and marks them accordingly.
- **Resume safety**: If the user force-quits mid-edit, the original plan is unchanged. Leftover editing copies are cleaned up on startup.

## Plan Creation Paths

### Fresh from UI

`AppRouter.createWorkoutPlan()`:

1. Guards `hasActiveFlow()`
2. Creates a new `WorkoutPlan()` with default title, `completed = false`
3. Inserts into context, saves
4. Sets `activeWorkoutPlan`, triggering `ContentView`'s full-screen cover to show `WorkoutPlanView`

This is a direct edit (no copy needed since there's no original to protect). `WorkoutPlanView` detects this by checking `plan.isEditing == false` — new plans go through the create flow rather than the edit-copy flow.

### From a Completed Workout

`WorkoutPlan(from: workout, completed: true)` in `WorkoutSummaryView.saveWorkoutAsPlan()`:

1. Copies title and notes from the workout
2. Creates `ExercisePrescription` rows from the workout's `ExercisePerformance` rows
3. Links each `ExercisePerformance` back to its new `ExercisePrescription`
4. Links each `SetPerformance` back to its new `SetPrescription`
5. Sets `completed = true` — this plan is ready to use immediately

Those back-links are critical: they allow the suggestion engine to use the just-finished workout as evidence for generating suggestions against the newly created plan.

### Editing an Existing Plan

`WorkoutPlanDetailView` triggers this flow:

1. Calls `plan.createEditingCopy(context:)` to create the copy
2. Presents `WorkoutPlanView` as a full-screen cover with the copy

## The Editing Copy

`createEditingCopy(context:)` does:

1. Creates a new `WorkoutPlan` with the same `title`, `notes`, `favorite`, but `completed = false`
2. Sets `isEditing = true` on the copy (marks it as a temporary editing artifact)
3. Maps all exercises via `ExercisePrescription(copying:workoutPlan:)` — deep copies exercises and their sets, preserving the same `id` values so the apply step can match originals to copies
4. Inserts the copy into context (it's persisted, not just in memory)

The copy is a full SwiftData object. This means it survives app kills, but `isEditing = true` marks it as disposable.

## During Editing

`WorkoutPlanView` provides the editing UI. The user can:

- **Add exercises** from the catalog via `AddExerciseView`
- **Remove exercises** with swipe or edit mode
- **Reorder exercises** via drag
- **Edit per-exercise settings**: rep range policy (mode/lower/upper/target), rest time policy, notes
- **Edit per-set targets**: weight, reps, rest, set type, target RPE (non-warmup sets only)
- **Add/remove sets** within an exercise
- **Edit plan title and notes** via `TextEntryEditorView` sheets

All mutations happen on the copy. The original plan is untouched throughout.

## Finishing an Edit (Apply)

When the user saves, `WorkoutPlanView` calls `finishEditing(context:)` on the plan:

For editing copies, this calls `applyEditingCopy(_:context:)` on the original plan, passing the copy. For new plans, it just marks the plan as `completed = true`.

### applyEditingCopy

This method diffs the copy against the original and synchronizes changes:

**Step 1: Reconcile pending suggestions** (`reconcilePendingChanges`)

Before applying any changes, the method compares the copy to the original to find what the user changed manually. For each exercise that exists in both:

- If the exercise's `catalogID` changed (exercise was replaced), all pending suggestions for that exercise are deleted
- Otherwise, field-by-field comparison detects manual changes:
  - Exercise-level: rep range mode, lower/upper bounds, target reps
  - Set-level: set type, target weight, target reps, target rest

When a manual change matches a pending/deferred suggestion's domain (e.g., user changed target weight, and there was a pending `increaseWeight` suggestion), that suggestion is marked via `markAsUserOverride()`.

**Step 2: Apply values**

- Copy `title` and `notes` from the editing copy
- For exercises that exist in both (matched by `id`): copy all field values, sync sets
- For exercises only in the copy (new additions): reparent them to the original plan
- For exercises only in the original (deletions): delete pending suggestions targeting them, then delete the exercise

**Step 3: Sync sets**

Within each exercise, sets are matched by `id`:

- Sets only in the copy (new): reparented to the original exercise
- Sets in both: field values copied (index, type, targetWeight, targetReps, targetRest, targetRPE)
- Sets only in the original (deleted): pending suggestions targeting them are deleted, then the set is deleted

**Step 4: Reindex**

All exercises are reindexed to maintain correct ordering.

## Canceling an Edit

`cancelEditing(context:)` deletes the editing copy from context. The original plan remains unchanged. If the plan was a new creation (not an editing copy), the entire plan is deleted.

`WorkoutPlanView` also handles the cancel via confirmation alert when there are unsaved changes.

## Deleting a Plan

`deleteWithSuggestionCleanup(context:)`:

1. Calls `deletePendingOutcomeChanges(context:)` — deletes all `PrescriptionChange` records targeting this plan where `outcome == .pending`
2. Deletes the plan itself from context

Only pending-outcome suggestions are removed. Resolved suggestions (with outcomes like `.good`, `.tooAggressive`, etc.) are preserved for analytics history even after the plan is gone.

## Interaction with Suggestions

### markAsUserOverride

`PrescriptionChange.markAsUserOverride()` is the bridge between manual edits and the suggestion system:

```
guard source != .user else { return }       // skip user-sourced changes
if decision == .deferred || decision == .pending {
    decision = .userOverride
}
if outcome == .pending {
    outcome = .userModified
}
```

Guards:
- Skips changes whose `source == .user` (user-created suggestions don't need override tracking)
- Only marks `decision = .userOverride` if the current decision is `pending` or `deferred` (already accepted/rejected suggestions are left alone)
- Only marks `outcome = .userModified` if the outcome is still `pending`

### Deletion Cleanup

Three levels of cleanup, all scoped to `outcome == .pending`:

1. **Plan deletion**: Removes all pending-outcome changes targeting this plan
2. **Exercise deletion**: Removes pending-outcome changes targeting the exercise and all its sets (deduplicated)
3. **Set deletion**: Removes pending-outcome changes targeting just that set

Resolved suggestions are always preserved.

### How This Differs from Suggestion Accept/Reject

Accepting a suggestion (`applyChange` in `SuggestionReviewView.swift`) directly mutates the live plan and sets `decision = .accepted`. This happens outside the editing copy flow — it modifies the original plan immediately.

Manual editing through the copy flow does not directly set `decision` on suggestions. Instead, it uses the reconciliation step to detect overlapping changes and mark them as `userOverride`.

## Startup Cleanup

`WorkoutPlan.resumableIncomplete` fetches plans where `!completed && !isEditing`. This means editing copies (which have `isEditing = true`) are excluded from the resume flow.

If the user force-quits during plan editing, the editing copy persists in the database but is not resumed on next launch. The original plan is untouched. The orphaned copy is cleaned up by `WorkoutPlan.incomplete` queries used in `hasActiveFlow()` checks, which include editing copies — this prevents starting new flows until the copy is dealt with. In practice, the editing copy is cleaned up when the user next opens the plan detail and starts a new edit (the old copy is replaced).

## Edge Cases

### Editing a plan with pending suggestions

The reconciliation step runs before any values are applied. This means if the user edits a set's weight and there was a pending `increaseWeight` suggestion for that same set, the suggestion is marked as `userOverride` before the new weight is written. The suggestion system treats this as "the user took matters into their own hands."

### Replacing an exercise during editing

If the user replaces an exercise (changes the `catalogID`), all pending suggestions for the old exercise are deleted rather than marked as overrides. This is correct because the suggestions targeted a different exercise entirely.

### Deleting the only set in an exercise

The editing UI prevents this — set deletion is only exposed when more than one set remains. `ExercisePrescription` is always initialized with at least one set.

### Save-as-plan creates a completed plan

Plans created via "Save as Workout Plan" from `WorkoutSummaryView` skip the editing copy flow entirely. They're created with `completed = true` and are immediately ready for use. No editing copy is involved.

# Plan Editing Flow

This document explains how workout plan editing works in VillainArc. The flow is mostly centered in `Data/Models/Plans/WorkoutPlan+Editing.swift`, with `AppRouter` starting edit mode and `WorkoutPlanView` handling save/cancel UI.

## Main Files

- `Data/Models/Plans/WorkoutPlan+Editing.swift`
- `Data/Models/Plans/WorkoutPlan.swift`
- `Data/Services/AppRouter.swift`
- `Views/WorkoutPlan/WorkoutPlanView.swift`
- `Views/WorkoutPlan/WorkoutPlanDetailView.swift`
- `Root/VillainArcApp.swift`

## Core Rule

Existing plans are never edited in place.

VillainArc uses a copy-merge flow:
- create a temporary editing copy
- let the user mutate that copy freely
- on save, merge the copy back into the original plan
- on cancel, delete the copy

That keeps the original plan stable until the user finishes, and it gives the app one place to reconcile stale pending suggestion state before anything is committed.

## Where Editing Starts

There are two main plan-authoring paths:

- `AppRouter.createWorkoutPlan()`
  - creates a brand-new incomplete plan
  - sets `activeWorkoutPlanOriginal = nil`
  - presents `WorkoutPlanView`
  - this is not a copy flow because there is no original plan to protect yet

- `AppRouter.editWorkoutPlan(_:)`
  - only works for completed non-editing plans and only when there is no other active flow
  - calls `plan.createEditingCopy(context:)`
  - stores the original in `activeWorkoutPlanOriginal`
  - presents the copy in `WorkoutPlanView`

`WorkoutPlanDetailView` is the normal UI entrypoint for editing an existing plan.

If the user is creating a brand-new plan instead of editing an existing one, `WorkoutPlanView` eventually marks that plan `completed = true`, clears completed-session prescription links if needed, saves it, and indexes it for Spotlight. That path is simpler because there is no original plan to merge back into.

## The Editing Copy

`createEditingCopy(context:)`:
- creates a new `WorkoutPlan`
- copies top-level plan fields like title, notes, favorite, and origin
- sets `completed = false`
- sets `isEditing = true`
- deep-copies the plan’s exercises and sets into the new plan
- keeps the same model IDs for matched copied exercises and sets so merge logic can align original and copy later

The copy is a real persisted SwiftData model, not just temporary view state.

That matters for two reasons:
- `WorkoutPlanView` can bind directly to the copy while editing
- if the app is killed mid-edit, the copy can still be cleaned up safely on next launch without ever mutating the original plan

## What the User Edits

`WorkoutPlanView` edits the copy directly.

At a high level the user can:
- change title and notes
- add, remove, and reorder exercises
- change exercise-level rep range settings
- change set-level type, weight, reps, rest, and RPE
- add and remove sets

Nothing in this phase touches the original plan.

## Saving an Existing Plan Edit

When the user taps Done while editing an existing plan, `WorkoutPlanView` does:

1. `originalPlan.applyEditingCopy(plan, context: context)`
2. `context.delete(plan)` for the temporary copy
3. `saveContext(context: context)`
4. `SpotlightIndexer.index(workoutPlan: originalPlan)`

So the real merge work lives inside `applyEditingCopy`.

## What `applyEditingCopy` Does

`applyEditingCopy(_ copy: WorkoutPlan, context: ModelContext)` does three practical things:

1. reconcile unresolved suggestion state that the manual edit invalidates
2. copy values from the editing copy back into the original plan
3. delete removed exercises and sets, then reindex ordering

### 1. Reconcile Pending Suggestion State First

This happens before values are copied back.

`reconcilePendingChanges(comparedTo:context:)` compares the original plan against the editing copy and removes unresolved suggestion state when the user has manually overridden the same area.

It checks:
- exercise rep range mode
- exercise rep range lower bound
- exercise rep range upper bound
- exercise rep range target
- set type
- set target weight
- set target reps
- set target rest

If the user changed one of those fields manually, the matching unresolved suggestion changes for that exercise or set are deleted.

If the unresolved change belongs to a `SuggestionEvent`, the event is deleted once rather than leaving half of it behind.

Important detail:
- this cleanup only removes unresolved suggestion work where `event.outcome == .pending`
- resolved suggestion history is preserved

### 2. Copy Values Back Into the Original

After reconciliation, the original plan is updated from the copy.

At the plan level it copies:
- title
- notes
- origin

At the exercise level it:
- updates existing exercises matched by ID
- reparents new exercises from the copy into the original plan
- copies catalog metadata, notes, muscles, equipment, index, and rep range values

At the set level it:
- updates existing sets matched by ID
- reparents new sets from the copy into the original exercise
- copies index, type, target weight, target reps, target rest, and target RPE

### 3. Delete Removed Exercises and Sets

If an exercise or set exists in the original but not in the editing copy anymore, it is treated as deleted.

Before deletion:
- `deletePendingOutcomeChanges(for: exercise, context: context)` or
- `deletePendingOutcomeChanges(for: set, context: context)`

removes unresolved suggestion state still attached to that target.

Then the model itself is deleted.

Finally the plan reindexes exercises, and each edited exercise reindexes its sets.

## Replacing an Exercise

Replacing an exercise is a special case because the original prescription identity is being reused for a different catalog exercise.

When `applyExerciseValues(from:to:context:)` sees a changed `catalogID`, it first calls:
- `originalExercise.clearLinkedPerformanceReferences()`

That clears historical performance references that should no longer point at a prescription whose identity has effectively changed.

This keeps old completed performances valid as history without pretending they still belong to the new exercise identity.

## Canceling

If the user cancels while editing an existing plan, `WorkoutPlanView` deletes the editing copy and dismisses.

The original plan remains untouched.

If the user is creating a brand-new incomplete plan instead of editing an existing one, cancel behavior is different:
- the unfinished plan itself is what gets discarded if the user cancels, because there is no protected original behind it

## Deleting a Plan

`deleteWithSuggestionCleanup(context:)` is the plan-level delete helper.

It:
- removes unresolved suggestion changes/events still reachable from the plan
- deletes the plan itself

Like the rest of the cleanup helpers, it only removes unresolved suggestion state. Resolved history is preserved.

## Startup and Resume Behavior

Editing copies are intentionally excluded from normal resume behavior.

Relevant `WorkoutPlan` fetches:
- `resumableIncomplete` returns incomplete plans where `isEditing == false`
- `editingCopies` returns plans where `isEditing == true`

That means:
- unfinished brand-new plan creation can resume on launch
- editing copies do not resume as active flows

Instead, `RootView.cleanupEditingWorkoutPlanCopies()` deletes all persisted editing copies on startup before normal routing continues.

So if the app is force-quit during plan editing:
- the original completed plan is still intact
- the editing copy is thrown away on next launch

## Relationship to Suggestions

Plan editing does not accept or reject suggestions.

That logic belongs to summary review and deferred review. Manual editing just establishes a new source of truth for the plan.

If an unresolved suggestion targeted the same field the user just changed manually, plan editing removes that unresolved suggestion state instead of trying to keep it alive.

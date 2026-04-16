# Plan Editing Flow

This document explains how workout plan authoring and editing work in VillainArc. The central rule is that completed plans are never edited in place.

## Main Files

- `Data/Models/Plans/WorkoutPlan.swift`
- `Data/Models/Plans/WorkoutPlan+Editing.swift`
- `Data/Services/App/AppRouter.swift`
- `Views/WorkoutPlan/WorkoutPlanView.swift`
- `Views/WorkoutPlan/WorkoutPlanDetailView.swift`
- `Data/Services/App/SpotlightIndexer.swift`

## Core Rule

VillainArc has two plan-authoring modes:

- create a brand-new plan
- edit an existing completed plan through a persisted editing copy

For completed plans, the app always:

- creates a temporary persisted editing copy
- lets the user edit that copy freely
- merges the copy back into the original on save
- deletes the copy on cancel

That keeps the original plan stable until commit time and gives the app one place to clean up stale suggestion state invalidated by manual edits.

Presentation note:

- an active plan-editing flow can be temporarily dismissed from full-screen presentation and later reopened from the active-flow resume bar
- while minimized, that draft/edit flow is still active work and still blocks starting another workout/plan flow

## Where Authoring Starts

### Blank Plan Creation

`AppRouter.createWorkoutPlan()`:

- blocks if another workout/plan flow is active
- creates a persisted incomplete `WorkoutPlan`
- presents `WorkoutPlanView`

This is a real draft model, so unfinished new-plan creation can resume later.

### Plan Creation From a Workout

`AppRouter.createWorkoutPlan(from:)`:

- blocks if another workout/plan flow is active
- creates `WorkoutPlan(from: workout)`
- converts the editable copy from canonical kg into the user’s unit
- links the workout to that new draft
- presents `WorkoutPlanView`

This is the editable workout-detail path, not the summary “save as plan” path.

### Editing an Existing Completed Plan

`AppRouter.editWorkoutPlan(_:)`:

- only allows completed, non-editing plans
- blocks if another workout/plan flow is active
- creates an editing copy through `plan.createEditingCopy(context:)`
- converts the copy into the user’s current display unit
- stores the original plan pointer in `activeWorkoutPlanOriginal`
- presents the copy in `WorkoutPlanView`

## The Editing Copy

`WorkoutPlan.createEditingCopy(context:)`:

- creates a new incomplete `WorkoutPlan`
- marks it `isEditing = true`
- copies top-level fields such as title, notes, and favorite state
- deep-copies exercises and sets
- preserves exercise and set IDs so merge logic can align original and copy later

The copy is persisted SwiftData, not temporary view state.

That matters because:

- the editor can bind directly to real models
- launch cleanup can safely delete abandoned edit copies
- the original plan remains untouched until save

## What the User Edits

`WorkoutPlanView` edits the draft copy directly.

Typical edits include:

- title and notes
- exercise add/remove/reorder
- exercise replacement
- rep-range mode and bounds
- set add/remove
- set type, target load, target reps, target rest, and target RPE

While editing, target loads use the current display unit. Save converts them back to canonical kg before commit.

When editing an existing plan, adding a set first tries to reuse the next unused tail-set identity from the original plan before creating a brand-new set. That preserves IDs for common delete-and-readd scenarios.

## Saving

### Saving a New Plan

For brand-new drafts, save:

- converts target weights back to kg
- marks the plan completed if appropriate
- clears active performance references from already-completed linked sessions
- saves
- Spotlight-indexes the plan
- reindexes linked splits

There is no merge because there is no protected original plan behind the draft.

### Saving an Edit to an Existing Plan

For edit-existing flows, save:

1. converts the editing copy back to canonical kg
2. calls `originalPlan.applyEditingCopy(copy, context:)`
3. deletes the editing copy
4. saves
5. Spotlight-indexes the original plan
6. reindexes any linked splits

## What `applyEditingCopy` Does

`WorkoutPlan.applyEditingCopy(_ copy: WorkoutPlan, context: ModelContext)` does three jobs:

1. reconcile unresolved suggestion state invalidated by manual edits
2. copy values from the editing copy back into the original
3. delete removed exercises and sets, then reindex ordering

### Suggestion Reconciliation

Before copying values back, the original plan is compared to the editing copy.

If the user manually changes a field that an unresolved suggestion still targets, the stale suggestion event is deleted.

That cleanup covers:

- rep-range configuration
- set type
- target load
- target reps
- target rest
- exercise replacement

Manual editing establishes the new source of truth. Unresolved suggestion state that no longer matches it is removed.

### Copy Back Into the Original

After reconciliation:

- top-level plan fields are copied back
- existing exercises are matched by ID and updated
- new exercises are reparented into the original plan
- existing sets are matched by ID and updated
- new sets are reparented into the original exercise

### Delete Removed Children

If an exercise or set exists in the original but not in the editing copy, it is treated as deleted.

Before deletion, stale unresolved suggestion state attached to that target is cleaned up.

## Replacing an Exercise

Replacing an exercise reuses the same prescription identity but changes its catalog meaning.

When `applyEditingCopy` sees a changed `catalogID`, it clears linked historical performance references before writing the new exercise metadata back. That keeps old historical performance data from pretending it belongs to the new exercise identity.

## Delete and Cancel Behavior

### Deleting a Plan

`deleteWithSuggestionCleanup(context:)` removes unresolved suggestion state attached to the plan structure before the surrounding caller deletes the plan itself.

### Cancel While Editing an Existing Plan

- delete the editing copy
- save
- dismiss
- leave the original plan untouched

### Cancel While Creating a New Plan

- if the draft is empty, delete it immediately
- if the draft has content, confirm before discarding it

## Resume Rules

Only real new-plan drafts are resumable.

- `WorkoutPlan.resumableIncomplete`
  - incomplete plans where `isEditing == false`
- `WorkoutPlan.editingCopies`
  - persisted edit copies where `isEditing == true`

That means:

- unfinished new-plan creation can resume
- edit copies are never resumed

`RootView` deletes abandoned edit copies before normal resume logic runs.

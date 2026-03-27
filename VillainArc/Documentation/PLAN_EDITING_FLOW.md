# Plan Editing Flow

This document explains how workout plan authoring and editing work in VillainArc. The central rule is that existing completed plans are never edited in place. The edit path is centered in `WorkoutPlan+Editing.swift`, with `AppRouter` creating the correct draft and `WorkoutPlanView` handling save/cancel/delete UI.

## Main Files

- `Data/Models/Plans/WorkoutPlan.swift`
- `Data/Models/Plans/WorkoutPlan+Editing.swift`
- `Data/Services/App/AppRouter.swift`
- `Views/WorkoutPlan/WorkoutPlanView.swift`
- `Views/WorkoutPlan/WorkoutPlanDetailView.swift`
- `Data/Services/App/SpotlightIndexer.swift`

## The Core Rule

VillainArc has two authoring modes:

- brand-new plan creation
- copy-merge editing of an existing completed plan

For existing plans, the app always:

- creates a temporary persisted editing copy
- lets the user mutate that copy freely
- merges the copy back into the original on save
- deletes the copy on cancel

That keeps the original plan stable until commit time and gives the app one place to clean up stale unresolved suggestion state.

## Where Authoring Starts

### Blank Plan Creation

`AppRouter.createWorkoutPlan()`:

- checks for conflicting active flows
- creates a brand-new incomplete `WorkoutPlan`
- sets `activeWorkoutPlanOriginal = nil`
- presents `WorkoutPlanView`

This is a real persisted draft, not temporary view state. If the app is interrupted, it can resume later through `WorkoutPlan.resumableIncomplete`.

### Plan Creation From a Workout

`AppRouter.createWorkoutPlan(from:)`:

- checks for conflicting active flows
- creates `WorkoutPlan(from: workout)`
- converts the new editable draft from canonical kg into the current user unit
- links `workout.workoutPlan` to that draft
- sets `activeWorkoutPlanOriginal = nil`
- presents `WorkoutPlanView`

This is the editable completed-workout-detail path, not the summary "save as plan" path.

### Editing an Existing Completed Plan

`AppRouter.editWorkoutPlan(_:)`:

- only allows completed, non-editing plans
- checks for conflicting active flows
- calls `plan.createEditingCopy(context:)`
- converts the copy from canonical kg into the current user unit
- stores the original in `activeWorkoutPlanOriginal`
- presents the copy in `WorkoutPlanView`

`WorkoutPlanDetailView` is the normal UI entry point.

## The Editing Copy

`WorkoutPlan.createEditingCopy(context:)`:

- creates a new incomplete `WorkoutPlan`
- marks it `isEditing = true`
- copies top-level fields such as title, notes, and favorite state
- deep-copies exercises and sets into the new plan
- preserves exercise and set IDs so merge logic can align original and copy later

The copy is persisted SwiftData, not ephemeral local state. That matters because:

- the editor can bind directly to real models
- launch cleanup can safely discard abandoned edit copies
- the original plan stays untouched until save

## What the User Edits

`WorkoutPlanView` edits the draft copy directly.

At a high level the user can:

- change title and notes
- add, remove, and reorder exercises
- replace an exercise with a different catalog exercise
- edit rep-range settings
- add and remove sets
- edit set type, target load, target reps, target rest, and target RPE

While the draft is on screen, weight values use the current user unit. Save converts them back to canonical kg before merge or final commit.

When editing an existing plan, adding a set first tries to restore the next unused tail-set identity from the original plan before falling back to a brand-new set. That preserves original set IDs for common delete-and-readd cases.

## Saving a New Plan

For brand-new drafts, `WorkoutPlanView`:

- converts target weights back to kg
- marks the plan completed if needed
- clears active performance references from already completed linked sessions
- saves
- Spotlight-indexes the plan
- reindexes linked splits

There is no merge step because there is no protected original plan behind the draft.

## Saving an Edit to an Existing Plan

For an existing completed plan, `WorkoutPlanView`:

1. converts the editing copy back to canonical kg
2. calls `originalPlan.applyEditingCopy(plan, context: context)`
3. deletes the temporary editing copy
4. saves
5. Spotlight-indexes the original plan
6. reindexes any linked splits

The real merge logic lives inside `applyEditingCopy`.

## What `applyEditingCopy` Does

`WorkoutPlan.applyEditingCopy(_ copy: WorkoutPlan, context: ModelContext)` does three jobs:

1. reconcile unresolved suggestion state invalidated by the manual edit
2. copy values from the editing copy back into the original
3. delete removed exercises and sets, then reindex ordering

### 1. Reconcile Unresolved Suggestion State

This happens before values are copied back.

The original plan is compared against the editing copy. If the user manually changed a field that an unresolved suggestion was still targeting, the stale event is deleted.

That reconciliation covers:

- exercise rep-range mode
- exercise rep-range lower bound
- exercise rep-range upper bound
- exercise rep-range target
- set type
- set target load
- set target reps
- set target rest
- replacing an exercise with a different catalog exercise

Important detail:

- cleanup is keyed off `event.outcome == .pending`
- decision state does not protect the event

So an accepted or rejected event can still be deleted if its outcome is unresolved and the manual edit invalidates the target it needed.

### 2. Copy Values Back Into the Original Plan

After reconciliation, the original plan is updated from the copy.

At the plan level:

- title
- notes

At the exercise level:

- existing exercises are matched by ID and updated
- new exercises are reparented into the original plan
- copied metadata and rep-range values are written back

At the set level:

- existing sets are matched by ID and updated
- new sets are reparented into the original exercise
- target values and ordering are written back

### 3. Delete Removed Children

If an exercise or set exists in the original plan but not in the editing copy, it is treated as deleted.

Before deletion, unresolved suggestion events attached to that target are cleaned up. Then the model is deleted and the remaining exercises/sets are reindexed.

## Replacing an Exercise

Replacing an exercise is a special case because the original prescription identity is being reused for a different catalog exercise.

When `applyEditingCopy` sees a changed `catalogID`, it clears linked historical performance references on the original prescription before writing the new metadata back.

That keeps completed session history valid without pretending older performances still belong to the new exercise identity.

## Deleting a Plan

`deleteWithSuggestionCleanup(context:)` is the model helper used before actual deletion. It:

- removes unresolved suggestion events still attached to the plan structure
- prepares the plan to be deleted

The surrounding view/caller path is responsible for:

- deleting the plan record itself
- deleting any temporary editing copy when needed
- updating Spotlight for the plan
- reindexing linked workout splits

## Deleting the Last Exercise

VillainArc does not allow an existing/completed plan flow to silently persist as an empty plan.

If deleting the last exercise would leave no exercises:

- brand-new incomplete drafts can simply be discarded
- completed plans or edit-existing flows escalate into full plan deletion confirmation

When deleting an existing plan while editing, the app deletes both:

- the original completed plan
- the temporary editing copy

## Canceling

Cancel behavior depends on authoring mode.

### Cancel While Editing an Existing Plan

- delete the editing copy
- save
- dismiss
- leave the original plan untouched

### Cancel While Creating a New Plan

- if the draft is empty, delete it immediately
- if the draft has content, confirm before discarding it

There is no protected original plan in this path, so discarding the draft means discarding the work.

## Startup and Resume Behavior

Only real new-plan drafts are resumable.

- `WorkoutPlan.resumableIncomplete` returns incomplete plans where `isEditing == false`
- `WorkoutPlan.editingCopies` returns persisted edit copies where `isEditing == true`

That means:

- unfinished new-plan creation can resume on launch
- edit copies are never resumed as active authoring flows

`RootView.cleanupEditingWorkoutPlanCopies()` deletes abandoned edit copies before normal launch resume runs.

## Relationship to Suggestions

Plan editing does not accept, reject, or defer suggestions. That belongs to:

- workout summary review
- deferred pre-workout review
- the plan-level suggestions sheet

Manual editing simply establishes a new source of truth for the plan. If unresolved suggestion state no longer matches that source of truth, the stale event is deleted.

# Workout Plan Suggestion Flow

This document describes the actual implementation of the workout-plan suggestion system in VillainArc, starting from `WorkoutSummaryView` and following the full lifecycle through plan creation, suggestion generation, review, application, and later outcome resolution.

It is based on the current code in:

- `Views/Workout/WorkoutSummaryView.swift`
- `Views/Workout/WorkoutSessionContainer.swift`
- `Views/Suggestions/DeferredSuggestionsView.swift`
- `Views/Suggestions/SuggestionReviewView.swift`
- `Data/Services/Suggestions/SuggestionGenerator.swift`
- `Data/Services/Suggestions/RuleEngine.swift`
- `Data/Services/Suggestions/MetricsCalculator.swift`
- `Data/Services/Suggestions/SuggestionDeduplicator.swift`
- `Data/Services/Suggestions/OutcomeResolver.swift`
- `Data/Services/Suggestions/OutcomeRuleEngine.swift`
- `Data/Services/Suggestions/AITrainingStyleClassifier.swift`
- `Data/Services/Suggestions/AITrainingStyleTools.swift`
- `Data/Services/Suggestions/AIOutcomeInferrer.swift`
- `Data/Models/Plans/WorkoutPlan.swift`
- `Data/Models/Plans/WorkoutPlan+Editing.swift`
- `Data/Models/Plans/ExercisePrescription.swift`
- `Data/Models/Plans/SetPrescription.swift`
- `Data/Models/Plans/PrescriptionChange.swift`
- `Data/Models/Plans/SuggestionGrouping.swift`
- `Data/Models/Sessions/WorkoutSession.swift`
- `Data/Models/Sessions/ExercisePerformance.swift`

## Core Model Pieces

The system has four main layers:

- `WorkoutSession`: what the user actually did in a workout.
- `WorkoutPlan`: the current prescription baseline.
- `ExercisePrescription` / `SetPrescription`: the exercise- and set-level targets inside a plan.
- `PrescriptionChange`: a suggested change, user decision, and later outcome record.

`PrescriptionChange` is the central record. It stores:

- where the suggestion came from (`source`, usually `.rules`)
- which session triggered it (`sessionFrom`)
- which performance data triggered it (`sourceExercisePerformance`, `sourceSetPerformance`)
- which plan/prescription it targets (`targetPlan`, `targetExercisePrescription`, `targetSetPrescription`)
- what the change was (`changeType`, `previousValue`, `newValue`)
- what style context was used (`trainingStyle`)
- what the user did with it (`decision`)
- how it turned out later (`outcome`, `outcomeReason`, `evaluatedInSession`)

## Lifecycle States

There are two separate state machines:

### Suggestion decision

- `pending`: new suggestion, not reviewed yet
- `accepted`: user applied it
- `rejected`: user declined it
- `deferred`: user postponed it
- `userOverride`: user changed the plan manually in a way that matched the suggestion category

### Suggestion outcome

- `pending`: not evaluated yet
- `good`: change looks appropriate
- `tooAggressive`: target seems too hard
- `tooEasy`: target seems too easy
- `ignored`: the suggested target was not really followed
- `userModified`: the plan was manually edited before normal outcome evaluation

## Where The Flow Starts

The normal post-workout flow starts in `WorkoutSummaryView`.

`WorkoutSession.finish(...)` moves a workout to `.summary`. `WorkoutSessionContainer` then renders `WorkoutSummaryView` for `.summary` and `.done`.

When `WorkoutSummaryView` appears, it does two important things in `.task(id: workout.id)`:

1. `loadPRs()`
2. `generateSuggestionsIfNeeded()`

`generateSuggestionsIfNeeded()` only runs when `workout.workoutPlan != nil`.
It also exits early if `sessionSuggestions` for that summary already exist, which prevents duplicate suggestion creation for the same session.

That means suggestion generation is tied to a workout being linked to a plan. A freeform workout does not participate until it is saved as a plan.

## Saving A Freeform Workout As A Plan

If the user started a fresh freeform session, `workout.workoutPlan` is `nil` until they tap `Save as Workout Plan` in `WorkoutSummaryView`.

That button does this:

1. Creates `WorkoutPlan(from: workout, completed: true)`.
2. Inserts the plan.
3. Assigns `workout.workoutPlan = plan`.
4. Saves context.
5. Indexes the plan for Spotlight.
6. Immediately runs `generateSuggestionsIfNeeded()`.

`WorkoutPlan(from: workout, completed: true)` is important:

- it copies workout title and notes into the plan
- it creates `ExercisePrescription`s from the workout’s `ExercisePerformance`s
- each `ExercisePerformance` is linked back to its new `ExercisePrescription`
- each `SetPerformance` is linked to its new `SetPrescription`

Because of that link-up, the just-finished workout can immediately be used as the trigger session for suggestion generation, even though it started freeform.

In practice:

- outcome resolution runs first, but usually finds nothing on a brand-new plan
- suggestion generation runs next
- the generated suggestions show in the same summary screen under the new plan section

If the rules do not have enough evidence yet, the summary shows the empty-state message instead of suggestions.

## Starting A Workout From A Plan

The plan-backed workout flow starts in `AppRouter.startWorkoutSession(from:)`.

That method:

1. creates `WorkoutSession(from: plan)`
2. sets `origin = .plan`
3. links `workoutSession.workoutPlan = plan`
4. copies prescriptions into workout performances
5. updates `plan.lastUsed`

Before presenting the workout, it checks `pendingSuggestions(for: plan, in: context)`.

- if there are pending or deferred suggestions, session status becomes `.pending`
- if there are none, the session stays `.active`

`WorkoutSessionContainer` uses `statusValue` to choose the UI:

- `.pending` -> `DeferredSuggestionsView`
- `.active` -> `WorkoutView`
- `.summary` / `.done` -> `WorkoutSummaryView`

## What DeferredSuggestionsView Actually Does

`DeferredSuggestionsView` is the gate before a plan-based workout starts.

It loads all `pending` and `deferred` suggestions for the plan and groups them with `groupSuggestions(...)`.

From there the user can:

- accept a group
- reject a group
- accept all
- skip all

Accepting does two things:

1. sets `decision = .accepted`
2. mutates the live plan immediately with `applyChange(...)`

Rejecting does not mutate the plan. It only sets `decision = .rejected`.

Skipping all marks every remaining `pending` or `deferred` change as `rejected`.

The view also has two automatic behaviors:

- if no pending or deferred suggestions remain on load (e.g. they were resolved between session creation and view appearance), the view immediately transitions to `.active` without showing the review screen
- after each individual accept or reject action, the view checks if any undecided changes remain and automatically proceeds to the workout if none are left

Once everything is decided, the screen moves the session to `.active` and the workout begins.

## What “Accept” Actually Changes

`applyChange(...)` in `SuggestionReviewView.swift` mutates the live `WorkoutPlan` directly.

Current behavior:

- weight change -> updates `SetPrescription.targetWeight`
- reps change -> updates `SetPrescription.targetReps`
- rest change -> updates `SetPrescription.targetRest`
- set type change -> updates `SetPrescription.type`
- rep-range change -> updates `RepRangePolicy`

So once a suggestion is accepted, the next workout is performed against the updated prescription.

## Suggestion Generation

Suggestion generation is handled by `SuggestionGenerator.generateSuggestions(for:context:)`.

It only runs when the session is linked to a plan.

For each exercise in the session, it:

1. gets the linked `ExercisePrescription`
2. collects complete sets from the current performance
3. fetches completed history for that `catalogID`
4. resolves training style
5. builds an `ExerciseSuggestionContext`
6. runs `RuleEngine.evaluate(context:)`
7. appends the candidate changes

After all exercises are processed, it runs `SuggestionDeduplicator.process(...)`.

### History Source

History comes from `ExercisePerformance.matching(catalogID:)`.

That fetch only returns performances whose parent `WorkoutSession.status == .done`.

The current workout is not in that history fetch yet, so `RuleEngine` prepends the current performance itself through `recentPerformances(context)`.

That means rules always evaluate the current workout plus prior completed workouts.

## Training Style Resolution

Training style is resolved before rules run.

The system first tries deterministic classification with `MetricsCalculator.detectTrainingStyle(...)`.

If deterministic classification returns `.unknown`, it can call `AITrainingStyleClassifier`.

The AI classifier is used only as a fallback. It is not the default path.

Resolved style is stored on each generated `PrescriptionChange` so outcome resolution can reuse the same style context later.

Current training styles:

- `straightSets`
- `ascendingPyramid`
- `descendingPyramid`
- `ascending`
- `topSetBackoffs`
- `unknown`

## Primary Progression Sets

The rule engine does not just look at every set equally.

`MetricsCalculator.selectProgressionSets(...)` chooses the “primary progression sets” based on style:

- `straightSets`: all ordered working candidates
- `topSetBackoffs`: the heavy cluster near the top weight
- `ascending` / pyramid styles: the heavy cluster around peak weight
- `unknown`: the same heavy-cluster approach (0.95 threshold) as pyramid/ascending styles

This matters because progression rules are evaluated on those primary sets, not automatically on every set in the exercise.

That is the main way the system handles top-set/backoff and pyramid structures differently from straight sets.

## Rule Engine Structure

`RuleEngine.evaluate(context:)` runs rules in four buckets:

1. progression suggestions
2. safety and cleanup suggestions
3. plateau suggestions
4. set-type hygiene suggestions

Plateau suggestions are skipped when the exercise should simply hold steady.

### Progression Rules

These try to advance the prescription when performance supports it.

#### 1. Large overshoot progression

If the user clearly overshoots the target in one session, weight can jump immediately.

- range mode: primary sets all hit `upper + 3`
- target mode: primary sets all hit `target + 4`

This creates:

- `increaseWeight`
- and for range mode, usually `decreaseReps` back to the lower bound

#### 2. Immediate range progression

If primary sets all hit the top of a rep range in the current session, the engine increases weight immediately and usually resets reps down to the lower bound.

This is the fast one-session progression path for range mode.

#### 3. Immediate target progression

If primary sets all exceed the target reps in the current session, the engine increases weight immediately.

This is the fast one-session progression path for target mode.

#### 4. Confirmed range progression

If the current session does not qualify for immediate load progression, but the last two sessions were both near the top of the rep range, the engine still progresses load.

Near-top here is `upper - 1` on all primary sets.

#### 5. Confirmed target progression

If the current session does not qualify for immediate load progression, but the last two sessions both reached the target on all primary sets, the engine progresses load.

#### 6. Steady rep increase within range

If the same working set has repeated the same reps at the same weight across recent sessions, and it is inside the current range but not already ready for load progression, the engine suggests `increaseReps`.

This is the “progress reps first” rule inside a range without changing load yet.

### Safety And Cleanup Rules

These are meant to correct prescriptions that are mismatched with what the user can actually do.

#### 1. Below-range weight decrease

If the user is below the rep floor in 2 of the last 3 sessions while attempting the prescribed load, the engine suggests `decreaseWeight`.

#### 2. Reduced weight to hit reps

If the user lowered the load in recent sessions in order to hit reps, the engine suggests reducing the prescribed weight to match reality.

#### 3. Match actual weight

If the user has consistently trained at a meaningfully different weight for three sessions, the engine suggests updating the prescription weight to that stable average.

### Hold-Steady Gate

Before plateau rules run, the engine checks `shouldHoldSteady(context)`.

This is the “you are close enough that we should collect another data point before making a recovery or volume adjustment” gate.

If progression and safety rules found nothing, and the user is on track enough, plateau suggestions are skipped.

### Plateau Rules

These run only if the engine is not already holding steady.

#### 1. Short-rest performance drop

If actual rest is materially shorter than prescribed and reps fall off across sets, the engine suggests `increaseRest`.

#### 2. Stagnation increase rest

If estimated 1RM has been flat for about three sessions and the user is struggling to hit targets, the engine suggests `increaseRest`.

For top-set or descending-heavy styles, the stagnation check uses progression sets rather than the whole exercise.

### Set-Type Hygiene Rules

These are structural cleanup suggestions.

They do not mainly try to drive overload. They try to keep the plan aligned with how the user actually logs sets.

Current rules:

- `dropSetWithoutBase`
- `warmupActingLikeWorkingSet`
- `regularActingLikeWarmup`
- `setTypeMismatch`

## Deduplication

After rules generate raw candidates, `SuggestionDeduplicator` cleans them up in two passes.

### Logical conflict pass

This operates in the same logical scope:

- same target set, or
- same target exercise for exercise-level changes

Examples:

- if both `increaseWeight` and `increaseRest` exist in the same scope, `increaseRest` is dropped
- if both `increaseWeight` and `decreaseWeight` exist in the same scope, `increaseWeight` is dropped

### Property conflict pass

Then it keeps one suggestion per `(target, property)` using priority, source, magnitude, and creation time.

This is what turns multiple candidate rules into the final set shown to the user.

## Suggestion Review At Summary Time

When the summary belongs to a plan-backed workout, suggestions generated from that workout are shown immediately in `WorkoutSummaryView`.

Those suggestions are fetched with:

- `@Query` on `PrescriptionChange`
- filtered by `sessionFrom?.id == workout.id`

At the summary screen, the user can:

- accept a group
- reject a group
- defer a group

If they leave the summary with suggestions still `pending`, `finishSummary()` calls `deferRemainingSuggestions()`, which converts those pending suggestions to `deferred`.

That is why plan workouts can surface those same suggestions again next time in `DeferredSuggestionsView`.
After that, `finishSummary()` rebuilds exercise histories while the just-finished workout is still included, then marks the workout `done`, saves, and dismisses the summary screen.

`WorkoutSummaryView` also guards suggestion actions while save is in progress, so accept/reject/defer handlers stop mutating changes once the finish path starts.

## Outcome Resolution

Outcome resolution happens before new suggestions are generated for a plan-backed workout summary.

`WorkoutSummaryView.generateSuggestionsIfNeeded()` does:

1. `OutcomeResolver.resolveOutcomes(for: workout, context: context)`
2. `SuggestionGenerator.generateSuggestions(for: workout, context: context)`

So the system first scores older suggestions against the just-finished workout, then creates new ones from the new evidence.

### Which Changes Are Eligible

`OutcomeResolver.gatherEligibleChanges(for:)` only considers changes that are:

- attached to prescriptions linked to exercises actually performed in this workout
- still `outcome == .pending`
- created before this workout started

That prevents same-session suggestions from being evaluated by the session that created them.

It also means if an exercise was not performed in the current workout, its old suggestions are left alone for now.

### Grouping For Outcome Resolution

Outcome resolution groups changes similarly to the suggestion review UI:

- first by `targetExercisePrescription`
- then set-level changes by `targetSetPrescription`
- exercise-level changes as a single rep-range group

That grouping is important because AI receives group context, not just isolated changes.

### Deterministic Outcome Rules

`OutcomeRuleEngine` runs first for every change.

It uses the stored `change.trainingStyle` when available. If a stored style is missing or unknown, it falls back to re-detecting style from the actual workout performance.

Current outcome logic:

- weight / reps / rest changes: check whether the athlete followed the suggested direction, then classify by rep performance
- rep-range changes: evaluate working-set reps against the new range or target
- set-type changes: binary match or not

Outcome rules are directional, not purely exact-match:

- getting near the new target counts
- moving clearly in the suggested direction can also count
- overshooting in the suggested direction is not automatically treated as ignored

### AI Outcome Inference

After rule evaluation, `OutcomeResolver` builds AI inputs per group.

There are two AI modes:

#### Applied mode

Used when a group contains `accepted` or `userOverride` changes.

The AI sees:

- the change group
- the prescription snapshot from before the applied change
- the trigger workout that caused the suggestion
- the current workout being evaluated
- training style
- the deterministic rule result

#### Rejected mode

Used when none of the group’s changes were applied.

This is an important edge case.

Rejected suggestions are still evaluated later. The AI is asked whether:

- the user effectively followed the suggestion anyway, or
- the suggestion would likely have helped even though it was not applied

That allows the system to learn from rejected suggestions later, not just accepted ones.

### Prescription Snapshot Reconstruction

For AI evaluation of applied changes, `OutcomeResolver` rebuilds the “before” prescription snapshot by reverting accepted or overridden changes from the current live prescription.

### Merge Rules

Rules are the primary outcome source.

AI does not automatically win.

Current merge behavior:

- if rules are unavailable, AI can decide
- if rules exist and AI agrees, rules are used
- if AI disagrees, it only overrides when:
  - rule confidence is below `0.7`
  - and AI confidence is at least `0.75`

The resolved outcome is then written back to the `PrescriptionChange`.

## Scenario Walkthroughs

### Scenario 1: User starts a fresh session and saves it as a plan at the end

1. User starts a freeform `WorkoutSession`.
2. They complete it and land in `WorkoutSummaryView`.
3. They tap `Save as Workout Plan`.
4. A completed `WorkoutPlan` is created from the workout.
5. The workout is linked to that plan.
6. Outcome resolution runs first.
   Usually nothing resolves here because this is a brand-new plan.
7. Suggestion generation runs.
8. Suggestions, if any, appear immediately in the same summary.
9. If the user leaves suggestions undecided, they become `deferred`.

This flow works because saving as a plan attaches the just-completed performances to newly created prescriptions.

### Scenario 2: User uses a plan for the first time

1. `AppRouter.startWorkoutSession(from:)` creates a plan-based session.
2. If the plan has no pending or deferred suggestions, the session opens directly in `WorkoutView`.
3. The workout ends and lands in `WorkoutSummaryView`.
4. Outcome resolution runs against any older eligible suggestions.
   Often there are none on a true first use.
5. Suggestion generation runs against the workout performance and historical completed sessions.
6. New suggestions are shown in the summary.

### Scenario 3: User uses a plan when suggestions already exist

1. Starting the workout checks `pendingSuggestions(for: plan, in: context)`.
2. If suggestions exist, the session opens in `DeferredSuggestionsView` first.
3. The user accepts or rejects before the workout begins.
4. Accepted suggestions mutate the plan immediately.
5. Rejected suggestions remain rejected but still keep `outcome == .pending`.
6. The user performs the workout against the resulting plan.
7. At summary time, older eligible changes are evaluated against the just-finished session.
8. After that, new suggestions are generated from the current workout.

### Scenario 4: User edits the plan manually instead of accepting a suggestion

Plan editing uses an edit copy.

When the user saves the edited copy back onto the original plan:

- the copy is diffed against the original
- matching pending/deferred suggestions on the original are marked `decision = .userOverride`
- if their outcome was still pending, outcome becomes `userModified`

This is how manual plan edits are tracked without creating new `PrescriptionChange` rows for those edits.

## Edge Cases And Important Behaviors

### Rejected suggestions are still evaluated later

This is intentional.

Decision and outcome are separate.

A rejected suggestion can still later resolve as:

- `good` if the user effectively followed it anyway
- `good` for certain safety-style cases if not applying it appears to have hurt performance
- `ignored` if the later workout does not support it

### Same-session suggestions are never self-evaluated

Outcome resolution only looks at changes created before the workout started.

So a workout cannot generate a suggestion and resolve its outcome in the same pass.

### Deferred suggestions are surfaced before the next plan workout

If the user leaves summary-generated suggestions unresolved, `finishSummary()` converts remaining `pending` changes to `deferred`.

Those are then shown in `DeferredSuggestionsView` before the next workout from that plan starts.

`DeferredSuggestionsView` also guards its accept/reject-all and transition actions so the session only advances to `.active` once.

### If an exercise is not performed, its old changes stay pending

Outcome resolution only groups changes when it can match the target prescription to an exercise performance in the current workout.

If the exercise was skipped, there is no evaluation for that change yet.

### Deleting plan/set/exercise objects removes only pending targeted changes

Deletion and editing cleanup are explicit, not just passive cascade behavior.

`WorkoutPlan+Editing.swift` does this:

- deleting a whole plan removes only `targetedChanges` whose `outcome == .pending`
- deleting an exercise removes pending changes attached to that exercise plus its sets
- deleting a set removes pending changes attached to that set
- editing a value that matches a pending or deferred suggestion marks that change `decision = .userOverride` and `outcome = .userModified` (skips changes whose `source == .user`, and only applies when the current decision is `pending` or `deferred`, not if already accepted or rejected)

Resolved suggestion history is preserved so later analytics and learning still have that evidence.

That is why structural deletions do not become `userOverride`.

They are removed with the object they targeted.

### Edit copies are disposable

Editing an existing plan creates a persisted edit copy with `isEditing = true`.

Changes are only applied to the real plan on save.

If the user cancels or force-quits mid-edit, the original plan is unchanged. Startup cleanup deletes leftover editing copies.

## How This Supports Later Learning

The current system is already structured in a way that can support learning later because each `PrescriptionChange` stores:

- the trigger context
- the target context
- the training style used
- the user’s decision
- the later outcome
- the reason attached to that outcome

The cleanest rollout path for learning is:

1. learn from accepted suggestions first
2. then learn from rejected suggestions using later outcome resolution
3. then learn from `userOverride` once the app stores the exact manual value the user changed to

The first learning layer should probably be calibration, not full autonomous policy generation.

That means using outcomes to adjust things like:

- confidence of specific rule families
- how aggressive load jumps should be
- whether a context responds better to rest, reps, or volume changes
- how quickly plateau rules should trigger

Once those signals are reliable, the system can move from “fixed rules with outcome tracking” to “rules tuned by observed outcomes.”

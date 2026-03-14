# Suggestion and Outcome Flow

This document explains how VillainArc handles plan suggestions and their later outcomes: what happens when a plan-based workout reaches summary, how older suggestions are evaluated, how new suggestions are created, how accept/reject/defer works, how deferred suggestions block the next plan workout, and how manual plan edits clean up stale suggestion state.

## Main Files

- `Views/Workout/WorkoutSummaryView.swift`
- `Views/Suggestions/DeferredSuggestionsView.swift`
- `Views/Suggestions/SuggestionReviewView.swift`
- `Data/Services/Suggestions/Generation/SuggestionGenerator.swift`
- `Data/Services/Suggestions/Generation/RuleEngine.swift`
- `Data/Services/Suggestions/Generation/SuggestionDeduplicator.swift`
- `Data/Services/Suggestions/Outcomes/OutcomeResolver.swift`
- `Data/Services/Suggestions/Outcomes/OutcomeRuleEngine.swift`
- `Data/Models/Suggestions/SuggestionEvent.swift`
- `Data/Models/Suggestions/PrescriptionChange.swift`
- `Data/Models/Suggestions/SuggestionGrouping.swift`
- `Data/Models/Plans/WorkoutPlan+Editing.swift`

## Core Model

The suggestion system is built around two persisted model layers:

- `SuggestionEvent`: the grouped review/evaluation unit
- `PrescriptionChange`: the scalar change rows inside that event

### SuggestionEvent

`SuggestionEvent` stores:
- the source session (`sessionFrom`)
- the target exercise identity (`catalogID`)
- grouped decision state
- grouped outcome state
- frozen trigger snapshots
- optional evaluated-performance snapshot
- training style
- reasoning text
- child `PrescriptionChange` rows

This is the main object shown in review UI and the main object whose decision/outcome state changes over time.

The important detail is why those fields exist:
- `triggerTargetSnapshot` freezes what the plan prescribed when the suggestion was created
- `triggerPerformanceSnapshot` freezes what the user actually did in the triggering workout
- `evaluatedPerformanceSnapshot` later freezes the workout that was used to judge whether the suggestion worked
- `trainingStyle` preserves how the generator interpreted the exercise so later outcome evaluation can use the same lens
- `changeReasoning` and `outcomeReason` give both the review UI and future debugging a human-readable explanation
- `targetExercisePrescription` and optional `targetSetPrescription` keep the live plan target on the event itself
- `targetSetIndex` preserves the intended target slot even if ordering shifts or the live set reference disappears
- `category` identifies the event family (`performance`, `recovery`, `structure`, `repRangeConfiguration`, and future buckets) so deduplication and unresolved-overlap blocking can reason at the event level

### PrescriptionChange

Each `PrescriptionChange` stores one concrete mutation, such as:
- weight increase/decrease
- reps increase/decrease
- rest increase/decrease
- set type change
- rep range changes

So an event can represent one grouped recommendation while still carrying one or more exact plan deltas.

The scalar rows deliberately do not own live plan targets anymore. They only store:
- the change type
- the previous value
- the new value

That keeps grouped suggestions coherent at the event level while preserving simple scalar before/after deltas that are easy to render, apply, and evaluate. Weight values are always stored in kg here, matching the canonical storage in `SetPrescription.targetWeight` and `SetPerformance.weight`; display conversion to the user's preferred unit happens only in the review UI.

## The Two State Machines

Suggestions have two separate lifecycles.

### Decision State

- `pending`: new and not reviewed
- `accepted`: user chose to apply it
- `rejected`: user chose not to apply it
- `deferred`: user postponed it for later

### Outcome State

- `pending`: not evaluated yet
- `good`: the suggestion looks like it worked
- `tooAggressive`: the change appears too hard
- `tooEasy`: the change appears too easy
- `ignored`: the user did not really follow the suggestion

The important distinction is:
- decision is about what the user chose
- outcome is about how that choice played out later

## Where the Flow Starts

The main suggestion lifecycle starts in `Views/Workout/WorkoutSummaryView.swift`.

When a plan-based workout reaches summary, `generateSuggestionsIfNeeded()` runs.

Its order is:
1. `OutcomeResolver.resolveOutcomes(for: workout, context: context)`
2. `SuggestionGenerator.generateSuggestions(for: workout, context: context)`

So the app first looks backward at older suggestions, then forward to create new ones.

This only runs when `workout.workoutPlan != nil`.

## Outcome Resolution

Outcome resolution happens in:
- `Data/Services/Suggestions/Outcomes/OutcomeResolver.swift`
- `Data/Services/Suggestions/Outcomes/OutcomeRuleEngine.swift`

The resolver gathers eligible older events by looking at the plan prescriptions linked to the current workout and finding events that are:
- still `outcome == .pending`
- older than the current workout
- already decided as `accepted` or `rejected`

Then it matches those events against the current workout’s performed exercises and sets.

### What Actually Counts as Eligible

Outcome resolution does not scan every historical suggestion in the database.

It starts from the current workout’s live prescription links:
- current `ExercisePerformance.prescription`
- current `SetPerformance.prescription`
- each prescription’s attached `SuggestionEvent`s

That means only suggestions still attached to the active plan structure are considered.

At the set level, the resolver is stricter:
- the event must still point at a live `targetSetPrescription`
- the current workout must contain a completed performed set still linked to that exact target set

If that evidence is missing, the resolver skips the event for now and leaves `outcome == .pending`.

### Deleted Sets, Deleted Exercises, and Skipped Evidence

This is the practical behavior:
- if a set-level suggestion targets a set that the user simply did not complete this session, there is no evaluation evidence yet, so the outcome stays pending
- if the user deletes a set or replaces an exercise during the session so the performed work is no longer linked to that original target, the resolver cannot confidently evaluate that suggestion in this workout
- if the target still exists in the plan, the event can remain pending and be evaluated in a later workout when a completed performed set is again linked to that same live target
- if the user manually edits the plan and removes or invalidates that unresolved target before evaluation, `WorkoutPlan+Editing` deletes the unresolved suggestion event instead of keeping stale outcome work around

So there are really two paths for unresolved suggestions:
- wait for a future workout if the target still exists
- get deleted during plan editing if the target itself was manually changed away

### Deterministic First, AI Second

`OutcomeRuleEngine` runs first for each change.

`AIOutcomeInferrer` is only a fallback for lower-confidence cases. The resolver can let AI override a rule result only when:
- the rule confidence is low
- AI confidence is high enough
- the AI outcome disagrees with the rule result

The merged outcome is written back to the `SuggestionEvent` itself:
- `outcome`
- `outcomeReason`
- `evaluatedAt`
- `evaluatedPerformanceSnapshot`

This is why outcomes are not tied only to accepted changes. Rejected suggestions can still get evaluated later if the user effectively trained in line with them anyway.

### How Change Types Are Judged

The deterministic rules are change-type specific:
- weight changes usually check whether the user actually moved toward or reached the new load, then classify the result by reps relative to the active rep policy
- rep changes check whether the user actually performed near the new rep target rather than the old one
- rest changes check whether the user actually rested near the new target and then whether reps landed in a good zone
- rep-range changes judge the full working-set distribution against the post-change range or target
- set-type changes are basically binary: did the performed set type match the new target type

There is one important category-specific exception:
- `warmupCalibration` weight changes are judged by whether the adjusted set still behaved like a warmup relative to the working/top-set anchor, not by the normal working-set progression lens

This is why event-level set targeting matters so much. For weight, reps, rest, and set-type changes, the resolver only evaluates a set-scoped event when it can match a completed performed set through the live `targetSetPrescription`. Historical fields like `targetSetIndex` and `SetPerformance.linkedTargetSetIndex` are still valuable for generation, frozen snapshots, and UI labeling, but they are not used as authority for current set-level outcome resolution.

## New Suggestion Generation

New suggestions are created in:
- `Data/Services/Suggestions/Generation/SuggestionGenerator.swift`
- `Data/Services/Suggestions/Generation/RuleEngine.swift`
- `Data/Services/Suggestions/Generation/SuggestionDeduplicator.swift`

### Generation Flow

For each exercise in the current plan-based session, the generator:
- finds the linked prescription
- gathers completed sets
- fetches completed history for that exercise
- resolves training style
- builds an `ExerciseSuggestionContext`
- asks `RuleEngine` for candidate `SuggestionEventDraft`s

After collecting drafts from all exercises, it:
- suppresses drafts that are blocked by unresolved incompatible events already attached to the same live target scope
- resolves remaining conflicts with `SuggestionDeduplicator`
- converts surviving drafts into persisted `SuggestionEvent`s with child `PrescriptionChange`s

### What Generation Looks At

Generation is not based on the current workout alone.

For each plan-backed exercise, the generator combines:
- the current session’s completed performed sets
- the current live prescription and rep-range policy
- recent completed performances for the same `catalogID`
- historical target snapshots from those earlier performances when available
- the resolved training style for picking the right progression sets

When the rule engine compares older workouts to the current prescription, it does not assume today’s target values were always true in the past.

For older performances it uses:
- `ExercisePerformance.originalTargetSnapshot`
- `SetPerformance.linkedTargetSetIndex`

That lets it ask questions like:
- what rep range was this exercise using in that earlier session?
- which performed set corresponded to target slot 1 or 2 back then?
- did the user actually attempt the prescribed weight at that time?

### Training Style

Training style is resolved through:
- `MetricsCalculator.detectTrainingStyle(...)` first
- `AITrainingStyleClassifier` only when deterministic style detection returns `.unknown`

So AI is a fallback, not the primary path.

### Main Rule Buckets

`RuleEngine` is organized into a few buckets:
- progression rules for immediate or confirmed load increases
- cleanup/safety rules for lowering load or matching the prescription to what the user is already doing
- plateau/rest rules when performance is stalling and recovery looks limiting
- set-type hygiene rules when warmup/working/drop-set structure no longer matches actual use
- exercise-level rep-range rules when the current mode or range no longer fits recent performance

In practice it looks at signals like:
- whether progression sets hit or overshot the top of a range or target
- whether the same reps and weight have repeated across recent sessions
- whether the user fell below the floor while still attempting the prescribed load
- whether the user has been consistently using meaningfully different weights than prescribed
- whether short rest appears to be hurting downstream sets
- whether estimated 1RM has plateaued across recent sessions
- whether recent set types consistently differ from the prescription
- whether recent rep evidence suggests a target should become a range, or a range should shift up or down

Most of those rules use the current session plus the last 1-3 completed performances for the same exercise.

### Current Session Plus Previous Performed Work

Inside `ExerciseSuggestionContext`, the current workout is treated as the newest performance and historical performances are appended after it.

That means generation can do things like:
- progress immediately when this session alone strongly justifies it
- require two recent sessions before confirming a load increase
- require three sessions before cleaning up weight drift or proposing an initial rep range

So the previous performed work is not only background context. It is part of the direct evidence window many generation rules use.

### Building the Persisted Event

Once drafts survive deduplication, `SuggestionGenerator` turns them into real `SuggestionEvent`s.

At that point it stores:
- the triggering workout session via `sessionFrom`
- the live target exercise and optional target set on the event itself
- the suggestion `category`
- a frozen target snapshot representing what the plan prescribed during the triggering session
- a frozen performance snapshot representing what the user actually performed in that session
- the resolved training style used when interpreting the exercise
- the grouped reasoning text
- one or more `PrescriptionChange` rows with the exact before/after scalar values

That stored context is what later makes review, deferral, outcome resolution, and history debugging possible even after live prescription links get cleared for historical sessions.

### Deduplication

`SuggestionDeduplicator` groups candidate drafts by target scope and then selects the compatible set of winners for that scope.

Current behavior:
- exercise-scoped drafts still keep only one winner
- set-scoped drafts may keep more than one event only when the categories are compatible
- right now the only allowed multi-event set combination is `performance` + `recovery`
- `structure`, `volume`, `warmupCalibration`, and `repRangeConfiguration` currently suppress other categories on the same set in the same pass

Its ordering preferences are:
- higher-priority categories first
- higher-priority change types first
- then drafts with more complete grouped changes
- then larger total magnitude

In practice this helps the app avoid showing conflicting suggestions for the same exercise or set target while still allowing a small number of sensible combinations, such as a load progression plus a recovery tweak.

### Unresolved Overlap Blocking

Before new drafts are deduplicated and persisted, `SuggestionGenerator` also checks the active plan for unresolved existing events on the same target scope.

If an unresolved event is already attached to the same exercise/set and its category is incompatible with the new draft, the new draft is suppressed for now.

That means:
- an unresolved set-level `performance` event blocks new set-level `performance` drafts for that same target
- an unresolved set-level `structure` event blocks everything else on that target
- exercise-level rep-range configuration suggestions do not pile up while an earlier one is still unresolved

This keeps the generator from repeatedly proposing overlapping changes before the older suggestion has been reviewed or evaluated.

## How Suggestions Are Reviewed in Summary

`WorkoutSummaryView` renders current-session suggestion events through:
- `groupSuggestions(...)`
- `SuggestionReviewView`

Each grouped row in `SuggestionReviewView` is a `SuggestionGroup`, which is a light wrapper around one `SuggestionEvent`.

At summary time, the user can:
- accept
- reject
- defer

The shared mutation helpers are in `SuggestionReviewView.swift`.

### Accept

`acceptGroup(...)` does two things:
- sets `event.decision = .accepted`
- applies each `PrescriptionChange` to the live plan immediately through `applyChange(...)`

That means accepted suggestions change the actual `WorkoutPlan` right away.

### Reject

`rejectGroup(...)`:
- sets `event.decision = .rejected`
- does not mutate the plan

### Defer

`deferGroup(...)`:
- sets `event.decision = .deferred`
- does not mutate the plan yet

### Leaving Summary With Pending Suggestions

When summary is finalized, `WorkoutSummaryView.finishSummary()` calls `deferRemainingSuggestions()`.

That converts any still-`pending` current-session suggestion events to `deferred`.

So the app never leaves summary with current-session suggestions still in `pending`. They become deferred review for the next plan-based session.

## How Deferred Suggestions Block the Next Plan Workout

Before a plan-based session starts logging, `AppRouter.startWorkoutSession(from:)` checks:

- `pendingSuggestionEvents(for: plan, in: context)`

If any `pending` or `deferred` events exist for that plan, the new session starts in `.pending` instead of `.active`.

`WorkoutSessionContainer` then shows `DeferredSuggestionsView` first.

### What Counts as Pending Before Workout Start

`pendingSuggestionEvents(...)` walks the plan’s exercise and set event relationships and returns unique `SuggestionEvent`s whose decision is:
- `pending`
- `deferred`

So the pre-workout gate is event-driven, not based on raw child changes by themselves.

## DeferredSuggestionsView

`Views/Suggestions/DeferredSuggestionsView.swift` is the pre-workout gate for unresolved plan suggestions.

It loads the plan’s pending/deferred events, groups them, and makes the user resolve them before the workout can really begin.

Available actions:
- accept one group
- reject one group
- accept all
- skip all

### Accept in Deferred Review

Accepting from `DeferredSuggestionsView` still uses `acceptGroup(...)`, so it:
- marks the event accepted
- mutates the live plan immediately

### Reject in Deferred Review

Rejecting marks the event rejected and leaves the plan unchanged.

### Accept All

Applies every pending/deferred event to the plan, marks them accepted, then moves the session to `.active`.

### Skip

Marks every pending/deferred event as rejected, then moves the session to `.active`.

### Transition to the Workout

The session only proceeds to `.active` when no unresolved pending/deferred events remain.

So deferred suggestions are not just a visual reminder. They are a real gate in the plan-based session lifecycle.

## How Suggestions Are Represented in the UI

The main UI helpers are in `Data/Models/Suggestions/SuggestionGrouping.swift`.

`groupSuggestions(...)`:
- groups `SuggestionEvent`s by target exercise
- sorts them by set/index order when possible
- builds `ExerciseSuggestionSection`s for the review UI

Each visible row is labeled using either:
- the live target set index
- the frozen target set index
- or “Rep Range” for exercise-level events

This is why the UI can still show a meaningful target label even when some live references are weaker or have already shifted.

## Manual Plan Editing and Pending Suggestions

Manual plan edits can make unresolved suggestion events stale.

That cleanup lives in `Data/Models/Plans/WorkoutPlan+Editing.swift`.

When a user edits a plan copy and applies it back to the original plan, the editing logic compares the edited copy against the original and deletes unresolved changes/events when the manual edit has already invalidated them.

Examples:
- changing a set’s target weight deletes matching unresolved weight changes for that set
- changing reps deletes matching unresolved reps changes
- changing rest deletes matching unresolved rest changes
- changing set type deletes matching unresolved set-type changes
- changing rep range values deletes matching unresolved rep-range changes
- changing an exercise to a different catalog exercise deletes pending outcome changes for the old prescription entirely

Important detail:
- this cleanup only deletes unresolved work where `event.outcome == .pending`

So manual editing is treated as the new source of truth for still-unresolved suggestion state.

## Freeform Workouts Saved as Plans

A freeform workout normally has no suggestion flow because `workout.workoutPlan == nil`.

That changes if the user taps “Save as Workout Plan” in summary.

That path:
- creates a new `WorkoutPlan(from: workout, completed: true)`
- links the session to that new plan
- backfills frozen target snapshots from the performed exercises
- immediately reruns the suggestion pipeline against that new plan-backed session

So a freeform workout can enter the suggestion system from summary if it is converted into a plan there.

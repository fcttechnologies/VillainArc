# Suggestion and Outcome Flow

This document explains how VillainArc handles plan suggestions and later outcomes: how suggestion events are created, where users review them, how deferred suggestions block the next plan workout, how later workouts evaluate prior changes, and how manual plan edits clean up stale unresolved events.

## Main Files

- `Views/Workout/WorkoutSummaryView.swift`
- `Views/Suggestions/DeferredSuggestionsView.swift`
- `Views/Suggestions/SuggestionReviewView.swift`
- `Views/Suggestions/WorkoutPlanSuggestionsSheet.swift`
- `Data/Models/Suggestions/SuggestionEvent.swift`
- `Data/Models/Suggestions/PrescriptionChange.swift`
- `Data/Models/Suggestions/SuggestionEvaluation.swift`
- `Data/Models/Suggestions/SuggestionGrouping.swift`
- `Data/Models/Suggestions/SuggestionSnapshots.swift`
- `Data/Services/Suggestions/Generation/SuggestionGenerator.swift`
- `Data/Services/Suggestions/Generation/RuleEngine.swift`
- `Data/Services/Suggestions/Generation/SuggestionDeduplicator.swift`
- `Data/Services/Suggestions/Outcomes/OutcomeResolver.swift`
- `Data/Services/Suggestions/Outcomes/OutcomeRuleEngine.swift`
- `Data/Models/Plans/WorkoutPlan+Editing.swift`

## Core Model

The suggestion system is built around three persisted layers:

- `SuggestionEvent`: one grouped review/evaluation unit
- `PrescriptionChange`: one scalar before/after mutation inside that event
- `SuggestionEvaluation`: one later-workout outcome evaluation for that event

### `SuggestionEvent`

`SuggestionEvent` stores:

- the source session through `sessionFrom`
- the live target exercise and optional live target set
- decision state
- outcome state
- the triggering performance through `triggerPerformance`
- the copied triggering set identity through `triggerTargetSetID`
- persisted evaluation rows
- required evaluation count
- the frozen load step used for weight-change suggestions through `weightStepUsed`
- training style
- confidence score and reasoning text
- child `PrescriptionChange` rows

One important modeling rule:

- live prescription relationships are the source of truth for current plan behavior
- copied target-set IDs and snapshots are the source of truth for historical matching
- `weightStepUsed` is the source of truth for historical load-change tolerance during outcome evaluation
- set indices are mainly for ordering and labeling in UI

`SuggestionEvent` does not duplicate the trigger-time target snapshot on itself anymore. It reaches that frozen context through `triggerPerformance.originalTargetSnapshot`.

### `PrescriptionChange`

Each `PrescriptionChange` stores one exact mutation, such as:

- weight increase/decrease
- reps increase/decrease
- rest increase/decrease
- set type change
- rep-range changes

Weight values here are canonical kg.

### `SuggestionEvaluation`

Each `SuggestionEvaluation` stores one later workout's evaluation of the event:

- the source workout session ID
- the evaluated `ExercisePerformance`
- the partial outcome for that workout
- confidence
- reason
- evaluation timestamp

That lets VillainArc accumulate evidence across more than one later session.

## The Two State Machines

Suggestions have two separate lifecycles.

### Decision State

- `pending`: new and not reviewed
- `accepted`: user chose to apply it
- `rejected`: user chose not to apply it
- `deferred`: user postponed it

### Outcome State

- `pending`: not evaluated yet
- `good`
- `tooAggressive`
- `tooEasy`
- `insufficient`
- `ignored`

Decision is about what the user chose. Outcome is about how that choice played out later.

## Where Suggestions Start

The main lifecycle starts in `WorkoutSummaryView`.

For plan-backed sessions, `generateSuggestionsIfNeeded()` does:

1. `OutcomeResolver.resolveOutcomes(for: workout, context: context)`
2. `SuggestionGenerator.generateSuggestions(for: workout, context: context)`

So the app always looks backward at older unresolved events before it looks forward and creates new ones.

## Review Surfaces

VillainArc has three suggestion surfaces.

### 1. Summary Review

`WorkoutSummaryView` renders the current session's newly generated events through `SuggestionReviewView`.

Available actions:

- accept
- reject
- defer

Action behavior:

- accept = set `decision = .accepted`, apply all `PrescriptionChange`s to the live plan, and save
- reject = set `decision = .rejected`, leave the plan unchanged
- defer = set `decision = .deferred`, leave the plan unchanged

When summary closes, any still-`pending` current-session events are automatically converted to `deferred`.

### 2. Deferred Pre-Workout Review

If a plan still has `pending` or `deferred` events, `AppRouter.startWorkoutSession(from:)` starts the new workout in `.pending`.

`DeferredSuggestionsView` blocks entry to active logging until those events are resolved.

Available actions:

- accept one
- reject one
- accept all
- skip all

Important detail:

- accepting a suggestion mutates the plan and also hydrates the already-created pending session copy through shared `acceptGroup(...)`
- rejecting only changes decision state
- `Skip All` marks pending/deferred events as `rejected` before the workout proceeds

The workout only transitions to `.active` once there are no pending or deferred events left.

### 3. Plan-Level Suggestions Sheet

`WorkoutPlanDetailView` can open `WorkoutPlanSuggestionsSheet`, which has two tabs:

- `To Review`
  - backed by pending or deferred decision state
  - used for suggestions that still need user action
- `Awaiting Outcome`
  - currently used for accepted suggestions whose outcomes are still unresolved

The underlying data helpers can still reason about accepted and rejected unresolved events, but the current Awaiting Outcome UI is focused on accepted changes that were actually applied to the live plan.

This surface does not generate anything new. It is a management view over suggestion state already attached to the plan.

## Generation

New suggestions are created in:

- `SuggestionGenerator`
- `RuleEngine`
- `SuggestionDeduplicator`

### What Generation Looks At

For each plan-backed exercise in the current session, generation combines:

- the current session's completed sets
- the current live prescription
- recent completed performances for the same `catalogID`
- frozen target snapshots from older performances when available
- resolved training style

Historical matching is UUID-based rather than set-index based:

- each historical `SetPerformance` stores `originalTargetSetID`
- each frozen snapshot carries copied target-set IDs

That lets generation keep matching the right logical target even after live plan set order changes.

Load-change generation is also equipment-aware:

- pure bodyweight prescriptions do not emit weight increase/decrease suggestions
- once a bodyweight exercise explicitly tracks external load, it can emit load-change suggestions
- double dumbbells and double cables use per-side load semantics
- machine-assisted exercises invert harder/easier load semantics

### Training Style

Training style is resolved through:

- `MetricsCalculator.detectTrainingStyle(...)` first
- `AITrainingStyleClassifier` only when deterministic detection returns `.unknown`

The AI fallback is confidence-gated:

- it returns a style plus confidence
- the app only accepts the AI style when confidence is greater than `0.5`
- the history tool used by the classifier is capped at 3 recent performances

That resolved style is then reused for:

- choosing the progression evidence window
- storing how the event was interpreted
- later outcome evaluation

### Draft Conflict Handling

Before drafts become persisted events, the generator does two conflict passes.

#### 1. Blocked by Older Unresolved Events

If an unresolved older event is already attached to the same target scope and the categories are incompatible, the new draft is suppressed for now.

#### 2. Dedup Within the Current Generation Pass

`SuggestionDeduplicator` resolves conflicts among newly generated drafts.

Important behavior:

- exercise-scoped drafts still keep one winner
- set-scoped drafts can keep more than one event only when categories are compatible
- default allowed coexistence is still `performance` + `recovery` on the same set
- one narrow extra coexistence rule allows `changeSetType -> .working` alongside one same-set compatible draft

Its ordering prefers:

- category priority
- evidence strength
- change priority
- richer grouped changes
- larger magnitude

### Persisted Event Creation

Once drafts survive blocking and deduplication, `SuggestionGenerator` turns them into `SuggestionEvent`s with:

- the source session
- the triggering performance
- the live target exercise and optional target set
- copied target-set identity
- the resolved training style
- grouped reasoning
- child `PrescriptionChange` rows
- persisted confidence score
- `requiredEvaluationCount`
- `weightStepUsed` for weight-change events

### Required Evaluation Count

`requiredEvaluationCount` is based on the semantic intent of the change, not only the raw `ChangeType`.

Current rules:

- harder progression changes require `2` evaluations
- easier/supportive load changes require `1`
- rep-range configuration changes require `2`
- structure, warmup-calibration, and volume changes require `1`

That matters for assisted-machine suggestions because persisted change direction is not always the same thing as difficulty direction.

## Outcome Resolution

Outcome resolution happens in:

- `OutcomeResolver`
- `OutcomeRuleEngine`

### Which Events Are Eligible

The resolver does not scan every suggestion in the database.

It starts from the current workout's live prescription links and only considers events that are:

- still attached to the current plan structure
- `outcome == .pending`
- older than the current workout
- already decided as `accepted` or `rejected`

If the current workout cannot still provide the required structural evidence, the event stays pending.

Examples:

- set-scoped evaluation requires a completed performed set still linked to the live target set
- recovery events also require the downstream completed working set that the rest change was supposed to help

### Deterministic First, AI Second

`OutcomeRuleEngine` always runs first.

`AIOutcomeInferrer` is only used when:

- rule signal is missing, or
- rule confidence is not high enough

AI is still gated by structure. If the current workout does not have enough evidence for that event shape, the event stays pending instead of asking AI to guess across the gap.

For weight-change outcomes, deterministic evaluation uses the event's frozen `weightStepUsed` when present instead of re-reading live exercise preferences. That keeps older suggestions stable even if the user later changes preferred progression step sizing.

When AI does run, it also receives the current workout's captured context:

- `postEffort` when recorded
- pre-workout feeling when explicitly set
- `tookPreWorkout` only when explicitly recorded as true

Those values adjust confidence, not the core structural evidence requirements.

### Multi-Session Evidence

Outcomes are not finalized after one later workout unless the event's required evaluation count is `1`.

Each eligible later workout can append one `SuggestionEvaluation`.

The resolver uses two dedup guards:

- within one resolve call, each event is processed once
- across multiple calls, it will not append a second evaluation for the same source workout session ID

### Finalization Rule

Once `event.evaluations.count >= event.requiredEvaluationCount`, the resolver no longer finalizes through a fixed priority list.

Instead it:

- stores each `SuggestionEvaluation` with a context-adjusted confidence
- converts outcomes into weighted scores
- sums those scores across sessions
- escalates some mixed 2-session events to require a 3rd evaluation instead of forcing a winner

Current score map:

- `tooAggressive = -2`
- `insufficient = -1`
- `ignored = 0`
- `tooEasy = +1`
- `good = +2`

Each evaluation contributes `score * adjustedConfidence`.

Context currently adjusts confidence rather than changing the outcome label itself:

- high `postEffort` strengthens negative evidence and slightly dampens positive evidence
- low `postEffort` dampens negative evidence and slightly boosts positive evidence
- sick or tired pre-workout feeling weakens negative evidence
- good or great pre-workout feeling slightly strengthens negative evidence
- taking pre-workout slightly strengthens negative evidence and slightly dampens positive evidence

Conflict handling:

- exact `tooAggressive + tooEasy` across the first two evaluations always escalates to `requiredEvaluationCount = 3`
- other mixed positive/negative pairs can also escalate when the weighted net score is too close to neutral

Finalization:

- only neutral evidence -> finalize to `ignored`
- strong negative net -> finalize to `tooAggressive` or `insufficient`
- strong positive net -> finalize to `good` or `tooEasy`
- after 3 evaluations, near-neutral evidence still resolves to `ignored`

## Manual Plan Editing and Suggestions

Manual plan edits can invalidate unresolved suggestion work. That cleanup lives in `WorkoutPlan+Editing.swift`.

When a user edits a plan copy and applies it back to the original plan, VillainArc compares the original and copy and deletes unresolved events when the manual edit already changed the same target.

Important detail:

- cleanup is keyed off `event.outcome == .pending`
- decision state does not matter

So accepted or rejected events can still be deleted if their outcomes are unresolved and the manual edit invalidates the target they needed.

## Freeform Workouts Saved as Plans

A freeform workout normally has no suggestion lifecycle because `workout.workoutPlan == nil`.

That changes when the user taps the summary-screen "Save as Workout Plan" action. That path:

- creates a completed plan from the finished workout
- links the workout to that plan
- backfills frozen target snapshots from the performed workout
- reruns the suggestion pipeline against the now plan-backed session

That behavior is specific to the summary-screen save path. Other save-as-plan entry points may create the plan link without rerunning summary-time suggestion work.

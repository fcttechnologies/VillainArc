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
- training style
- confidence score and reasoning text
- child `PrescriptionChange` rows

One important modeling rule:
- live prescription relationships are the source of truth for current plan behavior
- copied target-set IDs and snapshots are the source of truth for historical matching
- set indices are mostly for ordering and labeling

`SuggestionEvent` does not duplicate the trigger-time target snapshot on itself anymore. It reaches that frozen context through `triggerPerformance.originalTargetSnapshot`.

### `PrescriptionChange`

Each `PrescriptionChange` stores one exact mutation, such as:
- weight increase/decrease
- reps increase/decrease
- rest increase/decrease
- set type change
- rep range changes

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
- accept = set `decision = .accepted`, apply all `PrescriptionChange`s to the live plan, save
- reject = set `decision = .rejected`, leave the plan unchanged
- defer = set `decision = .deferred`, leave the plan unchanged

When summary closes, any still-`pending` current-session events are automatically converted to `deferred`.

### 2. Deferred Pre-Workout Review

If a plan still has `pending` or `deferred` events, `AppRouter.startWorkoutSession(from:)` starts the session in `.pending`.

`DeferredSuggestionsView` blocks entry to active logging until those events are resolved.

Available actions:
- accept one
- reject one
- accept all
- skip all

Important detail:
- accepting a suggestion mutates the plan and also hydrates the already-created pending session copy through `hydratePendingSessionCopy(...)`
- rejecting or skipping only changes decision state

The workout only transitions to `.active` once there are no pending or deferred events left.

### 3. Plan-Level Suggestions Sheet

`WorkoutPlanDetailView` can open `WorkoutPlanSuggestionsSheet`, which has two tabs:

- `To Review`
  - backed by `pendingSuggestionEvents(...)`
  - shows plan suggestions whose decision is still `pending` or `deferred`
- `Awaiting Outcome`
  - backed by `pendingOutcomeSuggestionEvents(...)`
  - shows accepted or rejected suggestions whose `outcome == .pending`

This surface does not generate anything new. It is an inspection and management surface for suggestion state already attached to the plan.

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

### Training Style

Training style is resolved through:
- `MetricsCalculator.detectTrainingStyle(...)` first
- `AITrainingStyleClassifier` only when deterministic detection returns `.unknown`

That style is then reused for:
- choosing the right progression evidence window
- storing how the event was interpreted
- later outcome evaluation

### Draft Conflict Handling

Before drafts become persisted events, the generator does two conflict passes.

#### 1. Blocked by Older Unresolved Events

If an unresolved older event is already attached to the same target scope and the categories are incompatible, the new draft is suppressed for now.

That keeps the app from piling overlapping unresolved suggestions onto the same target.

#### 2. Dedup Within the Current Generation Pass

`SuggestionDeduplicator` resolves conflicts among newly generated drafts.

Important behavior:
- exercise-scoped drafts still keep one winner
- set-scoped drafts can keep more than one event only when categories are compatible
- default allowed coexistence is still `performance` + `recovery` on the same set
- one narrow extra coexistence rule allows `changeSetType -> .working` alongside one same-set `performance` or `recovery` draft

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
- set-scoped outcome evaluation requires a completed performed set still linked to the live target set
- recovery events also require the downstream completed working set that the rest change was supposed to help

### Deterministic First, AI Second

`OutcomeRuleEngine` always runs first.

`AIOutcomeInferrer` is only used when:
- the rule signal is missing, or
- rule confidence is not high enough

AI is still gated by structure. If the current workout does not have enough evidence for that event shape, the event stays pending instead of asking AI to guess across the gap.

When AI does run, it now receives the current workout's captured context too:
- `postEffort` when it was recorded before summary
- pre-workout feeling when it was explicitly set
- `tookPreWorkout` only when it was explicitly recorded as true

Those values are hints, not overriding evidence.

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

Each evaluation's contribution is `score * adjustedConfidence`.

Context currently adjusts confidence, not the outcome label:
- high `postEffort` strengthens negative evidence and slightly dampens positive evidence
- low `postEffort` dampens negative evidence and slightly boosts positive evidence
- sick or tired pre-workout feeling weakens negative evidence
- good or great pre-workout feeling slightly strengthens negative evidence
- taking pre-workout slightly strengthens negative evidence and slightly dampens positive evidence

Conflict handling:
- exact `tooAggressive + tooEasy` across the first two evaluations always escalates to `requiredEvaluationCount = 3`
- other mixed positive/negative 2-session pairs escalate when the weighted net score is too close to neutral

Finalization:
- if an event reaches its required count with only neutral evidence, it resolves to `ignored`
- strong negative net -> finalize to `tooAggressive` or `insufficient`
- strong positive net -> finalize to `good` or `tooEasy`
- after 3 evaluations, if the weighted net is still near neutral -> finalize to `ignored`

## Manual Plan Editing and Suggestions

Manual plan edits can invalidate unresolved suggestion work. That cleanup lives in `WorkoutPlan+Editing.swift`.

When a user edits a plan copy and applies it back to the original plan, VillainArc compares the original and copy and deletes unresolved events when the manual edit already changed the same target.

Important detail:
- cleanup is keyed off `event.outcome == .pending`
- decision state does not matter

So accepted or rejected events can still be deleted if their outcomes are unresolved and the manual edit invalidates the target they needed.

## Freeform Workouts Saved as Plans

A freeform workout normally has no suggestion lifecycle because `workout.workoutPlan == nil`.

That changes if the user taps "Save as Workout Plan" in summary. That path:
- creates a completed plan from the finished workout
- links the workout to that plan
- backfills frozen target snapshots from the performed workout
- reruns the suggestion pipeline against the now plan-backed session

So a freeform workout can enter the suggestion system from summary.

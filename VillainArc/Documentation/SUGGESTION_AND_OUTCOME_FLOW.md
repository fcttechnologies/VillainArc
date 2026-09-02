# Suggestion and Outcome Flow

This document explains how VillainArc creates plan suggestions, where users review them, how they block later workouts when unresolved, and how later workouts resolve outcomes.

## Main Files

- `Views/Workout/WorkoutSummaryView.swift`
- `Views/Suggestions/DeferredSuggestionsView.swift`
- `Views/Suggestions/SuggestionReviewView.swift`
- `Views/Suggestions/WorkoutPlanSuggestionsSheet.swift`
- `Data/Models/Suggestions/SuggestionEvent.swift`
- `Data/Models/Suggestions/PrescriptionChange.swift`
- `Data/Models/Suggestions/SuggestionEvaluation.swift`
- `Data/Services/Suggestions/Generation/SuggestionGenerator.swift`
- `Data/Services/Suggestions/Generation/RuleEngine.swift`
- `Data/Services/Suggestions/Generation/SuggestionDeduplicator.swift`
- `Data/Services/Suggestions/ExerciseSuggestionSettings.swift`
- `Data/Services/Suggestions/Outcomes/OutcomeResolver.swift`
- `Data/Services/Suggestions/Outcomes/OutcomeRuleEngine.swift`
- `Data/Services/Suggestions/Outcomes/SuggestionOutcomeReporting.swift`
- `Data/Models/Plans/WorkoutPlan+Editing.swift`
- `Views/Exercise/ExerciseSuggestionSettingsSheet.swift`

## Core Model

The suggestion system has three persisted layers:

- `SuggestionEvent`
  - one grouped review/evaluation unit
- `PrescriptionChange`
  - one scalar before/after mutation inside an event
- `SuggestionEvaluation`
  - one later-workout evaluation for that event

Important modeling rules:

- live prescription relationships are the source of truth for the current plan
- copied target identities and snapshots are used for historical matching
- `weightStepUsed` freezes weight-step tolerance for later outcome evaluation
- the exercise catalog can globally disable suggestion generation for a specific `catalogID`

## Two State Machines

Suggestions track two lifecycles.

### Decision State

- `pending`
- `accepted`
- `rejected`
- `deferred`

Decision state answers: what did the user choose to do with this suggestion?

### Outcome State

- `pending`
- `good`
- `tooAggressive`
- `tooEasy`
- `insufficient`
- `ignored`

Outcome state answers: how did that decision work out in later workouts?

### What the field report gets

Both state machines stay the app's own. Alongside them, each answer is reported to
`diag.algorithm_outcomes` against `VillainArcEngine.nextSet` through `SuggestionOutcomeReporting`
(`Diag.outcome` in production) — the fleet-wide vocabulary, translated at the edge:

| Where | Reported |
| --- | --- |
| `acceptGroup` | `accepted` |
| `rejectGroup`, `skipSuggestions` | `dismissed` |
| `OutcomeResolver` finalizing `good` | `accepted` |
| … `tooAggressive` / `tooEasy` | `too_aggressive` / `too_easy` |
| … `ignored` | `abandoned` |
| … `insufficient` | nothing — "the evidence could not judge it" is a statement about the workout, not a verdict on the suggestion |

Every row carries the generator (`rules` → `progression`, `ai` → `similarity`; a `user`-authored
suggestion is not the engine's and reports nothing at all), the rank the group sat at in the list
that was shown, and how long the suggestion had been standing (`createdAt` to now). A pending event
is reported when it resolves and not before: nothing ages one out, so `unresolved` has no site —
a pending event either meets a later workout that judges it, or its plan changes and it is deleted
outright, which is an edit rather than a verdict.

## Where Suggestions Start

The main lifecycle starts in `WorkoutSummaryView`.

For plan-backed sessions, summary does:

1. resolve outcomes for older unresolved events
2. generate new suggestions for the current workout

That ordering is deliberate. The app always looks backward before creating new forward-looking coaching events.

## Review Surfaces

VillainArc has three suggestion surfaces.

### Summary Review

`WorkoutSummaryView` renders newly generated suggestions for the current session through `SuggestionReviewView`.

User actions:

- accept
- reject
- defer

Behavior:

- accept
  - applies all `PrescriptionChange`s to the live plan
  - sets `decision = .accepted`
- reject
  - leaves the plan unchanged
  - sets `decision = .rejected`
- defer
  - leaves the plan unchanged
  - sets `decision = .deferred`

Any still-`pending` current-session events are converted to `deferred` when summary finalization completes.

### Deferred Pre-Workout Review

If a plan still has pending or deferred events, `AppRouter.startWorkoutSession(from:)` creates the workout in `.pending`.

`DeferredSuggestionsView` blocks active logging until those events are resolved.

Available actions:

- accept one
- reject one
- accept all
- skip all

Important behavior:

- accepting mutates the live plan and hydrates the already-created pending session copy
- rejecting only changes decision state
- skipping all marks pending/deferred events as rejected before the workout proceeds

### Plan-Level Suggestions Sheet

`WorkoutPlanDetailView` can open `WorkoutPlanSuggestionsSheet`.

It separates suggestion state into:

- `To Review`
  - pending or deferred user decisions
- `Awaiting Outcome`
  - accepted or rejected suggestions whose outcomes are still unresolved

This sheet does not generate anything new. It is a management view over suggestion state already attached to the plan.

## Generation

Generation lives in:

- `SuggestionGenerator`
- `RuleEngine`
- `SuggestionDeduplicator`

Generation combines:

- the current workout’s completed sets
- the live prescription
- recent completed performances for the same exercise
- exercise-catalog settings for that `catalogID`
- frozen target snapshots when available
- resolved training style

Important design details:

- historical matching is UUID-based, not just set-index based
- bodyweight vs externally-loaded behavior is handled explicitly
- double-dumbbell and assisted-load semantics are handled explicitly
- generation is skipped entirely when the source `Exercise` has suggestions disabled

### Training Style

Training style is resolved by:

1. deterministic detection first
2. AI fallback only when deterministic detection returns `.unknown`

The AI fallback is confidence-gated. Low-confidence AI output is ignored.

### Draft Conflict Handling

Before drafts become persisted events, the generator does two conflict passes:

1. suppress drafts blocked by older unresolved events on the same target scope
2. deduplicate conflicting drafts produced in the current generation pass

That is why the app can generate multiple draft ideas internally without exposing obviously conflicting events to the user.

### Persisted Event Creation

Once drafts survive blocking and deduplication, the generator persists:

- the source session
- the triggering performance
- the live target exercise and optional set
- copied target identity
- the resolved training style
- grouped reasoning
- child `PrescriptionChange` rows
- confidence
- `requiredEvaluationCount`
- `weightStepUsed` when relevant

If generation is disabled for an exercise, no draft for that `catalogID` reaches this persistence step.

## Required Evaluation Count

`requiredEvaluationCount` is based on the semantic meaning of the change, not only the raw change category.

The practical effect is:

- some changes can resolve after one later workout
- others require two or more later workouts before the app commits to a final outcome

Important shortcut:

- if the first eligible later workout resolves as `good` or `tooEasy`, the event finalizes immediately
- negative or ambiguous first evaluations such as `tooAggressive`, `insufficient`, or `ignored` still wait for the normal required count
- once multiple evaluations exist, contradiction handling and confidence-weighted aggregation still decide whether to finalize or collect more evidence

## Outcome Resolution

Outcome resolution lives in:

- `OutcomeResolver`
- `OutcomeRuleEngine`

### Which Events Are Eligible

The resolver does not scan the whole database blindly.

It starts from the current workout’s live prescription links and only considers events that are:

- still attached to current plan structure
- `outcome == .pending`
- older than the current workout
- already decided as `accepted` or `rejected`

If the current workout cannot provide the required structural evidence, the event stays pending.

### Deterministic First, AI Second

`OutcomeRuleEngine` runs first.

AI only runs when:

- rule-based signal is missing, or
- rule-based confidence is not strong enough

AI is still structure-gated. If the workout does not provide enough evidence for that event shape, the event stays pending instead of asking AI to guess across the gap.

### Multi-Session Evidence

Outcomes are not always finalized after one later workout.

Each eligible later workout can append one `SuggestionEvaluation`. The resolver prevents duplicate evaluations from the same later workout session.

If the first evaluation is positive, the resolver can finalize immediately as `good` or `tooEasy`.

Otherwise, when the event has enough evaluations:

- the app scores the partial outcomes
- weights them by confidence
- combines them across sessions
- and only then chooses the final outcome

## Post-Session Subjective Feedback

`WorkoutSummaryView` captures a single subjective "How'd it go?" rating that feeds the suggestion system as another input. The rating is session-level in the UI but is recorded per-suggestion-event in storage — there is no session-level outcome field.

The UI:

- inline "How'd it go?" section on `WorkoutSummaryView` with four cards (`great`, `good`, `ok`, `tough`) backed by the `SessionOutcome` enum
- the section only renders when the just-completed session has at least one rateable suggestion event to write to (otherwise there is nothing meaningful for the rating to attach to)
- selecting a card writes immediately to every rateable suggestion event in one save

Where the rating lands:

- the rating maps to `SuggestionEvent.userFeedback` (`UserFeedback`):
  - `great` → `feltGood`
  - `good` → `feltGood`
  - `ok` → `noChange`
  - `tough` → `tooHard`
- the mapping does not produce `tooEasy`; that signal still comes from the deterministic outcome resolver

Rateable suggestion events for a session:

- `decision == .accepted`
- `userFeedback == nil`
- `targetExercisePrescription` is on the session's `workoutPlan`
- `sessionFrom?.id != workoutSession.id` (events generated by this summary are validated by a future workout, not this one)

Relationship to the suggestion outcome state machine:

- `userFeedback` is a subjective user-side signal recorded on the event
- `Outcome` is the deterministic / AI-resolved outcome computed by `OutcomeResolver` over later workouts
- the two coexist on the same `SuggestionEvent` and are independent — `userFeedback` is the user's take, `outcome` is the evidence-based resolution

## Downstream Surface: Correlation Insights

`CorrelationInsightsView` (Health tab → Trends → Performance Correlations) is the read-only analysis surface that consumes accumulated `userFeedback` ratings.

For each completed `WorkoutSession` that has a `workoutPlan`:

- gather every `SuggestionEvent` reachable through `plan.sortedExercises[*].suggestionEvents` where `userFeedback != nil`, `decision == .accepted`, and `sessionFrom?.startedAt < session.startedAt`
- map each feedback to a 0...1 quality score: `feltGood`/`tooEasy` → 1.0, `noChange` → 0.5, `tooHard` → 0.0
- the session's `qualityScore` is the mean of those values

The view pairs the per-session `qualityScore` with:

- `HealthSleepNight.timeAsleep / 3600` for the session's `startedAt` wake day, when present
- the session's average completed-set RPE (sets where `complete == true && rpe > 0`)

Two Swift Charts scatter plots are rendered (sleep vs quality, RPE vs quality) with a simple closed-form linear regression line. A minimum of 8 rated sessions is required before the view leaves its empty state. An auto-generated headline insight is surfaced when sleep ≥7h and average RPE ≤8 both align with high quality, or when Pearson correlation magnitude crosses 0.3.

This is an analysis surface only — it does not write back to `SuggestionEvent` and does not influence the outcome state machine.

## Relationship to Manual Plan Editing

Manual editing does not review suggestions. It establishes a new plan source of truth.

If an unresolved suggestion no longer matches that source of truth, `WorkoutPlan+Editing.swift` deletes the stale event during edit-copy merge.

That keeps coaching state aligned with the user’s explicit plan edits instead of trying to preserve outdated events.

## AI Exercise Replacement Suggestions

`ReplaceExerciseView` augments the deterministic muscle-overlap + equipment-match ranker with a top-of-list "AI Suggestions" section when on-device Apple Intelligence is available.

The flow:

- On view appear, `AIExerciseReplacementSuggester` is queried with the current exercise (name, muscles, equipment), the user's fitness level, and the active training goal.
- The service sends a short `Prompt` to `SystemLanguageModel.default` and asks for a `@Generable AIReplacementSuggestionList` of 3–5 `AIReplacementSuggestion` rows (`exerciseName`, `equipment`, `reasoning`).
- Each suggestion is fuzzy-matched against the catalog via the same 5-strategy resolver used by `AIWorkoutPlanGenerator` (exact name+equipment, exact name, alias, equipment-prefixed name, token-overlap score).
- Resolved suggestions render in a horizontal scroll above the existing list. Tapping one selects that exercise and triggers the same Keep Sets / Clear Sets confirmation dialog as a tap in the main list.

Fallback behavior:

- `SystemLanguageModel.default.availability != .available` → the AI section never renders; the existing rank-based list is the only surface.
- AI returns zero resolvable suggestions → the AI section renders a "no matches" caption but doesn't block the main list.
- AI errors → silently swallowed (logged in service code); the user still sees the deterministic list.

The AI suggestions are surfaced as an additional ranked source, not a replacement for the deterministic ranker. The deterministic logic still feeds the rest of the picker through `FilteredExerciseListView.preferredMuscles` + `preferredEquipmentType`.

## Exercise-Level Suggestion Settings

VillainArc also supports a global exercise-catalog setting through `ExerciseSuggestionSettingsSheet`.

When the user saves suggestion generation as off for an exercise:

- new suggestion generation is skipped for that `catalogID`
- progression-step tuning is hidden in that settings sheet
- unresolved suggestion events for matching plan exercises and sets are deleted

The cleanup target is intentionally unresolved-only:

- `outcome == .pending` events are deleted
- already finalized historical outcomes remain intact

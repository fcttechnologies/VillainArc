# Progression Improvements

This document is no longer a general research summary. It is now the practical improvement brief for VillainArc's progression system based on the research review and the current implementation.

The goal is not to redesign the system. The current direction is good. The goal is to identify the highest-value refinements that would make suggestion generation and outcome evaluation more accurate, more explainable, and more useful in real training.

## Current Direction

VillainArc is already aligned with the strongest progression principles:

- deterministic-first suggestion generation
- deterministic-first outcome evaluation with AI fallback
- multi-session outcome evaluation instead of single-session finalization
- conservative regression behavior
- double-progression behavior through load increases, rep increases, and rep resets
- equipment-aware increment sizing
- strong plan anchoring through prescription and UUID-based target tracking

That means the best next work is refinement, not replacement.

## Highest-Value Next Improvements

1. Expand training-style detection beyond the current style buckets.
2. Add explicit suggestion confidence and recommendation tiering.
3. Tune progression thresholds by exercise context, not just increment size.
4. Use actual RPE and target RPE as confidence modifiers.
5. Improve mixed-evidence outcome handling so ambiguous cases stay unresolved longer.
6. Visually separate strong suggestions from exploratory suggestions in the review flow.

---

## 1. Expand Training-Style Detection

### Why this should be next

This is the most foundational improvement because training-style detection controls which sets count as progression evidence. If the evidence window is wrong, the progression rules and the outcome rules both start from the wrong signal.

### What the app does now

Current style detection supports:

- straight sets
- ascending
- ascending pyramid
- descending pyramid
- top set plus backoffs
- unknown

This is implemented primarily in:

- `Data/Services/Suggestions/Shared/MetricsCalculator.swift`
- `Data/Services/AI/Suggestions/AITrainingStyleClassifier.swift`

The current system already does a good job avoiding obvious misclassification of moderate ramps and backoffs, but it still treats several real-world patterns as either generic working sets or `unknown`.

### Improvement

Add explicit handling for:

- feeder ramps
- reverse-pyramid or heavy-first clusters distinct from simple descending pyramids
- drop-set clusters
- rest-pause or cluster-style fatigue work
- top set plus one meaningful backoff vs broad backoff clusters

### Why it would help

Better style detection improves:

- progression-set selection
- warmup and feeder exclusion
- rest and recovery interpretation
- outcome evaluation for heavy-set-driven structures

### Example

If a session looks like:

- `60 x 10`
- `80 x 8`
- `100 x 6`
- `100 x 4` with very short recovery

the engine should mostly treat `100 x 6` as the primary signal and avoid letting the fatigue cluster distort normal progression.

### Recommended implementation

- Expand `TrainingStyle` with more granular cases.
- Update deterministic classification first.
- Update progression-set selection so drop-set or rest-pause clusters are excluded from normal load progression.
- Update the AI classifier instructions so AI only resolves patterns that deterministic logic still marks ambiguous.

### Likely files/functions

- `Data/Models/Enums/Suggestions/TrainingStyle.swift`
- `Data/Services/Suggestions/Shared/MetricsCalculator.swift`
- `MetricsCalculator.detectTrainingStyle(...)`
- `MetricsCalculator.selectProgressionSets(...)`
- `Data/Services/AI/Suggestions/AITrainingStyleClassifier.swift`

### Risk / complexity

Medium.

### Timing

Do now.

---

## 2. Make Suggestion Confidence Explicit

### Why this should be next

The system already has the idea of rule strength, but it is mostly internal. Users currently see suggestions as if they are equally strong, even though some are much more evidence-backed than others.

### What the app does now

Suggestion drafts carry:

- `ruleID`
- `evidenceStrength`

But persisted `SuggestionEvent` records do not preserve a user-facing confidence or tier. The review UI shows reasoning text, but not strength.

Outcome evaluation already stores confidence in `evaluationHistory`, but that confidence is not surfaced in the suggestion flow.

### Improvement

Persist a suggestion-level confidence and convert it into a simple user-facing tier, for example:

- strong
- moderate
- exploratory

### Why it would help

This makes the system more honest and more usable:

- direct progression or safety corrections can be treated as strong
- rep-range cleanup and heuristic rest suggestions can be treated as exploratory
- users can make faster, better accept/reject decisions

### Example

These should not look equivalent in the review UI:

- repeated below-range miss at prescribed load -> reduce weight
- repeated short-rest performance drop -> increase rest
- possible target-to-range rep-range shift

### Recommended implementation

- Add persisted suggestion confidence to `SuggestionEvent`.
- Derive it from `ruleID`, `evidenceStrength`, session count, and style certainty.
- Render a badge or label in review rows.
- Use the same tiering in deferred suggestions.

### Likely files/functions

- `Data/Models/Suggestions/SuggestionEvent.swift`
- `Data/Models/Suggestions/SuggestionEventDraft.swift`
- `Data/Services/Suggestions/Generation/SuggestionGenerator.swift`
- `Views/Suggestions/SuggestionReviewView.swift`
- `Views/Suggestions/DeferredSuggestionsView.swift`

### Risk / complexity

Low to medium.

### Timing

Do now.

---

## 3. Tune Progression Thresholds by Exercise Context

### Why this should be next

VillainArc already adapts increment size by equipment and muscle context, but evidence thresholds are still fairly uniform. That leaves value on the table.

### What the app does now

Current context-sensitive progression mostly comes from:

- `MetricsCalculator.weightIncrement(...)`
- a top-set style multiplier
- a few catalog-specific barbell pull overrides

But the decision logic for immediate progression, confirmed progression, overshoot, and required evaluation count is still mostly driven by rep-range mode and change type.

### Improvement

Introduce exercise-context progression profiles that tune:

- how many sessions are needed
- when immediate progression is allowed
- when overshoot should trigger a larger jump
- when rep progression should be preferred over load progression
- when regression should require stronger confirmation

### Why it would help

Different lift types behave differently:

- heavy barbell compounds need more confirmation
- machines and isolations can progress faster
- dumbbells often need rep progression because jumps are large
- bodyweight and assisted work need special handling

### Example

A cable curl and a barbell squat should not require the same confirmation behavior just because both are in range mode.

### Recommended implementation

- Add a `ProgressionProfile` helper derived from `equipmentType`, `catalogID`, and exercise context.
- Use it inside progression, overshoot, regression, and `requiredEvaluationCount`.
- Keep the first version simple and deterministic.

### Likely files/functions

- `Data/Services/Suggestions/Shared/MetricsCalculator.swift`
- `Data/Services/Suggestions/Generation/RuleEngine.swift`
- `immediateProgressionRange(...)`
- `confirmedProgressionRange(...)`
- `confirmedProgressionTarget(...)`
- `largeOvershootProgression(...)`
- `belowRangeWeightDecrease(...)`
- `SuggestionGenerator.requiredEvaluationCount(...)`

### Risk / complexity

Medium.

### Timing

Do now.

---

## 4. Use RPE and Effort Signals as Confidence Modifiers

### Why this should be next

VillainArc already captures actual set `rpe` and target `targetRPE`, but the current progression and outcome rules mostly ignore it. This is one of the cleanest upgrades because the signal already exists.

### What the app does now

The app stores:

- actual `SetPerformance.rpe`
- planned `SetPrescription.targetRPE`
- frozen `targetRPE` and actual `rpe` in snapshots

But suggestion and outcome rules currently rely mostly on:

- reps
- load
- rest
- set type

### Improvement

Use RPE as a confidence modifier first, not as a primary rule replacement.

### Why it would help

RPE can distinguish:

- true reserve from grinder reps
- easy overshoots from max-effort overshoots
- legitimate underperformance from expected high-effort work

### Example

`100 x 10 @ RPE 10` should not support the same confident progression as `100 x 10 @ RPE 7-8`.

Likewise:

`100 x 8 @ RPE 6` against a target `RPE 8` is useful too-easy evidence even if reps are not dramatically above target.

### Recommended implementation

First use RPE to:

- lower confidence for progression when reps are hit at very high effort
- raise confidence for progression when reps are hit comfortably below target effort
- reduce confidence on ambiguous misses when effort suggests expected fatigue
- help decide whether mixed evidence should stay unresolved

Do not make RPE a hard gate in the first pass.

### Likely files/functions

- `Data/Models/Sessions/SetPerformance.swift`
- `Data/Models/Plans/SetPrescription.swift`
- `Data/Models/Suggestions/SuggestionSnapshots.swift`
- `Data/Services/Suggestions/Generation/RuleEngine.swift`
- `Data/Services/Suggestions/Outcomes/OutcomeRuleEngine.swift`

### Risk / complexity

Medium.

### Timing

Do now, but only as confidence tuning in v1.

---

## 5. Improve Mixed-Evidence Outcome Handling

### Why this matters

The current system is appropriately safety-weighted, but once the required number of sessions is reached it still has to pick a winner. That can force an overconfident final label in genuinely noisy cases.

### What the app does now

At finalization, outcomes are chosen using safety-weighted priority:

- `tooAggressive`
- `insufficient`
- `good`
- `tooEasy`
- `ignored`

That is the right default for safety. But it does not explicitly model conflicting, low-confidence, mixed evidence.

### Improvement

Add a more explicit keep-watching path for threshold-reaching mixed evidence.

### Why it would help

Some cases should remain unresolved longer:

- partial follow-through one session
- near-old-target execution the next
- one noisy travel session
- one good and one ambiguous evaluation with similar confidence

### Example

If a suggestion gets:

- one low-confidence `good`
- one medium-confidence `ignored`

it may be better to collect one more session than to force a final result.

### Recommended implementation

Start with the safest version:

- keep `tooAggressive` as always decisive
- allow one additional evaluation session when evidence is mixed and confidence is narrow
- only later consider a new terminal outcome like `inconclusive`

### Likely files/functions

- `Data/Services/Suggestions/Outcomes/OutcomeResolver.swift`
- `aggregateRuleSignal(...)`
- `applyOutcomeIfPossible(...)`
- `Data/Models/Suggestions/SuggestionEvent.swift`

### Risk / complexity

Medium to high.

### Timing

Do later.

---

## 6. Separate Strong Suggestions from Exploratory Suggestions in the UI

### Why this matters

The review flow currently treats every suggestion the same. Once suggestion confidence exists, the UI should reflect that.

### What the app does now

The review UI shows:

- group label
- reasoning text
- scalar change descriptions
- accept / reject / defer actions

But there is no distinction between:

- strong safety or progression suggestions
- exploratory range or heuristic recovery suggestions

### Improvement

Group or label suggestions by recommendation tier.

### Why it would help

This reduces cognitive load and makes the review flow feel smarter.

### Example

The summary screen could show:

- Strong Suggestions
- Exploratory Suggestions

without changing behavior yet.

### Recommended implementation

- Use persisted suggestion confidence or tier.
- Sort strong suggestions first.
- Add lightweight visual labeling before changing any interaction design.

### Likely files/functions

- `Views/Suggestions/SuggestionReviewView.swift`
- `Views/Suggestions/DeferredSuggestionsView.swift`
- `Data/Models/Suggestions/SuggestionGrouping.swift`
- `Views/Workout/WorkoutSummaryView.swift`

### Risk / complexity

Medium.

### Timing

Do now for display-only separation.

---

## Suggested Implementation Order

If these improvements are tackled incrementally, the best order is:

1. expand training-style detection
2. add suggestion confidence and tiering
3. add exercise-context progression profiles
4. use RPE as confidence tuning
5. separate strong vs exploratory suggestions in UI
6. improve mixed-evidence outcome handling

This order improves the evidence quality first, then the explainability, then the more complex ambiguity handling.

## Do Not Change Yet

These ideas sound attractive, but are too risky or too premature right now:

- replacing deterministic progression with AI-first progression
- turning workout-level post-session effort into a set-level progression signal
- introducing a large new outcome taxonomy all at once
- auto-applying exploratory suggestions
- building highly individualized long-history progression models before profile-based tuning is finished

## Bottom Line

VillainArc does not need a new progression system.

It needs the next layer of refinement:

- broader style detection
- explicit confidence
- better exercise-context thresholds
- smarter use of RPE
- more honest mixed-evidence handling
- clearer UI separation between strong and exploratory recommendations

That is the path that would make the current system feel elite without sacrificing the conservative, deterministic-first foundation that already makes it strong.

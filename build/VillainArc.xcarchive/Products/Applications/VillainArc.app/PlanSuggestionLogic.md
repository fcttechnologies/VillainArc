# Plan Suggestion System

## Overview
The suggestion system generates prescription changes after a workout and lets users accept, reject, or defer them. Suggestions come from the **rule engine** (deterministic, data-driven). On-device AI (FoundationModels) assists by classifying rep range and training style when heuristics are unknown or recent history is weak.

Suggestions are generated per workout session, stored as `PrescriptionChange`, and surfaced in the summary and deferred review flows.

## Generation Pipeline
1. `WorkoutSummaryView` asks `SuggestionGenerator` for existing suggestions for the session. If none exist and the session has a plan, it generates new ones.
2. **Gather Phase (Main Actor)**:
   - Identify candidates for AI inference by checking if training style is `unknown`.
   - Prepare lightweight `AIRequest` snapshots (Sendable) for these candidates.
   - Map requests by `exercisePerf.id` (UUID) to handle duplicate exercises.
3. **Scatter Phase (Background - Parallel)**:
   - Launch a `TaskGroup` to run all AI inference requests simultaneously.
   - Each request uses `AITrainingStyleClassifier` which creates a dedicated, thread-safe session.
4. **Evaluate Phase (Main Actor)**:
   - Iterate through exercises again.
   - Re-fetch **full** history (no limit) for accurate Rule Engine analysis via `ExercisePerformance.matching`.
   - Apply pre-calculated AI results if available.
   - Run `RuleEngine.evaluate`.
5. Merge all suggestions and pass them through `SuggestionDeduplicator`.
6. Persist `PrescriptionChange` items with `decision = .pending`.

## AI Configuration Inference
AI does NOT generate suggestions directly. It classifies configuration values that enable rules to fire.

### What AI Classifies
**Training Style** — Classifies set/weight patterns when heuristic detection returns `unknown`.
- Used as an override in `MetricsCalculator.selectProgressionSets` when regular sets aren't labeled.
- Styles: straightSets, ascendingPyramid, descendingPyramid, ascending, topSetBackoffs, unknown.

### Availability
- Uses `SystemLanguageModel.default` (on-device). If unavailable, returns nil and existing heuristics are the full fallback.
- One tool available: `getRecentExercisePerformances` (last N sessions, max 5) for additional context.
- AI inferences are ephemeral — used for the current suggestion generation only, not persisted.

## Context and Helpers
- Full history: `ExercisePerformance.matching(catalogID:)` returns all completed performances (sorted most recent first).
- Progression sets: `MetricsCalculator.selectProgressionSets` picks all working sets used by progression rules. When set types are unlabeled, uses training style detection to identify the working cluster. Accepts a resolved training style override.
- Weight increments: `MetricsCalculator.weightIncrement` and `roundToNearestPlate`.

## Training Style Detection
`MetricsCalculator.detectTrainingStyle` infers training style from weight patterns when set types aren't labeled. AI is only used if this returns `unknown`.

| Style | Detection Pattern | Progression Sets Picked |
|-------|------------------|------------------------|
| `straightSets` | All weights within ~10% of average | All sets |
| `topSetBackoffs` | 1-3 sets cluster at top weight (within 90% of max), rest significantly lighter (<80% of max) | Heavy cluster (within 90% of max) |
| `ascending` | Weights monotonically increase, heaviest is last | All sets within 90% of max |
| `descendingPyramid` | Weights mostly descend, heaviest is first | All sets within 90% of max |
| `ascendingPyramid` | Max weight is in the middle (not first or last) | All sets within 95% of max |
| `unknown` | No clear pattern | All sets (sorted by weight) |

## Rule Engine (Order + Details)
Rule order matters and is executed exactly as listed below. Progression and rep-based safety rules require a rep range mode to be set on the prescription (`.range` or `.target`). Set-type and rest hygiene rules still run even when rep range is `.notSet`.

### Progression Rules
1. Large overshoot progression
   - Range mode: last 2 sessions, all progression sets >= upper + 4 reps.
   - Target mode: last 2 sessions, all progression sets >= target + 5 reps.
   - Increase weight by 1.5x the normal increment.
   - If range mode, reset reps to the lower bound.
2. Double progression (range mode)
   - Last 2 sessions: all progression sets hit the top of the range.
   - Increase weight, reset reps to lower bound.
3. Double progression (target mode)
   - Last 2 sessions: all progression sets exceed target by at least 1.
   - Increase weight.
4. Steady reps increase within range (new)
   - Range mode only.
   - Last 2 sessions: progression set repeats the same reps at the same weight.
   - Reps are within range and below the upper bound.
   - Increase set target reps by 1 (capped at upper).
   - Skips if weight progression already qualifies.

### Safety / Cleanup
1. Below range weight decrease
   - Range mode only.
   - Last 3 sessions: at least 2 sessions below lower bound while attempting prescribed load (within 2.5 lbs).
   - Decrease weight by the normal increment.
2. Reduced weight to hit reps
   - Last 2 sessions: user reduced weight and still hit low reps.
   - Decrease target weight to the average used.
3. Match actual weight
   - Last 3 sessions: consistent deviation > 5 lbs above or below target.
   - Skip if progression weight increase is already warranted.
   - Update target weight to the average used.
4. Stagnation increase rest
   - Last 3 sessions: estimated 1RM within +/-2% (plateau).
   - User is struggling with targets in at least 2 of 3 sessions.
   - Increase rest (policy-level if all-same, otherwise per set).

### Set Type / Rest Hygiene
1. Short rest performance drop
   - Last 2 sessions: rest shorter than prescribed by at least 15s, and reps drop by 2+ or fall below rep floor.
   - Increase rest (policy-level or per set depending on rest mode).
2. Drop set without base
   - First drop set occurs before any regular set.
   - Convert that drop set to regular.
3. Warmup acting like working set
   - Warmup set within 10% of top regular weight in last 2 sessions.
   - Convert to regular.
4. Regular acting like warmup
   - Early regular set (<70% of top regular weight) in last 2 sessions.
   - Convert to warmup.
5. Set type mismatch
   - Last 2 sessions: logged set type differs from prescription.
   - Update set type to match behavior.

## Deduplication and Conflict Resolution
`SuggestionDeduplicator` resolves conflicts between generated suggestions.

### Conflict Resolution
1. Strategy conflicts
   - Weight increase vs rest increase: keep weight increase.
   - Weight increase vs weight decrease: keep decrease (safety wins).
2. Property conflicts (same target + property)
   - Keep highest-priority change.
   - Priority order: decrease weight (1), increase weight/reps (2), set type/rep range (3), rest changes (5).
   - Tie-breakers: rules over AI, larger magnitude, earlier created.

## Storage and UI
- Suggestions are stored as `PrescriptionChange` with source, reasoning, decision, and target references.
- Summary view shows suggestions immediately after a workout; leaving the summary defers remaining `pending` items.
- Deferred suggestions appear before the next workout from the same plan.
- Suggestion outcomes are evaluated at summary time (before suggestions are generated) via `OutcomeResolver`.

## Examples
These are illustrative scenarios that map directly to rule logic. Numbers are simplified.

### Progression
- **Double progression (range mode)**: Bench press 8-12 @ 135. Last two sessions all working sets hit 12. Suggest +5 lbs (140) and reset target reps to 8.
- **Large overshoot**: Same setup, but last two sessions all working sets hit 16+ reps. Suggest larger jump (1.5x increment) and reset reps to lower bound.
- **Double progression (target mode)**: Pull-ups target 8 reps @ +25. Last two sessions all working sets hit 9–10. Suggest +5 lbs (30).
- **Steady reps increase within range**: DB rows 8-12 @ 60, target reps 10. Last two sessions repeat 10 reps at 60. Suggest target reps 11.

### Safety / Cleanup
- **Below range decrease**: Squat 5-8 @ 225. Two of last three sessions were below 5 reps while attempting 225. Suggest -10 lbs (215).
- **Reduced weight to hit reps**: OHP target 95, but last two sessions reduce to ~85 and still barely hit reps. Suggest target weight ~85.
- **Match actual weight**: Three sessions consistently use ~10 lbs above target. Update target to match working weight.

### Set Type / Rest Hygiene
- **Short rest performance drop**: Target rest 120s but user rests ~60s; reps drop by 2+ in the next set across last two sessions. Suggest +15s rest.
- **Warmup acting like working set**: Warmup set is within 10% of top working weight in last two sessions. Suggest changing that set to working.
- **Regular acting like warmup**: Early regular set is <70% of top working weight in last two sessions. Suggest changing that set to warmup.

## File Map
- Generation: `VillainArc/Data/Classes/Suggestions/SuggestionGenerator.swift`
- Rule engine: `VillainArc/Data/Classes/Suggestions/RuleEngine.swift`
- Metrics helpers: `VillainArc/Data/Classes/Suggestions/MetricsCalculator.swift`
- Dedup/conflict handling: `VillainArc/Data/Classes/Suggestions/SuggestionDeduplicator.swift`
- AI inferrer: `VillainArc/Data/Classes/Suggestions/AITrainingStyleClassifier.swift`
- AI models: `VillainArc/Data/Models/AIModels/AISuggestionModels.swift`
- AI tools: `VillainArc/Data/Classes/Suggestions/AITrainingStyleTools.swift`
- Model: `VillainArc/Data/Models/Plans/PrescriptionChange.swift`
- Grouping: `VillainArc/Data/Models/Plans/SuggestionGrouping.swift`
- Summary UI: `VillainArc/Views/Workout/WorkoutSummaryView.swift`
- Review UI: `VillainArc/Views/Suggestions/SuggestionReviewView.swift`
- Deferred UI: `VillainArc/Views/Suggestions/DeferredSuggestionsView.swift`

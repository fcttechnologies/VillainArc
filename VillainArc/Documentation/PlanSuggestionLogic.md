# Plan Suggestion System

## Overview
The suggestion system generates prescription changes after a workout and lets users accept, reject, or defer them. Suggestions come from two sources:
- Rule engine (deterministic, data-driven).
- On-device AI (FoundationModels) when available.

Suggestions are generated per workout session, stored as `PrescriptionChange`, and surfaced in the summary and deferred review flows.

## Generation Pipeline
1. `WorkoutSummaryView` asks `SuggestionGenerator` for existing suggestions for the session. If none exist and the session has a plan, it generates new ones.
2. For each exercise in the session:
   - Build `ExerciseSuggestionContext` with current performance, prescription, plan, last 3 completed performances, and cached history.
   - Run `RuleEngine.evaluate`.
   - Run `AISuggestionGenerator.generateSuggestions` (only if the on-device model is available).
3. Merge all suggestions and pass them through `SuggestionDeduplicator`.
4. Persist `PrescriptionChange` items with `decision = .pending`.

## Context and Helpers
- Recent history: `ExercisePerformance.matching(catalogID:)` with `fetchLimit = 3` (sorted most recent first).
- Cached history: `ExerciseHistoryUpdater.fetchOrCreateHistory` provides typical ranges and trend data.
- Progression sets: `MetricsCalculator.selectProgressionSets` picks the 1-2 working sets used by progression rules.
- Weight increments: `MetricsCalculator.weightIncrement` and `roundToNearestPlate`.

## Rule Engine (Order + Details)
Rule order matters and is executed exactly as listed below.

### Rep Range Inference
- If rep range mode is `.notSet`, infer a mode and values from recent history or cached typical range.
- Creates exercise-level changes to set mode and bounds/target.

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
   - Last 2 sessions: rest shorter than prescribed and reps drop or fall below target.
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

## Deduplication and Similarity Rules
`SuggestionDeduplicator` filters and resolves conflicts.

### Similar Suggestion Cooldown
- Similar means same `changeType` and same target (set or exercise).
- If a similar suggestion was created within the last 7 days and is pending, deferred, or accepted, skip it.
- If a similar suggestion was rejected within the last 7 days, skip it.

### Conflict Resolution
1. Strategy conflicts
   - Weight increase vs rest increase: keep weight increase.
   - Weight increase vs weight decrease: keep decrease (safety wins).
2. Property conflicts (same target + property)
   - Keep highest-priority change.
   - Priority order: decrease weight (1), increase weight/reps (2), set type/rep range (3), add/remove set (4), rest changes (5), exercise structure (6).
   - Tie-breakers: rules over AI, larger magnitude, earlier created.

## AI Suggestion Integration (FoundationModels)
AI suggestions are live and run per exercise after rules.

- Uses `SystemLanguageModel.default` (on-device). If unavailable, AI returns no suggestions.
- Tools available to the model:
  - `getExerciseHistoryContext` (cached summary across all history).
  - `getRecentExercisePerformances` (last N sessions, max 5).
- The model outputs 0-5 quantifiable suggestions with a change type, target set index, new value, and reasoning.
- Values are normalized (plate rounding for weight, integer reps/rest). Exercise-level changes use `targetSetIndex = -1`.
- AI suggestions are merged with rule suggestions and deduped/conflict-resolved together; rules win ties.

## Storage and UI
- Suggestions are stored as `PrescriptionChange` with source, reasoning, decision, and target references.
- Summary view shows suggestions immediately after a workout; leaving the summary defers remaining `pending` items.
- Deferred suggestions appear before the next workout from the same plan.
- `outcome` fields exist but are not yet evaluated in the current codebase.

## File Map
- Generation: `VillainArc/Data/Classes/Suggestions/SuggestionGenerator.swift`
- Rule engine: `VillainArc/Data/Classes/Suggestions/RuleEngine.swift`
- Metrics helpers: `VillainArc/Data/Classes/Suggestions/MetricsCalculator.swift`
- Dedup/conflict handling: `VillainArc/Data/Classes/Suggestions/SuggestionDeduplicator.swift`
- AI generator: `VillainArc/Data/Classes/Suggestions/AISuggestionGenerator.swift`
- AI tools/models: `VillainArc/Data/Classes/Suggestions/AISuggestionTools.swift`, `VillainArc/Data/Classes/Suggestions/AISuggestionModels.swift`
- Model: `VillainArc/Data/Models/Plans/PrescriptionChange.swift`
- Grouping: `VillainArc/Data/Models/Plans/SuggestionGrouping.swift`
- Summary UI: `VillainArc/Views/Workout/WorkoutSummaryView.swift`
- Review UI: `VillainArc/Views/Suggestions/SuggestionReviewView.swift`
- Deferred UI: `VillainArc/Views/Suggestions/DeferredSuggestionsView.swift`

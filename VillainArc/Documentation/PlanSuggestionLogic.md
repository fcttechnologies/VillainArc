# Plan Suggestion System

## Overview
The suggestion system generates prescription changes after a workout and lets users accept, reject, or defer them. Suggestions come from the **rule engine** (deterministic, data-driven). On-device AI (FoundationModels) assists by classifying rep range and training style when heuristics are unknown or recent history is weak.

Suggestions are generated per workout session, stored as `PrescriptionChange`, and surfaced in the summary and deferred review flows.

## Generation Pipeline
1. `WorkoutSummaryView` asks `SuggestionGenerator` for existing suggestions for the session. If none exist and the session has a plan, it generates new ones.
2. **Gather Phase (Main Actor)**:
   - Identify candidates for AI inference by checking:
     - `history.count < 10` (Quick check with `limit: 10`).
     - OR training style is `unknown`.
   - Prepare lightweight `AIRequest` snapshots (Sendable) for these candidates.
   - Map requests by `exercisePerf.id` (UUID) to handle duplicate exercises.
3. **Scatter Phase (Background - Parallel)**:
   - Launch a `TaskGroup` to run all AI inference requests simultaneously.
   - Each request uses `AIConfigurationInferrer` which creates a dedicated, thread-safe session.
4. **Evaluate Phase (Main Actor)**:
   - Iterate through exercises again.
   - Re-fetch **full** history (no limit) for accurate Rule Engine analysis.
   - Apply pre-calculated AI results if available.
   - Run `RuleEngine.evaluate`.
5. Merge all suggestions and pass them through `SuggestionDeduplicator`.
6. Persist `PrescriptionChange` items with `decision = .pending`.

## AI Configuration Inference
AI does NOT generate suggestions directly. It classifies configuration values that enable rules to fire.

### What AI Classifies
1. **Rep Range Mode + Values** — When `repRange.activeMode == .notSet` and total history is weak (`< 10` total sessions).
   - Classifies as Range (lower + upper) or Target (target reps).
   - AI is never allowed to suggest `untilFailure` mode.
   - AI is preferred **strictly** when `history.count < 10`; otherwise full history candidates are used.

2. **Training Style** — Classifies set/weight patterns when heuristic detection returns `unknown`.
   - Used as an override in `MetricsCalculator.selectProgressionSets` when regular sets aren't labeled.
   - Styles: straightSets, ascendingPyramid, descendingPyramid, ascending, topSetBackoffs, unknown.

### Availability
- Uses `SystemLanguageModel.default` (on-device). If unavailable, returns nil and existing heuristics are the full fallback.
- One tool available: `getRecentExercisePerformances` (last N sessions, max 5) for additional context.
- AI inferences are ephemeral — used for the current suggestion generation only, not persisted.

## Context and Helpers
- Full history: `ExercisePerformance.matching(catalogID:)` returns all completed performances (sorted most recent first).
- Recent window: `recentHistory = history.prefix(10)` is used for rep range inference and AI gating.
- Cached history summary: `ExerciseHistoryUpdater.fetchHistory` is passed to context for rules/future use, but rep range inference currently uses recent history only.
- Progression sets: `MetricsCalculator.selectProgressionSets` picks the 1-2 working sets used by progression rules. Accepts a resolved training style override.
- Weight increments: `MetricsCalculator.weightIncrement` and `roundToNearestPlate`.

## Training Style Detection
`MetricsCalculator.detectTrainingStyle` infers training style from weight patterns when set types aren't labeled. AI is only used if this returns `unknown`.

| Style | Detection Pattern | Progression Sets Picked |
|-------|------------------|------------------------|
| `straightSets` | All weights within ~10% of average | First 2 complete sets |
| `topSetBackoffs` | 1-3 sets cluster at top weight (within 90% of max), rest significantly lighter (<80% of max) | Heavy cluster (up to 3 sets) |
| `ascending` | Weights monotonically increase, heaviest is last | Last 1-2 sets |
| `descendingPyramid` | Weights mostly descend, heaviest is first | First 1-2 sets |
| `ascendingPyramid` | Max weight is in the middle (not first or last) | Top 1-2 sets within 95% of max |
| `unknown` | No clear pattern | 2 heaviest by weight |

## Rule Engine (Order + Details)
Rule order matters and is executed exactly as listed below.

### Rep Range Inference
- If rep range mode is `.notSet`, infer a mode and values from recent history.
- Candidate sources (in order):
  1. **AI classification** when `history.count < 10` and AI returns a rep range.
  2. **Policy-based history**: most common `repRange` policy used in **full** `history` (ties broken by recency).
  3. **Rep-based history**: p25-p75 of completed regular-set reps in `history` (range mode).
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
- If the similar suggestion is a user-originated accepted change, the cooldown is 3 days.
- If a similar suggestion was rejected within the last 7 days, skip it.

### Conflict Resolution
1. Strategy conflicts
   - Weight increase vs rest increase: keep weight increase.
   - Weight increase vs weight decrease: keep decrease (safety wins).
2. Property conflicts (same target + property)
   - Keep highest-priority change.
   - Priority order: decrease weight (1), increase weight/reps (2), set type/rep range (3), add/remove set (4), rest changes (5), exercise structure (6).
   - Tie-breakers: rules over AI, larger magnitude, earlier created.

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
- AI inferrer: `VillainArc/Data/Classes/Suggestions/AIConfigurationInferrer.swift`
- AI models: `VillainArc/Data/Classes/Suggestions/AISuggestionModels.swift`
- AI tools: `VillainArc/Data/Classes/Suggestions/AISuggestionTools.swift`
- Model: `VillainArc/Data/Models/Plans/PrescriptionChange.swift`
- Grouping: `VillainArc/Data/Models/Plans/SuggestionGrouping.swift`
- Summary UI: `VillainArc/Views/Workout/WorkoutSummaryView.swift`
- Review UI: `VillainArc/Views/Suggestions/SuggestionReviewView.swift`
- Deferred UI: `VillainArc/Views/Suggestions/DeferredSuggestionsView.swift`

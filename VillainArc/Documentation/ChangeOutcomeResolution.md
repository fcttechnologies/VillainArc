# Change Outcome Resolution

**Status**: Planned

## Goals
- Resolve outcomes for prior `PrescriptionChange` items when a workout summary loads.
- Run deterministic rules first, then always run AI for a second opinion.
- Evaluate changes regardless of decision (accepted, rejected, deferred, pending), as long as the outcome is still `.pending`.
- If an exercise is not performed, keep outcomes pending.
- No sets are ever saved if they are not completed, but still treat `complete == true` as the guard.

## Entry Point & Timing
1. `WorkoutSummaryView` loads.
2. Before `SuggestionGenerator.generateSuggestions(...)`, call `OutcomeResolver.resolveOutcomes(for: workout, context: context)`.
3. Outcome resolution targets changes from prior sessions only:
   - `change.outcome == .pending`
   - `change.createdAt < workout.startedAt`
   - `change.targetPlan?.id == workout.workoutPlan?.id`
   - `change.sessionFrom?.id != workout.id`

## Data Needed Per Change
- **Old prescription**: derive from `previousValue` (fallback to current prescription if nil).
- **New prescription**: derive from `newValue` (or bundle of related changes), applied to an in-memory copy.
- **Trigger performance**: `sourceExercisePerformance` / `sourceSetPerformance` (optional; may be deleted).
- **Actual performance**: match session exercise/set by prescription ID (fallback to index).

## Outcome Resolution (Rules + AI)
Rules and AI are both executed for every eligible change. The AI receives the rule outcome and reasoning as part of its input.

### Decision Policy
- If the **AI outcome differs** from the rule outcome and `ai.confidence >= 0.7`, **use the AI outcome**.
- Otherwise, **use the rule outcome**.
- If the rule outcome is `nil`, **always use the AI outcome** (regardless of confidence). Only keep `pending` if AI returns `nil`.

### Attempted vs Ignored
Outcomes are only judged as `good` / `tooAggressive` / `tooEasy` when the user appears to have **attempted** the intended target.

- **Accepted changes**: always eligible to evaluate, but still require an attempt to avoid mislabeling.
- **Rejected/deferred changes**: evaluate only if attempted; otherwise `ignored` (or leave pending if exercise not performed).

Attempt heuristics (deterministic):
- **Weight change**: attempted if `abs(actualWeight - newWeight) <= weightStep`.
  - Ignored if `abs(actualWeight - oldWeight) <= weightStep` and far from new.
- **Reps change**: attempted if `abs(actualReps - newReps) <= 1` or reps moved toward new target.
  - Ignored if reps stayed at old target.
- **Rest change**: attempted if `abs(actualRest - newRest) <= 15`.
  - Ignored if rest stayed at old target.
- **Rep range changes**: attempted if most completed regular sets fall inside the **new** range/target.
- **Set type changes**: attempted if actual set type matches the new type.

Where `weightStep` is computed via `MetricsCalculator.weightIncrement(for:primaryMuscle:equipmentType:)`, using the exercise/prescription equipment type and primary muscle (both required).

### Outcome Ordering (for AI guidance only)
- `ignored` (lowest priority)
- `tooAggressive`
- `good`
- `tooEasy`

This ordering is provided to the AI so it understands how outcomes are interpreted, but the merge logic is driven by confidence.

## Rule-First Resolution
### Matching
- Match `ExercisePerformance` by `prescription.id` when available.
- Match `SetPerformance` by `prescription.id`, else by index.
- If no matching exercise performance is found: **leave pending**.

### Tolerances
- Weight tolerance: `<= weightStep` (equipment-aware via `MetricsCalculator.weightIncrement(for:primaryMuscle:equipmentType:)`)
- Reps tolerance: `<= 1 rep`
- Rest tolerance: `<= 15 sec`

### Decision Matrix
| Change Type | Rule Input | Outcome Decision | When to return `ignored` |
| --- | --- | --- | --- |
| increase/decrease weight | actual set weight + reps vs new rep range | below floor => tooAggressive, within => good, above upper+2 => tooEasy | actual weight not within tolerance of new target |
| increase/decrease reps | actual reps vs new rep range | below floor => tooAggressive, within => good, above upper+2 => tooEasy | actual reps not within tolerance of new target reps |
| increase rest (set-level) | actual rest + reps vs rep range | below floor => tooAggressive, within => good, above upper+2 => tooEasy | rest not within tolerance of new target |
| increase rest time seconds (exercise-level) | actual rest + reps vs rep range | below floor => tooAggressive, within => good, above upper+2 => tooEasy | rest data missing |
| rep range changes (mode/lower/upper/target) | actual reps vs new rep range | below new lower/target => tooAggressive, within => good, above upper+2 => tooEasy | missing complete regular sets |
| change set type | actual set type | good if actual matches new type | mismatch or missing set |

## AI Outcome Models (FoundationModels)
Add a parallel AI path, modeled after `AIConfigurationInferrer`, to evaluate outcome for every change.

### Models
- `AIOutcomeInferenceInput`
  - `changeType` (Generable enum containing only rule-generated change types)
  - `previousValue`, `newValue` may be ambiguous for enum-backed changes (rep range mode, set type).
    - Use AI-friendly enum strings instead of raw numeric values.
    - Map `RepRangeMode` and `ExerciseSetType` to corresponding AI enums.

#### Rule-Generated Change Types (AI enum)
- `increaseWeight`, `decreaseWeight`
- `increaseReps`, `decreaseReps`
- `increaseRest`
- `increaseRestTimeSeconds`
- `changeSetType`
- `changeRepRangeMode`
- `increaseRepRangeLower`, `decreaseRepRangeLower`
- `increaseRepRangeUpper`, `decreaseRepRangeUpper`
- `increaseRepRangeTarget`, `decreaseRepRangeTarget`

## Rep Range Bundling
Rep range updates are emitted as multiple changes in the same session (mode + lower/upper/target).
For outcome evaluation:
- Build a temporary rep range policy by applying **all rep-range changes** for the same exercise and creation window.
- Evaluate against that composed policy, not an individual scalar change.
  - `previousValue`, `newValue`
  - `oldPrescription` (snapshot of target exercise + set)
  - `newPrescription` (snapshot with change applied)
  - `actualPerformance` (`AIExercisePerformanceSnapshot`)
- `AIOutcomeInferenceOutput`
  - `outcome` (`good`, `tooAggressive`, `tooEasy`, `ignored`)
  - `confidence` (0.0 - 1.0)
  - `reason`

### AI Rules of Use
- AI always runs and receives the rule outcome + reasoning in its input.
- Minimum `confidence` required (`>= 0.7`) for AI to override rule output.
- If rules are `nil`, accept AI even when confidence is low.

## OutcomeResolver Pipeline
1. **Gather Phase (Main Actor)**
   - Collect eligible `PrescriptionChange` items.
   - Build in-memory snapshots of old/new prescriptions (bundle rep-range changes).
   - Build `AIOutcomeInferenceInput` for all changes and include rule output (if any).
2. **Rules Phase (Main Actor)**
   - Produce `OutcomeSignal?` with `score`, `reason`, and `confidence`.
3. **AI Phase (Background)**
   - Run AI inference for all changes in parallel using a `TaskGroup` (same pattern as `SuggestionGenerator`).
4. **Merge Phase (Main Actor)**
   - Use AI outcome only if confidence >= 0.7 and it differs from rules.
   - Otherwise use rule outcome; if rule outcome is nil, accept AI regardless of confidence (unless AI returned nil).
   - Update `change.outcome`, `change.outcomeReason`, `change.evaluatedAt`, `change.evaluatedInSession`.
5. **Persist**
   - Save once per summary load.

## Implementation Notes
- `OutcomeResolver` should be `@MainActor` (similar to `SuggestionGenerator`).
- Use a non-mutating apply helper to compute a **new** prescription snapshot.
- Reuse `AIExercisePerformanceSnapshot` for actual performance input.
- Keep all new AI model types in a dedicated file near `AISuggestionModels.swift`.

## File Map
- New resolver: `VillainArc/Data/Classes/Suggestions/OutcomeResolver.swift`
- New AI models: `VillainArc/Data/Classes/Suggestions/AIOutcomeModels.swift`
- New AI inferrer: `VillainArc/Data/Classes/Suggestions/AIOutcomeInferrer.swift`
- Entry point: `VillainArc/Views/Workout/WorkoutSummaryView.swift`

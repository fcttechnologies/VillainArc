# Outcome Resolution Logic

**Status**: Implemented

This document describes how VillainArc resolves outcomes for prior `PrescriptionChange` records after a workout is completed.

## Purpose

Outcome resolution labels each pending change with one of:

- `good`
- `tooAggressive`
- `tooEasy`
- `ignored`

Resolution is hybrid:

1. Deterministic rules produce a per-change signal.
2. AI evaluates each change group and may override rules when confidence is high.

## Entry Point

Outcome resolution runs from workout summary flow before new suggestions are generated:

- `OutcomeResolver.resolveOutcomes(for:context:)`
- File: `Data/Classes/Suggestions/OutcomeResolver.swift`

## Eligibility

A change is eligible only if all are true:

- `change.outcome == .pending`
- `change.createdAt < workout.startedAt`
- Change belongs to prescriptions included in the current workout's performed exercises

Current logic does **not** filter by decision (`accepted`, `rejected`, `deferred`, etc). It resolves any eligible pending-outcome change.

## Grouping Model

Changes are grouped by exercise context to match suggestion UI structure and AI input shape:

1. Group by target exercise prescription.
2. Split into set-level vs exercise-level changes.
3. Set-level: group by `targetSetPrescription.id`.
4. Exercise-level: group by `changeType.policy` (`repRange` or `restTime`).

Grouping is used for AI evaluation and merge application.

## Pipeline

### 1) Gather and Group

- Collect eligible changes from performed exercise prescriptions.
- Match current workout performance by prescription ID.
- Build `OutcomeGroup` entries for resolution.

### 2) Rule Evaluation (Per Change)

`OutcomeRuleEngine.evaluate(change:exercisePerf:)` runs for each change and returns `OutcomeSignal?`:

- `outcome`
- `confidence`
- `reason`

Rule coverage currently includes:

- weight changes
- rep changes
- set-level rest changes
- exercise-level rest seconds changes
- rep range mode/value changes
- set type changes

Rules use attempt checks and tolerances (plate increment for weight, ±1 rep, ±15s rest), then classify intensity against rep-range context.

### 3) Build AI Group Input

For each group, resolver builds `AIOutcomeGroupInput` with:

- grouped `changes` (`previousValue`, `newValue`, optional `targetSetIndex`)
- `prescription` snapshot representing state **before** accepted changes
- `triggerPerformance` (session that created the change)
- `actualPerformance` (current workout)
- aggregated group rule hint (`ruleOutcome`, `ruleConfidence`, `ruleReason`)

Important detail:

- To create a true pre-change snapshot, resolver reverts accepted/userOverride changes from live prescription state.

### 4) AI Inference (Per Group, Parallel)

- File: `Data/Classes/Suggestions/AIOutcomeInferrer.swift`
- API: `AIOutcomeInferrer.infer(input:)`
- Model: `SystemLanguageModel.default`
- Execution: `TaskGroup` parallel inference across groups

AI returns one `AIOutcomeInferenceOutput` per group:

- `outcome`
- `confidence`
- `reason`

### 5) Merge and Apply (Per Change)

Even though AI output is group-level, merge is applied per change in that group:

1. If rules are missing and AI exists: use AI (`[AI] ...`).
2. If AI is missing and rules exist: use rules (`[Rules] ...`).
3. If both exist and disagree:
   - AI overrides only when `ai.confidence >= 0.7` (`[AI override] ...`).
   - Otherwise rules win.
4. If both missing: leave unresolved.

Resolved fields:

- `change.outcome`
- `change.outcomeReason`
- `change.evaluatedAt`
- `change.evaluatedInSession`

Resolver saves once at end.

## Rule Aggregation for AI Hint

AI receives one rule hint per group using priority:

1. `tooAggressive`
2. `good`
3. `tooEasy`
4. `ignored`

This aggregation is for AI context only. Final merge still uses each change's own rule signal.

## Key Files

- Resolver orchestrator: `Data/Classes/Suggestions/OutcomeResolver.swift`
- Deterministic rule evaluator: `Data/Classes/Suggestions/OutcomeRuleEngine.swift`
- AI outcome models: `Data/Classes/Suggestions/AIOutcomeModels.swift`
- AI outcome inference: `Data/Classes/Suggestions/AIOutcomeInferrer.swift`

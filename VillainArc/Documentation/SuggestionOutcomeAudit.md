# Suggestion & Outcome System Audit Report

## HIGH — Should Fix Before Launch


## MEDIUM — Worth Fixing


### 6. AI outcome validate silently discards entire inference on reason formatting
`AIOutcomeInferrer.swift:97-108`

If the on-device LLM produces a reason with `\n` or exceeding 160 chars, the *entire* output (including a potentially correct outcome and confidence) is discarded. The system falls back to rules-only.

**Fix:** Collapse newlines to spaces and truncate reason rather than discarding the full output.

---

### 7. RPE data omitted from AI snapshots
`AIExercisePerformanceSnapshot.swift` / `AIExercisePrescriptionSnapshot.swift`

`SetPerformance.rpe` and `SetPrescription.targetRPE` are not included in AI snapshots. RPE is the strongest per-set difficulty signal, but the model must infer difficulty solely from weight/reps. This limits AI quality when weight/reps look normal but RPE indicates struggle (e.g., same weight, same reps, RPE went from 7 to 9).

---

### 8. Kettlebell (double) increment may be miscalibrated
`MetricsCalculator.swift:427-428`

For `.kettlebell`, the code divides `currentWeight / 2` to get per-hand, then returns a total increment of 2.5 or 5.0. But paired kettlebells are discrete-weight implements — you jump the whole kettlebell, not add fractional plates. The actual jump from 2x16 to 2x20 is 8kg total, not 5.0. The increment underestimates real kettlebell jumps.

---

### 9. `normalizedRange` forces minimum width for heavy singles/doubles
`RuleEngine.swift:1265-1274`

`max(lower + 2, ...)` forces a minimum range width of 2. For heavy singles/doubles where all observed reps are 1-2, this creates an artificial range like 1-3, suggesting the user should sometimes do triples when they're doing max-effort singles. The minimum width should respect the observed rep distribution.

---

### 10. Rest overshoot outcome labels are semantically inverted vs weight/reps
`OutcomeRuleEngine.swift:236-249`

For rest increases (easier), overshooting is tagged `.insufficient`. For rest decreases (harder), overshooting is tagged `.tooEasy`. This is the opposite semantic frame from weight/reps, where overshooting in the harder direction is `.tooEasy`. The labels mean "the change didn't go far enough" rather than "the change was too easy/aggressive," which could produce confusing outcome data.

---


## Architecture Observation (Not a Bug)

**Outcome data not fed back into generation.** The outcome results (`tooAggressive`, `tooEasy`, `ignored`, etc.) are stored but never read by `RuleEngine` or `SuggestionGenerator`. The system can detect that a 2.5kg increase was too aggressive, but the next time it generates suggestions for that exercise, it will suggest the same 2.5kg increase again. This is the biggest systemic gap — the learning loop doesn't close. Documented as a planned post-launch improvement.

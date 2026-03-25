# Suggestion & Outcome System Audit Report

## HIGH — Should Fix Before Launch

### 1. Orphaned events can permanently block the deferred suggestions gate
`SuggestionGrouping.swift:29-35` / `DeferredSuggestionsView.swift:75-86`

If a plan exercise is deleted (e.g., via plan edit or CloudKit sync) while suggestion events still reference it, `pendingSuggestionEvents` returns those orphaned events (they pass the decision filter), but `groupSuggestions` silently drops them (nil `targetExercisePrescription`). Result: `sessionEvents` is non-empty so the view stays, but `sections` is empty — the user sees a blank screen with no suggestions and no way to proceed except "Skip All". Users who don't realize Skip All works are hard-stuck.

**Fix:** Filter out events with nil `targetExercisePrescription` in `pendingSuggestionEvents`, or auto-reject orphaned events in `refreshSections`.

---

### 2. Silent no-op on rep-range accept when `repRange` is nil
`SuggestionReviewView.swift:267-274`

`applyChange` uses optional chaining: `event.targetExercisePrescription?.repRange?.lowerRange = Int(change.newValue)`. If `repRange` is nil on the exercise, all rep-range changes silently do nothing, but the event is still marked `.accepted`. The user sees "Accepted" while the plan is unchanged.

**Fix:** Create a default `RepRangePolicy()` if nil before applying rep-range changes, similar to how `syncRepRangeFromPrescription` does on the performance side.

---

### 3. Drop set clusters silently produce zero suggestions
`MetricsCalculator.swift:164-165`

`setsForStyle(.dropSetCluster, ...)` returns `[]`. Every progression/safety rule in `RuleEngine` guards on `!progressionSets.isEmpty` and returns early. If training style resolves to `.dropSetCluster` (either deterministically or via AI), the entire rule engine is bypassed — no suggestions at all, with no indication to the user.

**Fix:** Either define meaningful progression sets for drop set clusters, or explicitly log/surface that drop set clusters are intentionally excluded from suggestion generation.

---

### 4. Orphaned suggestion events on direct plan deletion
`ExercisePrescription.swift:23-24`

`ExercisePrescription.suggestionEvents` uses `deleteRule: .nullify`. When a plan is deleted, its exercises are cascade-deleted, which nullifies `targetExercisePrescription` on all associated events — but leaves the events alive. `deleteWithSuggestionCleanup` handles this correctly, but if `context.delete(plan)` is ever called directly (bypassing the cleanup method), orphaned `SuggestionEvent` objects accumulate indefinitely with no way to surface or clean them up.

**Fix:** Add a guard at deletion call sites, or change the delete rule to `.cascade` if orphaned events are never useful.

---

## MEDIUM — Worth Fixing

### 5. AI validation rejects valid results due to float precision
`AITrainingStyleClassifier.swift:50-53`

`validate` clamps confidence to `[0, 1]`, then rejects if clamped differs from original. A confidence of `1.0001` (common floating-point noise from on-device LLM) discards the entire inference. The `@Guide` range annotation is not guaranteed to be precise.

**Fix:** Use epsilon comparison (`abs(clampedConfidence - output.confidence) < 0.001`) or simply clamp-and-accept.

---

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

### 11. Escalation preserves evaluations, allowing safety signals to be outvoted
`OutcomeResolver.swift:404-408`

When 2 evaluations conflict (e.g., `.tooAggressive` + `.tooEasy`) and escalate to require 3, the existing evaluations are kept. The 3rd evaluation then tips the scales. With asymmetric scoring (`tooAggressive: -2`, `tooEasy: +1`, `good: +2`), one `.good` evaluation can outweigh a `.tooAggressive` safety concern: `(-2*0.8) + (1*0.8) + (2*0.8) = 0.8`, finalizing as `.good` despite a safety-relevant negative signal.

---

### 12. No timeout on AI calls
`AITrainingStyleClassifier.swift` / `AIOutcomeInferrer.swift`

Both `session.respond(to:generating:)` calls have no timeout. If the on-device model stalls under extreme load, the user sees an indefinite loading state in the summary view with no recovery path.

---

## LOW — Minor / Defensive Hardening

**13.** `steadyRepIncreaseWithinRange` uses hardcoded 2.5kg tolerance regardless of equipment type (`RuleEngine.swift:354`).

**14.** No guard against inverted rep ranges (`lower > upper`) — could produce contradictory "harder weight + more reps" suggestions (`RuleEngine.swift` various).

**15.** `musclesTargeted.first ?? .chest` fallback gives lower-body exercises chest-sized increments (2.5kg instead of 5.0kg) when muscles are empty (`SuggestionGenerator.swift:221`).

**16.** Prewarmer session has no tools/instructions, so it may not effectively warm the code paths used by actual inference (`FoundationModelPrewarmer.swift`).

**17.** `latestEvaluation` sort is non-deterministic for same-timestamp evaluations (`SuggestionEvent.swift:70-72`).

**18.** `WorkoutPlanSuggestionsSheet` has no rapid-tap guard on accept/reject buttons, unlike the other two surfaces.

**19.** `acceptAll` in `DeferredSuggestionsView` calls `proceedToWorkout` unconditionally without verifying all events were actually applied (if one failed silently, the gate is bypassed).

---

## Architecture Observation (Not a Bug)

**Outcome data not fed back into generation.** The outcome results (`tooAggressive`, `tooEasy`, `ignored`, etc.) are stored but never read by `RuleEngine` or `SuggestionGenerator`. The system can detect that a 2.5kg increase was too aggressive, but the next time it generates suggestions for that exercise, it will suggest the same 2.5kg increase again. This is the biggest systemic gap — the learning loop doesn't close. Documented as a planned post-launch improvement.

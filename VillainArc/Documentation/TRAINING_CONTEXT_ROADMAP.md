# Training Context Roadmap

This is a forward-looking roadmap for what comes after the first condition-model integration. Use the other documents in this folder for the current app architecture and runtime flows.

This document is the working roadmap for the next layer of VillainArc's training intelligence. The goal is to add more context to workouts, suggestions, split behavior, and later session adaptation without losing the clean boundaries the app already has.

This roadmap is intentionally phased. We want to ship each piece one by one without losing sight of the long-term system.

## Why This Exists

VillainArc already has strong output signals:

- workout performance
- completed sessions
- weight history and goals
- sleep
- steps and energy
- suggestion generation
- suggestion outcome evaluation

The next major improvements should focus on explaining why performance changed and protecting the system from learning the wrong thing when the user is not training under normal conditions.

## Current Architecture That We Want To Preserve

The current system already has several good boundaries:

- `WorkoutSession` is the app-owned source of truth for what happened in a workout.
- `HealthWorkout`, `WeightEntry`, `HealthSleepNight`, `HealthStepsDistance`, and `HealthEnergy` are Health integration layers and caches.
- `WeightGoal` already demonstrates a clean date-ranged historical model with one active goal at a time.
- `SuggestionEvent` is a persisted coaching event with its own decision and later outcome lifecycle.
- `PreWorkoutContext` is session-scoped context, not global user state.
- `WorkoutSplit` is the raw schedule model, even though it currently owns its own scheduling logic.

We want to extend the system in a way that respects those boundaries instead of collapsing everything into one giant settings object.

## Guiding Principles

- Prefer date-ranged historical truth over mutable singleton state.
- Prefer additive models and resolver layers over invasive rewrites.
- Keep session context separate from cross-session user condition.
- Keep temporary session adaptations separate from long-term plan mutations.
- Only snapshot context when it is actually used for reasoning, so historical interpretation does not drift later.
- Treat the absence of a non-normal condition as the default "training normally" state.

Sleep sync now exists in the Health integration layer. `TrainingConditionPeriod` also now exists as an app-owned model with a Health-tab status surface, editor, and history. The split/context resolver layer is also now in place on top of `WorkoutSplit` and `TrainingConditionPeriod`. Use `Documentation/HEALTHKIT_INTEGRATION.md`, `Documentation/PROJECT_GUIDE.md`, and `Documentation/ARCHITECTURE.md` for the current implementation details. The roadmap below now mainly describes the remaining session-override layer that builds on top of that foundation.

## Phase 1 Status: Complete

The first condition-model integration is now in place.

Current shipped shape:

- `TrainingConditionPeriod`
- fields:
  - `kind`
  - `trainingImpact`
  - `startDate`
  - `endDate`
  - optional affected muscles for injury/recovery cases
- only one active non-normal condition at a time through app logic
- no persisted fake `normal` row
- top-of-Health status surface plus editor and history

Important behavior already implemented:

- ending a condition returns the user to the default "training normally" state
- replacing with a different kind ends the previous active period and starts a new one
- editing the same active kind updates the existing period in place
- an `endDate` remains active through the end of that day in the UI, while being stored as an exclusive upper bound internally

## Phase 2 Status: Complete

The split/context resolver layer is now also in place.

Current shipped shape:

- `SplitScheduleResolver`
- `WorkoutSplit` remains the raw schedule model
- active condition periods can now affect effective split resolution without being shoved directly into `WorkoutSplit`
- paused conditions freeze effective split progression instead of letting rotation continue to advance blindly
- home UI, quick actions, and workout-split intents now use the same resolved behavior

Important behavior already implemented:

- weekly mode now distinguishes a true split rest day from a condition-driven pause
- rotation mode no longer auto-advances through paused periods
- paused conditions block "today" actions that would otherwise open or start the scheduled workout
- non-paused conditions can influence scheduling behavior without mutating the split itself

With that integration done, the main remaining core product work is:

- add session adjustments / session overrides

## Why This Model Exists

Recommended condition kinds for the first version were:

- `sick`
- `injured`
- `recovering`
- `traveling`
- `onBreak`

Recommended impact values were:

- `contextOnly`
- `trainModified`
- `pauseTraining`

Important rules that still matter:

- only one active non-normal condition at a time
- active periods must never overlap
- changing condition ends the previous period and starts a new one
- returning to normal should usually just end the active period
- do not persist a fake `normal` or `active` condition row

Why this model should exist:

- it gives the app real history
- it can answer "what condition was active on this workout date?"
- it improves split behavior
- it gives richer context to session data
- it creates the foundation for later session adaptations

### Injury Scope

Injury scope should be included in the first version if possible.

The current first version is:

- affected muscles

That is enough to make future logic much smarter without inventing a much bigger injury taxonomy on day one.

## Important Separation: Condition vs Session Context

`TrainingConditionPeriod` is not a replacement for `PreWorkoutContext`.

These are different concepts:

- `TrainingConditionPeriod` explains a multi-day or multi-week abnormal training state
- `PreWorkoutContext` explains how the user felt for one workout

Examples:

- a user can be healthy overall but feel tired today
- a user can be recovering from illness but still feel good before one specific workout

Recommendation:

- keep `PreWorkoutContext`
- do not remove it just because `TrainingConditionPeriod` is added
- if we ever rename it, `SessionStartContext` would be a better name than removing the concept

## Remaining Phase: Session Adjustment / Session Override System

Once the app understands condition periods, the next major system is temporary workout adaptation.

Recommended concept:

- `SessionAdjustment`
- or `SessionOverride`

This system should:

- change the current workout targets
- not mutate the long-term plan
- display adjusted targets in the workout UI
- keep the original plan intact

Examples of future adjustment types:

- reduce load
- reduce sets
- increase rest
- swap exercise
- pause or block session

This is intentionally different from `SuggestionEvent`.

Why it should stay separate at first:

- suggestions are about long-term plan changes
- session adjustments are about temporary protective changes
- a condition-modified workout is not always valid evidence for normal plan progression

## How Session Adjustments Should Learn Later

The first version does not need heavy automation, but it should preserve enough information to learn over time.

The later learning loop should record:

- what condition was active
- what adjustment was proposed
- what the user accepted, rejected, or edited
- how the session went

This likely wants quicker evaluation than the current suggestion outcome system because session adjustments are temporary and context-specific.

## Suggestions And Outcome Resolution With More Context

Later, VillainArc should use condition and health context to improve suggestions and outcome resolution.

Examples:

- condition-modified sessions may suppress new progression suggestions
- condition-modified sessions may not resolve prior suggestions normally
- sleep and other recovery signals can affect confidence, not just raw outcome labels
- unhealthy or abnormal-context sessions should not poison long-term learning

Important design rule:

- if a piece of context is actually used for reasoning, snapshot the relevant subset at the time of reasoning

That prevents old suggestions or evaluations from changing interpretation later when:

- Health data backfills
- imported data changes
- condition history is edited

## What Should Stay Separate In The Future

Not everything belongs in `TrainingConditionPeriod`.

These should stay separate:

- session start mood and pre-workout use
- long-term training phase or intent
- daily readiness check-ins such as soreness or stress
- passive health metrics such as sleep, HRV, and resting heart rate

Likely future additions:

- `TrainingPhasePeriod`
  - examples: `strength`, `hypertrophy`, `maintain`, `cut`, `returnFromInjury`, `deload`
- `DailyReadinessEntry`
  - examples: soreness, stress, fatigue
- more Health context caches
  - resting heart rate
  - HRV

## Recommended Working Order

1. Add session adjustments / session overrides.
2. Start feeding context into suggestion generation and outcome resolution.
3. Later add training phase and readiness models if needed.

## Final Product Direction

The long-term goal is not just more data.

The goal is a system that:

- understands when the user is training normally
- understands when the user is not
- protects plan learning from bad evidence
- adapts single sessions safely without corrupting the long-term program
- becomes more useful as more context is added

If we keep these boundaries intact, VillainArc will be in a strong position to support:

- better split behavior
- smarter coaching
- safer temporary adaptations
- richer Health-informed insights
- future personalization without a rewrite

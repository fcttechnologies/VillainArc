# VillainArc Roadmap

This document is the working plan for pre-push readiness and post-launch features. It is ordered by priority and includes reasoning so future context is preserved.

---

## Phase 1: Pre-Push Readiness

These are things that are significantly harder or impossible to fix cleanly once real users have data in production CloudKit.

---

### ~~1. Remove `origin` from models~~ ✅ Done

Removed `origin: Origin` from `WorkoutPlan` and `WorkoutSession`. Deleted `Origin.swift`. Updated `SpotlightIndexer` to use `workoutPlan != nil` instead. Removed from `WorkoutSessionEntity` DTO. Confirmed no test references.

Goals and training style are separate concerns: goals will be a temporal model with start/end dates when the time comes; training style will be a simple optional field on `UserProfile` with a default; profile image will use `@Attribute(.externalStorage)` as an optional. None of those need to happen now.

---

### 2. Accessibility Audit

**Status:** Not started.

Run the accessibility auditor across the full app. Priority order for review:
1. Active workout flow — highest interaction density, most custom UI (set rows, exercise pages, quick-action buttons)
2. Suggestion review — accept/reject/defer cards
3. Plan editor — exercise/set rows with drag handles
4. Exercise detail and history

Things to check:
- VoiceOver coverage on all interactive elements
- Dynamic Type — no fixed-size frames that clip text at large accessibility sizes
- Color contrast — especially the accent-color-heavy workout UI
- Minimum tap target sizes on set row quick-action buttons
- Consistency of the `Helpers/Accessibility.swift` identifier scheme across flows

**Done when:** Auditor finds no critical issues and VoiceOver can navigate all primary flows without getting stuck.

---

### 3. Localization Readiness

**Status:** Not started.

Check whether user-facing strings use `String(localized:)` / `LocalizedStringKey` or are hardcoded literals. Check whether a `.xcstrings` String Catalog exists.

Decision to make: English-first launch (acceptable if the catalog is at least set up so adding languages is additive later) vs. localize before launch.

Regardless of that decision, verify before push:
- All date, number, weight, and time formatters are locale-aware
- Weight display in particular — lbs vs kg matters internationally. If the app is US-first by default, consider whether to add a `weightUnit` preference to `AppSettings` now while the schema is still clean.

**Done when:** Formatter audit is clean and a decision on localization scope is made.

---

### 4. Model Discovery and Cleanup Pass

**Status:** Not started. Do this after accessibility and localization so the schema is stable before locking V1.

Go through every `@Model` type one by one. For each:
- Is anything on it dead weight that we can remove now? (Like `origin` was.)
- Is anything typed incorrectly or more constrained than it needs to be?
- Is anything missing that we know we'll want — and that would be harder to add cleanly after V1 is locked?
- Does the model make sense given the features we're planning (AI plan gen, split gen, goals, training style)?

Known items to evaluate during this pass:
- `UserProfile` — add optional fields for experience level, primary goal (or defer to the temporal UserGoal model), training style, available equipment. These are the inputs the AI features will want. Better to add them as nil-defaulted optionals now than after V1.
- `AppSettings` — anything missing for international users (weight unit)? Any future AI preference toggles worth reserving a slot for?
- `WorkoutSplit` — anything missing? No notes field on days, no experience/goal context for AI generation.
- `SuggestionEvent` / `PrescriptionChange` — are all fields actively used or is anything vestigial?
- `ExerciseHistory` / `ProgressionPoint` — any metrics that are stored but never displayed, or missing metrics that would be useful?
- `RestTimeHistory` — minimal by design, still correct?

**Done when:** Every model has been reviewed, dead fields removed, and any pre-V1 additions made.

---

### 5. Establish VersionedSchema V1

**Status:** Not started. Do this last in Phase 1, after the model cleanup pass, so V1 is locked on a clean schema.

**Why now and not later:** Setting up VersionedSchema with existing user data is safe — SwiftData sees the store already matches V1 and does nothing. But doing it before the first production push means V1 is the baseline from day one, and every future structural change is a clean versioned migration rather than hoping SwiftData's automatic lightweight migration handles it correctly.

**What to do:**
- Wrap all `@Model` types in a `SchemaV1` namespace inside a `VersionedSchema` enum
- Declare `SchemaMigrationPlan` with V1 as the current version and an empty `stages` array
- Update `SharedModelContainer` to pass the migration plan to `ModelContainer`
- Verify the container opens correctly

**What this does NOT require:**
- Any data migration (V1 is identical to the post-cleanup schema)
- Changing any model properties

**After this:** Adding optional fields or non-optional fields with inline defaults never needs a migration. Renaming, type changes, or structural relationship changes get a V2 with a migration stage.

---

## Phase 2: Post-Launch

### Suggestion Learning Loop

Close the outcome → generation feedback gap. Outcome data (`good`, `tooAggressive`, `tooEasy`, `ignored`) is stored on `SuggestionEvent` but not currently fed back into `RuleEngine` / `SuggestionGenerator`. No schema changes needed — the data is already there.

Changes confined to: `SuggestionGenerator.swift`, `RuleEngine.swift`, and the suggestion context type that carries outcome history into generation.

---

### Foundation Models Features

All use guided generation → user reviews draft → user accepts → saved. All use existing models. No new `@Model` types required.

**In priority order:**

1. **Workout plan generation** — text-based, accounts for target muscles/exercises/goals. Creates a `WorkoutPlan` draft the user reviews in the plan editor before saving.

2. **Workout split generation** — user describes schedule and goals, model generates a `WorkoutSplit` with days. Composable with plan generation (days can reference generated or existing plans).

3. **Session / plan feedback** — ephemeral conversational AI in `WorkoutPlanDetailView` and `WorkoutSummaryView`. Seeds context from the current plan or session. Not stored in SwiftData.

4. **In-session AI assistant** — opt-in sheet in `WorkoutView`. User asks questions or requests exercise suggestions. Adding an exercise still goes through the normal `AddExerciseView` flow. Always opt-in, never interrupts mid-set.

---

## Summary Checklist

### Before Push
- [x] Remove `origin` from `WorkoutPlan`, `WorkoutSession`, and all call sites
- [ ] Accessibility audit — critical findings fixed
- [ ] Localization — formatters locale-aware, decision on string localization scope made
- [ ] Model discovery and cleanup pass
- [ ] VersionedSchema V1 established in `SharedModelContainer`

### Post-Launch
- [ ] Suggestion learning loop
- [ ] AI plan generation
- [ ] AI split generation
- [ ] Session / plan feedback
- [ ] In-session AI assistant

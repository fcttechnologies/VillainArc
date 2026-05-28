# Villain Arc 1.3 Release Notes

The 1.3 release turns Villain Arc from strength-only into a broader training and health companion: app-owned cardio, expanded Apple Health coverage, a Profile tab with insight surfaces, hydration tracking, on-device AI plan generation and exercise replacement, and a six-program template library.

This file is the internal change log. The customer-facing "What's New" copy lives in `APP_STORE_METADATA.md`.

---

## Added

### Cardio (new tab)

- Added a dedicated Cardio tab with a map-first recent-routes view, start cards for outdoor run, outdoor walk, treadmill run, and treadmill walk, plus recent cardio history and detail views.
- Added `CardioSession`, `CardioRoutePoint`, and `CardioTreadmillInterval` SwiftData models so cardio is app-owned instead of only mirrored from Apple Health.
- Added a full-screen active cardio flow with minimize/resume behavior, outdoor route recording, treadmill interval entry, live metrics, finish/cancel confirmation, and completed-session detail.
- Added manual treadmill support: enter speed (mph), duration, and incline per interval; the app calculates distance without GPS or Apple Health.
- Added outdoor route recording with When-In-Use location permission, activity type `.fitness`, distance filter `8 m`, and low-accuracy GPS points discarded before insert.
- Added optional Apple Health live cardio workout support when permissions exist: live heart rate, active energy, walking/running distance, linked Health workout mirrors, and HealthKit workout effort score writes.
- Added a separate Cardio Live Activity and Dynamic Island presentation with elapsed time, distance, pace, heart rate or energy, and route or interval count.
- Added active cardio resume bars in the app shell.
- Cardio completion contributes to Profile workout streak and complete-day workout credit.
- Added Cardio App Intents (`StartCardioSessionIntent`, `OpenActiveCardioSessionIntent`).

### Profile tab and Settings split

- Added a dedicated Profile tab. Owns avatar/photo management, name, birthday, gender, height editing, fitness-level editing and the time-threshold review cue, active training-goal editing, training summary stats, muscle-map distribution, workout streak, and a two-month complete-day heatmap.
- Added Profile complete-day tracking that surfaces workout completion, sleep goal completion, steps goal completion, and hydration goal completion as a heatmap.
- Settings remains an `AppSettingsView` surface (reached from Profile, app intents, legacy settings routes) with app preferences, support/legal links, App Store review entry, and safe-area-aware scroll padding so content is not hidden behind the quick-action bar.

### Hydration

- Added hydration tracking with manual water entries, Apple Health dietary-water import/export, active hydration goals, hydration goal history, hydration charts, and hydration goal completion notifications.
- Added `HydrationDay` as the daily hydration aggregate (total volume, goal target, completion timestamp, linked entries).
- Added an Add Water quick action to the main action bar.
- Hydration goals are historical `HydrationGoal` records; replacing or deleting reconciles affected hydration days.
- Added hydration widgets, summary cards, history, and goal-history surfaces.

### Health expansion

- Added expanded HealthKit permissions for heart-rate range, resting heart rate, walking heart rate average, heart-rate variability, respiratory rate, sleeping wrist temperature, and dietary water.
- Added Health tab cards and history screens for heart-rate range, resting heart rate, walking heart rate average, HRV, respiratory-rate range, and sleeping wrist temperature.
- Added matching Health widgets for heart vitals, respiratory rate, wrist temperature, and hydration.
- Added a temperature unit setting for wrist temperature display.
- Added a sleep weekday chart mode switch for average sleep, average bedtime, and average wake time.

### Health Trends

- Added `HealthTrendsView` with sparkline cards for weight, sleep duration, resting heart rate, total daily energy, daily steps, and per-session workout volume.
- 7D / 30D / 90D / 1Y range picker with a 30D default.
- Tapping a card opens a full-screen detail sheet with a larger Swift Charts line + area chart, axis labels, the same range picker, and a one-line auto-generated insight.
- All data sourced from existing SwiftData caches and the app-owned `WorkoutSession` store; no new HealthKit queries are issued.

### Sleep Timing Insights

- Added `SleepTimingInsightsView` with average bedtime/wake-time means (± spread from standard deviation over the trailing 30 days), average total sleep, a 0–100 consistency score, a sleep-efficiency tile (`timeAsleep / timeInBed`), and a 14-day scatter chart of bedtime/wake points.
- Auto-generated bedtime-shift insight when the half-over-half change is ≥ 5 minutes, with a steady-week fallback at ≥ 7 nights.

### Correlation Insights

- Added `CorrelationInsightsView` pairing per-session quality scores derived from accumulated `SuggestionEvent.userFeedback` ratings with sleep duration and average RPE.
- Two Swift Charts scatter plots (sleep vs quality, RPE vs quality) with a closed-form linear regression line and Pearson correlation coefficient.
- Empty state until 8 rated sessions exist; an auto-headline insight surfaces when sleep ≥ 7 h and average RPE ≤ 8 both align with high quality, or when Pearson magnitude crosses 0.3.

### Post-session outcome rating

- Added an inline "How'd it go?" section on `WorkoutSummaryView` with four cards (`great`, `good`, `ok`, `tough`).
- Selecting a card writes `UserFeedback` into every rateable `SuggestionEvent` on the session.
- The section stays visible after rating and allows re-rating in the same summary (events stay in-scope via `appliedFeedbackEventIDs`).
- Feedback is the read-side signal that powers Correlation Insights.

### AI features (Foundation Models)

- Added `AIWorkoutPlanGenerator`: on-device AI plan generation from a free-text prompt. The new "Generate with AI" entry on `PlanBuilderSheet` opens a prompt sheet (quick-pick chips + free text). The generator builds a structured `@Generable AIGeneratedPlan`, fuzzy-matches each exercise name against the catalog (5 strategies), and either drops a single-day result into the editor or materializes a multi-day result as a full program with active split.
- Added `AIExerciseReplacementSuggester`: when replacing an exercise, an "AI Suggestions" horizontal scroll surfaces 3–5 candidates from `SystemLanguageModel.default` based on the current exercise + fitness level + training goal. Each suggestion fuzzy-matches against the catalog and triggers the same Keep Sets / Clear Sets confirmation as the deterministic list.
- AI surfaces gracefully hide when `SystemLanguageModel.default.availability != .available`.
- User prompts are capped at 500 characters and sanitized (control chars stripped, default-ignorable code points removed, truncation at word boundary) before reaching the model.

### Plan templates

- Added a static `PlanTemplate` catalog with six pre-built programs: Push/Pull/Legs (6-day), Upper/Lower (4-day), Full Body (3-day), Stronglifts 5×5 (3-day), 5/3/1 BBB (4-day), Bro Split (5-day).
- Added `PlanTemplateMaterializer` for three shapes: single-day → editable WorkoutPlan, full program → completed WorkoutPlans + rotation WorkoutSplit, and AI variants for both.
- Added `PlanBuilderSheet` ("Start from Scratch" / "Generate with AI" / "Templates") as the unified entry from Home and from `WorkoutPlanPickerView`.
- Added `PlanTemplateDetailView` to preview templates day-by-day before materializing.
- Added the same registry to `SplitBuilderView` under "Or pick a full program."

### Replace exercise

- Replace-exercise picker now uses a deterministic muscle-overlap + equipment-match ranker via `FilteredExerciseListView.preferredMuscles` + `preferredEquipmentType`.
- AI Suggestions section renders above the deterministic list when Apple Intelligence is available.

### Onboarding, education, and re-entry

- Added an Onboarding Slideshow on first launch (4-screenshot paging TabView before readiness).
- Added a What's New sheet: version-tracked, Apple-style modal on launch after a version bump.
- Added a review prompt: `SKStoreReviewController.requestReview` after the 3rd completed session, one-time flag.
- Added 4 TipKit tips on workout options, exercise context menus, suggestion review, and the exercise history chart.

### Rest timer

- Redesigned the rest-timer sheet around a circular countdown with Skip, Extend, and Pause/Resume controls.
- Added a completion haptic and a "Rest time done" Live Activity transient status.
- Added a +/− adjustment row that mutates the shared timer state without touching set data.

### Split and session UX

- Added a split-aware Add Exercise sheet that emphasizes catalog exercises matching the active split day's target muscles, with the workout plan's muscles as a fallback.
- Added a pre-workout Session Condition prompt (great / good / tired / sore) with a hard-day flag on tired/sore.
- Added a pre-workout Health Context row that surfaces cached sleep duration and resting heart rate before the session begins.
- Added support for opening source workouts from exercise history rows.
- Added richer Exercise Detail: muscle map, personal records, polished progression charts, how-to steps, recent performances, and a route to full exercise history.
- Added workout plan history and training insight cards to plan details.

### Other

- Added the `MuscleMap` local Swift package and used it for exercise and profile muscle diagrams.
- Added support for standalone/imported completed exercise performances in exercise-history rebuilding.
- Added a setting for whether planned workout previous-set references use any matching workout or the last completed session from the same plan.
- Added a temperature unit setting for wrist temperature display.
- Added debug tools for seeding workout data, seeding Health sample scenarios, and touching all model tables.

## i18n

- Added first-pass es / fr / de / pt-BR translations marked `needs_review` for 60 high-visibility v1.3 strings.
- `WhatsNewSheet`, `OnboardingSlideshow`, and other v1.3 surfaces use `LocalizedStringResource`.

## Fixed

- Fixed Health workout detail rendering when the original Apple Health workout is no longer available; the screen no longer shows broken empty heart-rate sections.
- Fixed Health workout summaries to include average and maximum heart rate when cached values are available.
- Fixed profile/settings navigation by moving Profile into a real tab instead of relying on Home and Health header buttons.
- Fixed Settings bottom spacing so content is not hidden behind the custom quick-action safe-area bar.
- Fixed active-flow protection so workouts, workout-plan creation/editing, and cardio sessions cannot be started on top of each other.
- Fixed app resume so unfinished cardio sessions are discovered and restored like unfinished strength workouts and plans.
- Fixed workout history duplication for cardio-linked Apple Health workouts (mirrors already attached to a `CardioSession` are excluded).
- Fixed hydration goal ownership by removing the old `AppSettings.hydrationDailyGoalML` setting and using `HydrationGoal` / `HydrationDay` as the source of truth.
- Fixed hydration widgets and charts to use the active hydration goal instead of a global app setting.
- Fixed onboarding bootstrap cleanup so incomplete workouts and plans are removed during onboarding setup.
- Fixed exercise detail chart defaults and layout so max weight is the default and charts use the same card style as Health views.
- Fixed exercise-history rebuilds so standalone all-sets-complete performances can contribute to cached history.
- Fixed the outcome rating UI so the section stays visible after rating and supports re-rating.
- Fixed What's New feature list to reflect the actual v1.3 shipped features.

## Security

See `SECURITY_REVIEW_v1.3.md`. No critical or high findings. One medium (`M1`: unbounded user free text reaching the on-device model) is fixed. Pre-existing low items (`L1`–`L3`) are tracked; `L1` (residual `print()` calls on the live workout coordinator) was cleaned up in the pre-submission pass.

## Villain Arc Pro

Added the Villain Arc Pro subscription tier via StoreKit 2.

- Monthly plan: $4.99 USD with a 7-day free trial.
- Yearly plan: $39.99 USD with a 7-day free trial.
- Family Sharing enabled on both tiers.
- Five features gated behind Pro: AI Plan Generation, AI Exercise Replacement, Health Trends, Sleep Timing Insights, Correlation Insights.
- All other features — plans, templates, logging, cardio, hydration, widgets, shortcuts — remain free.
- Paywall is a full-screen sheet triggered via `SubscriptionGate.require(.feature) { action }` at each call site. The sheet spotlights the triggering feature.
- Subscription state is cached to the App Group so the widget can read `isPro` without a StoreKit query, and cold-launch avoids a paywall flash for known-Pro users.
- Restore Purchases available in Settings → Subscription.
- Implementation: `Data/Services/Subscription/SubscriptionStore.swift`, `SubscriptionGate.swift`, `Views/Subscription/PaywallView.swift`, `Views/Subscription/PremiumLockedView.swift`. Flow documented in `SUBSCRIPTION_FLOW.md`.

## Tests

- Added unit coverage on plan template materialization and the FoundationModels resolver paths (`VillainArcTests/PlanTemplatesTests.swift`, `VillainArcTests/AIWorkoutPlanGeneratorTests.swift`).

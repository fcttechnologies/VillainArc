# VillainArc Product Roadmap

Use the other files in this folder for current architecture and shipped behavior. Use this file when deciding what to build next, how to group work into releases, and which ideas should plug into existing systems versus become new systems.

## Planning Principles

- Prefer extending the current app architecture over introducing parallel systems.
- Keep date-ranged historical models for goals that can legitimately change over time.
- Keep one-off preferences separate from goals unless history is part of the product.
- Keep temporary session adaptation separate from long-term plan mutation.
- Do not let richer Health or AI features weaken the current app-owned source of truth for workouts, plans, suggestions, and goals.
- Ship in layers: foundation first, intelligence second, expansion surfaces third.
- A marquee feature can jump ahead of deeper foundation work when it uses existing infrastructure and unlocks strong marketing/conversion value.
- Pair announcement surfaces (What's New sheet, onboarding refresh, review prompt) with a marquee feature release so they earn their keep instead of shipping as standalone polish.
- Validate demand with a cheap mirror/ingest version of a new product area before investing in a device-generating version.

## Recently Shipped

- `SleepGoal` now exists as a date-ranged goal with one active goal at a time through app logic.
- The profile sheet/settings hub has been expanded.
- `FitnessLevel` has been added to `UserProfile` with required onboarding coverage and profile editing.
- A time-threshold fitness-level review cue now appears in profile surfaces (no auto-overwrite; user confirms changes).
- Terms of Service and Privacy Policy are now surfaced in the profile/settings structure.
- App theme is now user-configurable in settings.

## Current Extension Points

These existing pieces already give the roadmap a clean foundation:

- `UserProfile` plus onboarding routing
  - `Data/Models/UserProfile.swift`
  - `Data/Services/App/OnboardingManager.swift`
  - `Views/Onboarding/OnboardingView.swift`
  - `Views/Profile/FitnessLevelSelectionViews.swift`
- `TrainingGoal` history plus profile editing surfaces
  - `Data/Models/Training/TrainingGoal.swift`
  - `Views/Profile/ProfileSheetView.swift`
  - `Views/Profile/TrainingGoalSelectionViews.swift`
- Shared profile/settings entry point
  - `Views/Profile/*`
  - `Views/Settings/AppSettingsView.swift`
- Date-ranged goal patterns
  - `Data/Models/Health/StepsGoal.swift`
  - `Data/Models/Health/WeightGoal.swift`
  - `Data/Models/Health/SleepGoal.swift`
- Health sync, caches, and detail loaders
  - `Documentation/HEALTHKIT_INTEGRATION.md`
  - `Data/Services/HealthKit/Sync/*`
  - `Data/Models/Health/*`
- Training condition and split resolution
  - `Data/Models/Training/TrainingConditionPeriod.swift`
  - `Data/Services/Training/TrainingConditionStore.swift`
  - `Data/Services/Training/SplitScheduleResolver.swift`
- Suggestions and outcomes
  - `Documentation/SUGGESTION_AND_OUTCOME_FLOW.md`
  - `Data/Models/Suggestions/*`
  - `Data/Services/Suggestions/*`
- Existing Foundation Models hooks
  - `Data/Services/AI/Suggestions/AITrainingStyleClassifier.swift`
  - `Data/Services/AI/Outcomes/AIOutcomeInferrer.swift`
  - `Data/Services/AI/Shared/FoundationModelPrewarmer.swift`
- Health-tab and exercise/workout UX surfaces that can absorb new product work
  - `Views/Tabs/Health/HealthTabView.swift`
  - `Views/Workout/AddExerciseView.swift`
  - `Views/Exercise/ExerciseDetailView.swift`
  - `Views/Workout/WorkoutSummaryView.swift`
  - `Views/Workout/RestTimerView.swift`

## Product Decisions To Keep Stable

These decisions should guide the roadmap unless a future release proves they need to change.

- Training goal should be a date-ranged goal model, similar to `StepsGoal`.
  - It can influence suggestion style, generated plans, template-plan defaults, onboarding, and later personalization.
- Sleep goal should also be a date-ranged goal model.
  - It belongs with the other health goals, not as a loose setting.
- Desired wake-up time should start as a current preference, not a goal.
  - The app mostly cares about the active value.
  - If the app later uses it for historical reasoning, snapshot it at the moment it affects alerts, sleep debt, or coaching.
- Fitness level should stay profile-owned and user-confirmed, not fully autonomous.
  - Current shipped shape:
    - `fitnessLevel`
    - `fitnessLevelSetAt`
  - Current shipped review behavior:
    - time-threshold based move-up recommendation only
    - no auto-overwrite
    - no auto-downgrade
  - Candidate future extension:
    - add activity-quality gating before showing move-up prompts
- Manual sleep or steps input should stay deferred for now.
  - These conflict with the current Apple Health integration philosophy more than hydration or weight-style manual input does.
- Hydration is the better first manual metric.
  - It works as both HealthKit integration and app-owned entry.
- Core ML should come after richer feedback labels exist.
  - User outcome prompts, session overrides, and more contextual suggestion data should arrive before model personalization work.
- Monetization should follow feature proof, not lead it.
  - The app should first earn 2 to 3 obviously premium-worthy capabilities.
- Cardio should ship in two phases, not one.
  - Cardio v1 is HealthKit-mirror only. Reuse `HealthWorkout`, surface mirrored runs/walks/rides inside the Health tab, no new model, no GPS. This validates demand cheaply.
  - Cardio v2 is the full device-tracked experience with `CLLocationManager`, MapKit route rendering, `HKWorkoutSession` on iPhone, heart rate, splits, indoor cardio with manual treadmill correction, and a new app-owned `CardioSession` model.
  - The "Cardio" tab and the "Workout" → "Lifting" tab rename are v2 decisions. v1 lives as a section.
- Text-to-plan generation can pull ahead of deeper foundation work.
  - Foundation Models infrastructure already exists (`AITrainingStyleClassifier`, `AIOutcomeInferrer`, `FoundationModelPrewarmer`).
  - It is the most screenshot- and share-worthy way to prove the on-device AI claim the store listing now leads with.
  - Scope tight: template-plan generation first, split generation second, targeted split-day updates third. Defer chat/critique.
- Review prompt should trigger on clear success moments.
  - Best anchor is the first positive suggestion outcome or a completed goal.
  - Use app-side gating (ask once, offer "ask later") even though `SKStoreReviewController` already rate-limits to a few prompts per year.
  - Bundle with a richer announcement/education pass (`What's New`, refreshed onboarding, Getting Started, TipKit) rather than with notification plumbing.

## Backlog

### 1. Profile, Onboarding, and Goals

- Desired wake-up time
  - Start as a sleep preference, not a historical goal.
  - Use it for bedtime nudges, sleep debt messaging, and bedtime/wake charts.
- Fitness level
  - Extend from the current time-threshold cue into a richer review flow with explicit actions (`Move Up`, `Keep Current`, optional `Remind Later`).
  - Add activity-quality gating (for example recent completed-session thresholds) before showing move-up prompts.
  - Continue using user-confirmed updates only (no silent auto-overwrite).
- Profile and settings expansion
  - Continue extending the current profile sheet with fitness level and other profile-owned surfaces.
  - Keep app settings and profile editing separate, but continue using the shared entry point from both tabs.
- Settings and support expansion
  - Continue moving legal, support, and feedback actions into the new settings/profile structure.
  - Prioritize Request a Feature, Report a Bug, and a Getting Started surface.
- Improved onboarding
  - Add a proper feature-intro sequence before data-entry steps.
  - Fitness-level onboarding step is now shipped.
  - Continue onboarding additions only for new profile-owned setup that truly needs to block readiness.
- TipKit and product education
  - Best used for context menus, suggestion review, split behaviors, and other non-obvious UX.
- What's New and update surfaces
  - Add an "update available" prompt and a post-update feature sheet tied to app version tracking.
  - Pair this with a lightweight Getting Started or re-entry surface for users who want a refresher after onboarding.
- App review prompt
  - Best triggered by clear success moments such as a positive outcome, completed goal, or repeated healthy usage streak.

### 2. Health Expansion and Health Insights

- Expanded Health metrics
  - Heart rate
  - Resting heart rate
  - Heart rate variability
  - Walking heart rate average
  - Cardio recovery
  - Cardio fitness
  - Wrist temperature
  - Respiratory rate
  - Hydration
- Health trends
  - Trend summaries inspired by Apple Health.
  - Good fit for nightly or low-frequency recomputation, not every sync callback.
- Sleep timing insights
  - Average bedtime
  - Average wake time
  - Weekday sleep timing charts
  - Sleep debt or bedtime recommendation surfaces
- Hydration integration
  - Prefer both HealthKit sync and manual entries.
  - Good candidate for another app-owned health input like weight.
- Weight logging reminders and notification controls
  - Defer for now.
  - Do not prioritize a global app notifications toggle until there is a stronger product reason than simple settings completeness.
  - Revisit weight logging reminders later if retention data shows they would matter.
- Manual health inputs
  - Keep hydration as the first manual metric.
  - Defer manual sleep and manual steps until there is a stronger non-HealthKit strategy.
- Combined metric correlation views
  - Useful for weight, sleep, steps, resting heart rate, energy, and hydration.
  - Best added after the underlying new metrics exist.
- External health integrations
  - Garmin is the strongest candidate.
  - Whoop or other ecosystems can stay later.

### 3. Coaching, Suggestions, and Personalization

- Pre-workout context from health metrics
  - Use synced signals to prefill or suggest mood/context rather than replacing user input outright.
- User condition enrichment
  - Temperature and other health metrics can help suggest or confirm sick/recovery states.
- Session override system
  - Temporary workout modifications based on condition or pre-workout context.
  - Must stay separate from long-term plan edits.
- User outcome prompt
  - Surface the currently hidden user-feedback field.
  - Likely best in workout summary first, not per-set.
- Learning from good outcomes
  - Fold accepted-good outcomes into future suggestion ranking and confidence.
  - Weight accepted-good outcomes more than rejected-good outcomes.
- Full suggestion and outcome loop improvements
  - Better use of prior outcomes, user preference patterns, and condition context.
- Template learning from completed workouts
  - Explore a smart template system that can learn from what the user actually did the next time the template is reused.
  - Keep this separate from unresolved suggestion state so template catch-up for previously zero-target prescriptions is not forced through the current suggestion pipeline unless that ends up being the cleanest fit.
- Core ML personalization
  - Later phase once the app has better labels and more structured user feedback.
- Foundation Models expansion
  - Plan generation from text
  - Split generation from text
  - Add exercises from text
  - Text-to-plan flows
  - Plan or split critique/chat features
- Third-party AI
  - Consider only if on-device Foundation Models stop being enough for premium coaching features.

### 4. Workout, Split, and Exercise UX

- Split-aware add-exercise flow
  - Emphasize exercises that match the active split day's muscles.
  - This fits naturally into `AddExerciseView` because split day target muscles already exist.
- Search-mode navigation polish
  - Hide the quick-actions bar while searching exercises anywhere it competes with focused search UX.
- Smarter split completion handling
  - Detect when today's split workout already happened and reflect that in the Home split section, quick actions, and intents.
- Template plans for template splits
  - Template split creation should be able to suggest or attach starter plans.
- Post-workout plan update flow
  - Offer a way to update a plan from the workout that was just completed.
  - This should be deliberate and selective so the app does not silently overwrite long-term plan intent with one-off session adjustments.
- Improved exercise detail
  - How-to content
  - Exercise instructions
  - Muscle diagram
  - Better fusion of exercise detail and exercise history
- Muscle and training diagrams
  - Body map
  - Total volume by muscle
  - Total sets by muscle
  - Overall training distribution visuals
- Workout heatmap
  - Frequency and consistency visual.
- General training charts
  - Total workout time
  - Period comparisons
  - Volume or session comparisons across ranges
- Rest timer and set-rest improvements
  - Unify the current rest-timer and set-rest editing experience more cleanly.
  - Inline set-rest editing may be better than the current separate sheet-heavy flow.
- Different gym tracking
  - Needs a real model, likely gym profiles plus optional per-exercise or per-plan variance.
  - Avoid shipping this until the product clearly knows how it affects loads, exercise availability, and analytics.

### 5. New Surfaces and Business

- Shortcuts and system surfaces polish
  - Add any missing App Intents.
  - Wire donation coverage across all high-value actions and validate that surfaced suggestions stay aligned with the current navigation model.
- Cardio v1: HealthKit mirror only
  - Surface mirrored cardio `HealthWorkout` rows (runs, walks, rides from Watch, Strava, Nike Run Club, etc.) inside an existing surface.
  - No new persisted model, no GPS, no device tracking.
  - Ships as a Health tab section, not a new tab.
  - Purpose is to validate how often VillainArc users actually want cardio surfaced before committing to v2.
- Cardio v2: device-tracked
  - New app-owned `CardioSession` model parallel to `WorkoutSession`.
  - `CLLocationManager` + MapKit route rendering.
  - `HKWorkoutSession` on iPhone for live cardio.
  - Heart rate, pace, splits, HR zones.
  - Indoor cardio support with manual treadmill correction input.
  - At this point, add a dedicated Cardio tab and rename the current Workout tab to Lifting.
- More general workout tracking beyond strength
  - Especially useful for run-focused or hybrid users.
- Monetization
  - Start after premium feature clusters exist.
  - Likely premium candidates:
    - advanced AI generation or chat
    - deeper coaching and personalized interpretation
    - advanced health correlations and long-range insights
    - cardio expansion or external ecosystem integrations

## Suggested Release Order

This is the recommended shipping order based on current architecture, product leverage, and implementation risk. The order now assumes the immediate next release is the text-authoring push, followed by a screenshot/onboarding/education pass once fresh assets are ready.

### `1.2.x` — Current focus

Use the current build for dogfooding and asset capture before the next feature release.

- Daily app usage to capture real screenshots
- Identify the best product moments to turn into improved App Store creative
- Keep onboarding/image refresh scoped for the follow-up release once the new assets exist

### `1.3` — Marquee: Text authoring AI

The next release should be the first visible on-device AI authoring push.

- Template-plan generation from natural-language text (Foundation Models)
- Workout-split generation from natural-language text
- Keep the UX centered on creation, not mutation
- Targeted split-day updates stay in follow-on scope once create-from-text feels solid

Reason:

- Foundation Models infrastructure already exists, so this is more UX/prompt/integration work than a brand-new platform bet.
- It is the most screenshot-worthy feature currently available to back the AI positioning.
- It creates better raw material for the App Store refresh and onboarding refresh that should follow.

### `1.4` — Conversion + education pass

Use the assets and flows proven in `1.3` to improve conversion and re-entry surfaces.

- Improved App Store screenshots and creative direction
- Onboarding refresh that highlights the app's main product moments
- What's New sheet infrastructure shipped alongside this release
- Getting Started / refresher surface for returning users
- Review prompt triggered by the first positive suggestion outcome with an ask-later option and app-side gating
- TipKit passes for the newly emphasized flows and other non-obvious UX

Deliberately deferred from this release:

- Plan critique / chat-style features
- Third-party AI fallback
- Text-to-exercise additions inside an in-progress workout or plan
- Broad notification-settings work and weight reminders

Reason:

- The screenshot pass needs real assets first, so it should follow the feature release instead of leading it.
- Announcement surfaces (`What's New`, onboarding refresh, Getting Started, TipKit, review prompt) earn their keep here rather than shipping as disconnected polish.
- This is the right moment to improve both App Store conversion and returning-user comprehension.

### `1.5` — Health depth + Cardio v1

Broaden the Health tab and validate cardio demand cheaply.

- Expanded Health metrics: heart rate, resting heart rate, HRV, walking heart rate, cardio recovery, cardio fitness, wrist temperature, respiratory rate
- Hydration integration with HealthKit sync plus manual entries
- Sleep timing insights: average bedtime, average wake time, weekday sleep timing charts, sleep debt / bedtime recommendation surfaces
- Desired wake-up time as a sleep preference (not a historical goal)
- Health trends summaries
- First combined metric / correlation charts
- `Last synced at` visibility on Health models
- Cardio v1 — HealthKit mirror surface in the Health tab (no new model, no GPS)

Reason:

- Sync infrastructure for daily metric caches already exists; new metrics mostly add display and model work.
- Shipping Cardio v1 here lets the broader health expansion carry it without needing a dedicated cardio release.
- Creates the signal set that the next release will actually use.

### `1.6` — Coaching loop bundle

Close the suggestion/outcome loop with the richer signals now available.

- Pre-workout context suggestions prefilled from health metrics
- Session override system for temporary condition- or context-driven adjustments (kept separate from long-term plan mutation)
- User outcome prompt surfaced in workout summary
- Better suggestion learning from positive outcomes
- Weight accepted-good outcomes more than rejected-good outcomes
- More context-aware outcome evaluation

Reason:

- Health metrics from `1.5` feed directly into this work.
- Ships as one cohesive release because the pieces depend on each other.

### `1.7` — Workout and plan UX deepening

Daily-usability work after the intelligence layer is stronger.

- Smart templates that learn from what the user actually did next time the template is used (handles prior 0-target prescriptions via catch-up path)
- Post-workout plan update flow (deliberate, selective, does not silently overwrite long-term plan intent)
- Split-aware add-exercise flow
- Search-mode polish across exercise flows
- Template plans for template splits
- Improved exercise detail and how-to surfaces
- Muscle diagrams and total-volume-by-muscle views
- Workout heatmap
- Overall training charts (total time, period comparisons, range comparisons)
- Rest timer and set-rest UX redesign with more inline editing
- Keyboard quick actions across the app

### `1.8+` — Authoring and integrations

Harder or larger work best done after the earlier foundations are stable.

- Plan critique and assistant-style chat features on top of the text-to-plan base
- Text-based targeted updates to existing split day(s)
- Text-to-exercise inside active workouts
- Different gym tracking (needs a real model, likely gym profiles plus optional per-exercise or per-plan variance)
- Garmin integration
- More advanced correlation views
- Monthly and yearly workout analytics parity with sleep highlights
- Request Feature and Report Bug — deferred until there is a website backend to receive and triage submissions

### `2.0`

- Cardio v2 — device-tracked with new `CardioSession` model, `CLLocationManager`, MapKit routes, `HKWorkoutSession` on iPhone, heart rate, splits, and indoor cardio correction
- Rename the current Workout tab to Lifting and introduce a dedicated Cardio tab
- Broader workout tracking expansion beyond strength-first
- Premium packaging and monetization structure around the most differentiated coaching features

Reason:

- Cardio v2 is a real surface-area expansion, not an incremental sheet.
- By this point `1.5` should have answered whether users actually want cardio in VillainArc, so the v2 investment is justified or declined based on real data.

## Defer Until There Is A Better Product Reason

- Manual sleep entries
- Manual step entries
- Aggressive full auto-updating fitness level with no user confirmation
- Core ML personalization before richer user feedback and session-override labels exist
- Monetization before premium features feel essential
- Cardio v2 (device-tracked) before Cardio v1 (HealthKit mirror) has validated demand
- A dedicated Cardio tab and the Workout → Lifting rename before Cardio v2 is ready to ship
- Weight-log reminders until there is evidence they materially improve retention or goal adherence
- A global notifications toggle before there is a stronger product reason than simple settings completeness
- Request Feature and Report Bug until there is a website backend to receive and triage submissions

## Next Concrete Build Targets

If the roadmap is executed one feature cluster at a time, the cleanest next implementation sequence is:

1. Close out `1.2.x`: dogfood daily, capture the screenshots worth turning into stronger App Store creative, and note which product moments should be highlighted in onboarding.
2. `1.3` marquee: ship text-to-template-plan and text-to-split on top of existing Foundation Models infrastructure, keeping split-day mutation out of the first release.
3. `1.4` conversion/education pass: refresh onboarding, ship `What's New`, add Getting Started, add the review prompt, and layer in TipKit once the new assets and flows are ready.
4. `1.5` health expansion: add the expanded Health metrics set, hydration, sleep timing insights, desired wake-up time, Health trends, first correlation charts, `last synced at` on Health models, and Cardio v1 as a HealthKit-mirror section in the Health tab.
5. `1.6` coaching bundle: ship pre-workout context, session override, user outcome prompt, and learning-from-good-outcomes together because the pieces depend on each other.

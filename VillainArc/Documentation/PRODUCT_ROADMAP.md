# VillainArc Product Roadmap

Use the other files in this folder for current architecture and shipped behavior. Use this file when deciding what to build next, how to group work into releases, and which ideas should plug into existing systems versus become new systems.

## Planning Principles

- Prefer extending the current app architecture over introducing parallel systems.
- Keep date-ranged historical models for goals that can legitimately change over time.
- Keep one-off preferences separate from goals unless history is part of the product.
- Keep temporary session adaptation separate from long-term plan mutation.
- Do not let richer Health or AI features weaken the current app-owned source of truth for workouts, plans, suggestions, and goals.
- Ship in layers: foundation first, intelligence second, expansion surfaces third.

## Current Extension Points

These existing pieces already give the roadmap a clean foundation:

- `UserProfile` plus onboarding routing
  - `Data/Models/UserProfile.swift`
  - `Data/Services/App/OnboardingManager.swift`
  - `Views/Onboarding/OnboardingView.swift`
- Date-ranged goal patterns
  - `Data/Models/Health/StepsGoal.swift`
  - `Data/Models/Health/WeightGoal.swift`
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
- Fitness level should start as profile state with review metadata, not a fully autonomous model.
  - Recommended shape:
    - current level
    - source (`user`, `derived`, or `suggested`)
    - lastUpdatedAt
    - lastConfirmedAt
    - optional confidence or review-due flag
- Manual sleep or steps input should stay deferred for now.
  - These conflict with the current Apple Health integration philosophy more than hydration or weight-style manual input does.
- Hydration is the better first manual metric.
  - It works as both HealthKit integration and app-owned entry.
- Core ML should come after richer feedback labels exist.
  - User outcome prompts, session overrides, and more contextual suggestion data should arrive before model personalization work.
- Monetization should follow feature proof, not lead it.
  - The app should first earn 2 to 3 obviously premium-worthy capabilities.

## Backlog

### 1. Profile, Onboarding, and Goals

- Training goal
  - New date-ranged model similar to `StepsGoal`.
  - Influences suggestion style, onboarding defaults, template-plan selection, and later plan generation.
- Sleep goal
  - New date-ranged health goal with history and one active goal at a time through app logic.
- Desired wake-up time
  - Start as a sleep preference, not a historical goal.
  - Use it for bedtime nudges, sleep debt messaging, and bedtime/wake charts.
- Fitness level
  - Add to profile with a smart review flow rather than silent hard auto-overwrite.
  - Useful for onboarding, template plans, generation complexity, and suggestion tone.
- Profile hub
  - Replace the Health-tab gear button with a profile entry point.
  - Profile sheet can own profile fields, photo, training goal, sleep goal, fitness level, and a separate button into app settings.
- Improved onboarding
  - Add a proper feature-intro sequence before data-entry steps.
  - Add onboarding steps for training goal, sleep goal, wake time, and fitness level where appropriate.
- TipKit and product education
  - Best used for context menus, suggestion review, split behaviors, and other non-obvious UX.
- What's New and update surfaces
  - Add an "update available" prompt and a post-update feature sheet tied to app version tracking.
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
- Core ML personalization
  - Later phase once the app has better labels and more structured user feedback.
- Foundation Models expansion
  - Plan generation from text
  - Split generation from text
  - Enum selection or parsing from text
  - Add exercises from text
  - Text-to-plan flows
  - Plan or split critique/chat features
- Third-party AI
  - Consider only if on-device Foundation Models stop being enough for premium coaching features.

### 4. Workout, Split, and Exercise UX

- Split-aware add-exercise flow
  - Emphasize exercises that match the active split day's muscles.
  - This fits naturally into `AddExerciseView` because split day target muscles already exist.
- Smarter split completion handling
  - Detect when today's split workout already happened and reflect that in the Home split section, quick actions, and intents.
- Template plans for template splits
  - Template split creation should be able to suggest or attach starter plans.
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

- Cardio tab
  - Strong standalone product area.
  - Should support both outdoor and indoor cardio.
  - Outdoor work benefits from map and route support.
  - Indoor cardio may need manual treadmill correction input.
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

This is the recommended shipping order based on current architecture, product leverage, and implementation risk.

### `1.2`

Keep `1.2` focused on extending existing patterns rather than opening brand-new product areas.

- Profile hub replacing the simple Health settings button
- Training goal
- Sleep goal
- Desired wake-up time
- Fitness level
- Onboarding refresh for the new profile and goal fields
- Optional:
  - What's New sheet
  - lightweight review prompt
  - small rest-timer UX cleanup if it fits the release

Reason:

- This extends current onboarding, goal, and profile patterns cleanly.
- It creates the personalization foundation that later plan generation and coaching features will need.

### `1.3`

- Expanded health metrics foundation
- Wrist temperature and respiratory rate first because they help condition context directly
- Resting heart rate, HRV, and cardio fitness family after that
- Sleep timing insights
- Health trends
- Hydration integration
- First combined metric comparisons

Reason:

- This deepens the Health tab without forcing immediate suggestion-system changes.
- It creates better signals before health-driven coaching ships.

### `1.4`

- Pre-workout context suggestions from health metrics
- Session override system
- User outcome prompt
- Better suggestion learning from positive outcomes
- More context-aware suggestion and outcome evaluation

Reason:

- By this point the app will have better health signals and more user context.
- This is the best time to tighten the closed loop instead of adding intelligence too early.

### `1.5`

- Split-aware add-exercise flow
- Template plans for template splits
- Improved exercise detail and how-to surfaces
- Muscle diagrams
- Workout heatmap
- Overall training charts
- Rest timer and set-rest UX redesign

Reason:

- These features improve daily usability and make the app feel richer without forcing a new major navigation model.

### `1.6+`

- Foundation Models authoring features
- Text-to-plan and text-to-split
- Plan critique and assistant-style features
- Different gym tracking
- Garmin or other non-Health integrations
- More advanced correlation views

Reason:

- These features are powerful but easier to scope once the profile, health, and coaching foundations are stable.

### `2.0`

- Cardio tab
- Broader workout tracking expansion beyond strength-first
- Premium packaging and monetization structure around the most differentiated coaching features

Reason:

- Cardio is a real surface-area expansion, not just another card or sheet.
- It changes the product shape enough to justify a major release if the feature set is deep enough.

## Defer Until There Is A Better Product Reason

- Manual sleep entries
- Manual step entries
- Aggressive full auto-updating fitness level with no user confirmation
- Core ML personalization before richer user feedback and session-override labels exist
- Monetization before premium features feel essential

## Next Concrete Build Targets

If the roadmap is executed one feature cluster at a time, the cleanest next implementation sequence is:

1. Add a profile hub and move app settings behind it.
2. Add `TrainingGoal` and `SleepGoal` using the current goal-history pattern.
3. Add desired wake-up time plus onboarding/profile editing support.
4. Add fitness level with review metadata.
5. Refresh onboarding to introduce the new profile and goal structure.


# App Intents Coverage Audit

This is the map of VillainArc's App Intents surface: every meaningful user action and
data view, and the intent that exposes it. The goal is full observability and control
through App Intents so the app is drivable by Shortcuts, Siri, Spotlight, and — as Apple
ships native MCP support for App Intents (iOS/macOS 26.1 betas, App Intents 2.0) — by any
MCP-ready assistant.

## How intents are wired

- All modern App Intents live under `VillainArc/Intents/`. That folder is owned by the
  `VillainArc` (main app) file-system-synchronized group, so every `.swift` file there
  compiles into the main app automatically — new intent files need no `project.pbxproj`
  edit.
- The `VillainArcIntentsExtension` target is the **legacy SiriKit `INExtension`** (its own
  `VillainArcIntentsExtension/` folder: `IntentHandler`, `StartWorkoutSiriHandler`,
  `CancelWorkoutSiriHandler`, `EndWorkoutSiriHandler`). It does not compile the modern App
  Intents and is unrelated to adding new ones.
- The widget extension compiles a curated allowlist of main-app files (the `FD93E60D`
  exception set in `project.pbxproj`). Only add an intent file there if the widget itself
  references the type. The Health intents are not referenced by the widget, so they ship in
  the main app only.
- **App Intents are uncapped.** Only `VillainArcShortcuts` (`AppShortcutsProvider`) is
  capped — at **10** voice-prioritized `AppShortcut` slots (currently full). New intents are
  added as plain intents (available in the Shortcuts app and to assistants) without
  consuming a voice slot.

## Conventions in this codebase

- **Data reads** that answer conversationally: `static let supportedModes: IntentModes =
  .background`, `nonisolated func perform() async throws -> some IntentResult &
  ProvidesDialog`, reading a fresh `makeHealthIntentReadContext()` (Health) or the shared
  container. Gate with `SetupGuard.requireReady(context:)`.
- **Data exports**: no Health JSON export intent currently ships. If a large structured
  export returns later, use `IntentFile` instead of a large `String` payload so Shortcuts
  can hand the file to a Save File action reliably.
- **Mutations**: `.background` (silent) or `.foreground(.dynamic)` when they open UI;
  `@MainActor func perform()` using `SharedModelContainer.container.mainContext`, then
  `saveContext` + the relevant `HealthMetricWidgetReloader` reload.
- **Navigation**: `.foreground` / `.foreground(.dynamic)`, routing through `AppRouter` /
  `HealthNavigationIntentSupport`.
- **Execution targets (iOS 27)**: every state-writing intent (starts, finishes, cancels,
  deletes, creates, adds, toggles, goal/condition mutations, rest-timer controls) is pinned to
  the main app process via `static var allowedExecutionTargets: IntentExecutionTargets { .main }`,
  declared per-intent in `Intents/IntentExecutionPolicies.swift` (gated `@available(iOS 27.0, *)`).
  Writes never run in an extension or remote target. `AppIntentExecutionPolicyTests` asserts the
  full list stays `.main`. Pure data-read and navigation intents are unrestricted.

---

## Coverage map

Legend: ✅ existing · ⬜ intentionally omitted or deferred (reason inline).

### Workout session

| Action / view | Intent |
|---|---|
| Start an empty workout | ✅ `StartWorkoutIntent` |
| Start today's split workout | ✅ `StartTodaysWorkoutIntent` |
| Start a workout from a plan | ✅ `StartWorkoutWithPlanIntent` |
| Complete the next set | ✅ `CompleteActiveSetIntent` (+ `LiveActivityCompleteSetIntent`) |
| Finish the workout | ✅ `FinishWorkoutIntent` |
| Cancel/discard the workout | ✅ `CancelWorkoutIntent` |
| Open active workout | ✅ `OpenActiveWorkoutIntent` |
| Open a specific past workout | ✅ `OpenWorkoutIntent` |
| Open pre-workout context | ✅ `OpenPreWorkoutContextIntent` |
| Open active workout's settings | ✅ `OpenWorkoutSettingsIntent` |
| Open the rest timer | ✅ `OpenRestTimerIntent` |
| Save a workout as a plan | ✅ `SaveWorkoutAsPlanIntent` |
| Show workout history | ✅ `ShowWorkoutHistoryIntent` |
| View last completed workout | ✅ `ViewLastWorkoutIntent` |
| Spoken last-workout recap | ✅ `LastWorkoutSummaryIntent` |
| Delete a workout | ✅ `DeleteWorkoutIntent` |
| Delete all workouts | ✅ `DeleteAllWorkoutsIntent` |
| Reference a workout by name | ✅ `WorkoutSessionEntity` (+ query) |

### Exercise

| Action / view | Intent |
|---|---|
| Add an exercise | ✅ `AddExerciseIntent` (+ `LiveActivityAddExerciseIntent` from the live workout Live Activity) |
| Add multiple exercises | ✅ `AddExercisesIntent` |
| Replace the current exercise | ✅ `ReplaceExerciseIntent` |
| Open an exercise (progress/history) | ✅ `OpenExerciseIntent` |
| Open the exercises list | ✅ `OpenExercisesIntent` |
| Show an exercise's performance history | ✅ `ShowExerciseHistoryIntent` |
| Toggle exercise favorite | ✅ `ToggleExerciseFavoriteIntent` |
| View last used exercise | ✅ `ViewLastUsedExerciseIntent` |
| Reference an exercise by name | ✅ `ExerciseEntity` (+ query) |

### Workout plan

| Action / view | Intent |
|---|---|
| Create a plan | ✅ `CreateWorkoutPlanIntent` |
| Edit a plan | ✅ `EditWorkoutPlanIntent` |
| Open a plan | ✅ `OpenWorkoutPlanIntent` |
| Open active plan flow | ✅ `OpenActiveWorkoutPlanIntent` |
| Show all plans | ✅ `ShowWorkoutPlansIntent` |
| Toggle plan favorite | ✅ `ToggleWorkoutPlanFavoriteIntent` |
| View last used plan | ✅ `ViewLastWorkoutPlanIntent` |
| Delete a plan | ✅ `DeleteWorkoutPlanIntent` |
| Delete all plans | ✅ `DeleteAllWorkoutPlansIntent` |
| Review a plan's suggested changes | ✅ `OpenSuggestionReviewIntent` (routes to the plan and opens the review sheet through `AppRouter.pendingSuggestionReviewPlanID`) |
| Reference a plan by name | ✅ `WorkoutPlanEntity` (+ query) |

### Workout split

| Action / view | Intent |
|---|---|
| Create a split | ✅ `CreateWorkoutSplitIntent` |
| Activate a split | ✅ `ActivateWorkoutSplitIntent` (exclusive — every other split goes inactive in the same write, through `WorkoutSplitActivation`) |
| Delete a split | ✅ `DeleteWorkoutSplitIntent` (allowed on the active split, as the split screen allows it; the confirmation says what deleting it costs) |
| Manage/open splits | ✅ `ManageWorkoutSplitsIntent`, `OpenWorkoutSplitIntent` |
| Open today's plan from the split | ✅ `OpenTodaysPlanIntent` |
| Start today's split workout | ✅ `StartTodaysWorkoutIntent` |
| Spoken "what am I training" | ✅ `TrainingSummaryIntent` |
| Reference a split by name | ✅ `WorkoutSplitEntity` (+ query) |

### Cardio

| Action / view | Intent |
|---|---|
| Start a cardio session (run/walk, outdoor/treadmill) | ✅ `StartCardioSessionIntent` |
| Open active cardio session | ✅ `OpenActiveCardioSessionIntent` |
| Show cardio history + routes | ✅ `ShowCardioHistoryIntent` |
| Finish / cancel cardio session | ✅ `FinishCardioSessionIntent`, `CancelCardioSessionIntent` (`.background`; call `AppRouter.finishCardioSession` / `cancelCardioSession`) |
| Open a specific past cardio session | ✅ `OpenCardioSessionIntent` |
| Delete a completed cardio session | ✅ `DeleteCardioSessionIntent`, beside the options menu on whichever screen shows the session — `CardioSessionDetailView` for a route session, `HealthWorkoutDetailView` for a mirrored indoor one. Both run `AppRouter.deleteCompletedCardioSession` behind a confirmation, so Siri and the screen destroy the same thing the same way. The workouts list keeps its swipe disabled on cardio rows (`deleteDisabled(item.session == nil)`), where a swipe would offer to remove a row whose Health mirror it cannot touch. |
| Reference a cardio session by name | ✅ `CardioSessionEntity` (+ query, Spotlight-indexed on finish) |

### Rest timer

| Action / view | Intent |
|---|---|
| Start a rest timer | ✅ `StartRestTimerIntent` (+ `RestTimerSnippetIntent`) |
| Stop / pause / resume | ✅ `StopRestTimerIntent`, `PauseRestTimerIntent`, `ResumeRestTimerIntent` |
| Single control entry point | ✅ `RestTimerControlIntent` |
| Live Activity controls | ✅ `LiveActivityPauseRestTimerIntent`, `LiveActivityResumeRestTimerIntent` |

### Health — spoken data reads (`ProvidesDialog`)

| Metric | Today | Specific day |
|---|---|---|
| Day summary | ✅ `GetHealthDaySummaryIntent` | ✅ `GetHealthDaySummaryForDayIntent` |
| Any metric (weight/sleep/steps/distance/calories) | ✅ `GetHealthMetricIntent` | ✅ `GetHealthMetricForDayIntent` |
| Weight | ✅ `GetWeightIntent`, `GetLatestWeightIntent` | (via `GetHealthMetricForDay`) |
| Sleep | ✅ `GetSleepIntent` | (via `GetHealthMetricForDay`) |
| Steps | ✅ `GetStepsIntent` | (via `GetHealthMetricForDay`) |
| Distance | ✅ `GetDistanceIntent` | (via `GetHealthMetricForDay`) |
| Calories (total/active/resting) | ✅ `GetCaloriesBurnedIntent`, `GetActiveCaloriesIntent`, `GetRestingCaloriesIntent` | (via `GetHealthMetricForDay`) |
| **Heart vitals** (resting/range/walking/HRV) | ✅ `GetHeartRateIntent` | ✅ `GetHeartRateForDayIntent` |
| **Respiratory rate** | ✅ `GetRespiratoryRateIntent` | ✅ `GetRespiratoryRateForDayIntent` |
| **Wrist temperature** | ✅ `GetWristTemperatureIntent` | ✅ `GetWristTemperatureForDayIntent` |
| **Hydration** (water intake) | ✅ `GetHydrationIntent` | ✅ `GetHydrationForDayIntent` |
| Training condition | ✅ `GetTrainingConditionIntent` | — |

### Health — goal status reads

| Goal | Intent |
|---|---|
| Steps goal status | ✅ `GetStepsGoalStatusIntent` |
| Weight goal status | ✅ `GetWeightGoalStatusIntent` |
| **Sleep goal status** | ✅ `GetSleepGoalStatusIntent` |
| **Hydration goal status** | ✅ `GetHydrationGoalStatusIntent` |

### Health — structured data export

| Export | Intent |
|---|---|
| Day / range / all Health JSON export | ⬜ omitted from 1.3; Jarvis health tracking is manual, so the release ships no Health JSON export surface |

### Health — mutations

| Action | Intent |
|---|---|
| Log a weight entry | ✅ `AddWeightEntryIntent` |
| Create/replace weight goal | ✅ `CreateWeightGoalIntent` |
| Create/replace steps goal | ✅ `CreateStepsGoalIntent` |
| Create/replace sleep goal | ✅ `CreateSleepGoalIntent` |
| Update / end training condition | ✅ `UpdateTrainingConditionIntent`, `EndTrainingConditionIntent` |
| **Log a hydration entry** | ✅ `AddHydrationEntryIntent` |
| **Create/replace hydration goal** | ✅ `CreateHydrationGoalIntent` |

### Health — navigation (`.foreground`)

| Destination | Intent |
|---|---|
| Weight history / all entries / weight-goal history | ✅ `ShowWeightHistoryIntent`, `ShowAllWeightEntriesIntent`, `ShowWeightGoalHistoryIntent` |
| Steps history / steps-goal history | ✅ `ShowStepsHistoryIntent`, `ShowStepsGoalHistoryIntent` |
| Sleep history / sleep-goal history | ✅ `ShowSleepHistoryIntent`, `ShowSleepGoalHistoryIntent` |
| Calories history | ✅ `ShowCaloriesBurnedHistoryIntent` |
| Health Trends / Sleep Insights / Correlation Insights | ✅ `ShowHealthTrendsIntent`, `ShowSleepInsightsIntent`, `ShowCorrelationInsightsIntent` |
| Training condition history | ✅ `OpenTrainingConditionHistoryIntent` |
| Heart history / resting heart / walking heart / HRV history | ✅ `ShowHeartRateHistoryIntent`, `ShowRestingHeartRateHistoryIntent`, `ShowWalkingHeartRateHistoryIntent`, `ShowHeartRateVariabilityHistoryIntent` |
| Respiratory / wrist-temp history screens | ✅ `ShowRespiratoryRateHistoryIntent`, `ShowWristTemperatureHistoryIntent` |
| Hydration history / hydration-goal history | ✅ `ShowHydrationHistoryIntent`, `ShowHydrationGoalHistoryIntent` |

### App, profile, settings

| Action | Intent |
|---|---|
| Open the app | ✅ `OpenAppIntent` |
| Open profile | ✅ `OpenProfileIntent` |
| Open settings | ✅ `OpenSettingsIntent` |
| Open workout preferences / Health / notifications / units settings | ✅ `OpenWorkoutPreferencesIntent`, `OpenAppleHealthSettingsIntent`, `OpenNotificationSettingsIntent`, `OpenUnitSettingsIntent` |
| Restore purchases / view subscription / paywall | ⬜ intentionally omitted — purchase/subscription flows must run in foreground StoreKit UI and aren't a fit for Siri/MCP automation |

## Intentional omissions and follow-ups

**Health JSON export.** Day, range, and full-history JSON export intents are intentionally
absent. Add them only when there is a product need for a user-facing export or assistant
sync path, and include nutrition/workout/cardio history deliberately instead of shipping a
partial dump by accident. Use `IntentFile` for that surface, not a large returned string.

**Ask Villain Arc (not an App Intent).** The conversational assistant
(`AskVillainArcAssistant` + `AskVillainArcView`) answers natural-language questions over the
user's indexed data through the iOS 27 `SpotlightSearchTool`, scoped to the app's own
CoreSpotlight index. It is read-only by construction (the Spotlight tool conforms to `SafeTool`
and is vetted read-only; see `AIToolSafety.swift`) and complements — does not replace — the
intent surface above: actions and writes still flow through the intents, the assistant only
reads and explains. It is gated behind iOS 27 + Apple Intelligence, with a History/Trends
fallback.

---

## Voice slots (`VillainArcShortcuts`, 10/10 — full)

Start Today's Workout · Training Summary · Complete Set · Add Exercise · Start Timer ·
Today's Summary · Last Night's Sleep · Today's Steps · Today's Calories · Stop Timer.

Everything else is reachable as a Shortcuts-app action or by an assistant. Displacing a
voice slot is a deliberate trade — only do it when a new phrase clearly out-earns one above.

The split, cardio and suggestion-review verbs deliberately take no slot. Activating a split and
reviewing a plan's suggestions happen occasionally and from a screen the user is already on; the
two deletes are rare and destructive, which is the worst thing to hand a misheard phrase. All ten
slots above are either mid-workout (hands busy, the case voice exists for) or a daily read.

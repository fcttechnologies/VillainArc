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
- **Data exports** that return structured values: `.background` mode, `nonisolated`
  `perform()` returning `some IntentResult & ReturnsValue<String>`.
- **Mutations**: `.background` (silent) or `.foreground(.dynamic)` when they open UI;
  `@MainActor func perform()` using `SharedModelContainer.container.mainContext`, then
  `saveContext` + the relevant `HealthMetricWidgetReloader` reload.
- **Navigation**: `.foreground` / `.foreground(.dynamic)`, routing through `AppRouter` /
  `HealthNavigationIntentSupport`.

---

## Coverage map

Legend: ✅ existing · 🆕 added in build 12 · ⬜ intentionally omitted (reason inline).

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
| Add an exercise | ✅ `AddExerciseIntent` |
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
| Reference a plan by name | ✅ `WorkoutPlanEntity` (+ query) |

### Workout split

| Action / view | Intent |
|---|---|
| Create a split | ✅ `CreateWorkoutSplitIntent` |
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
| Finish / cancel cardio session | ⬜ no intent — cardio finish/cancel is in-session UI only; mirror of the workout finish/cancel intents is a possible follow-up |

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
| **Heart vitals** (resting/range/walking/HRV) | 🆕 `GetHeartRateIntent` | ⬜ follow-up: day-parameterized variant |
| **Respiratory rate** | 🆕 `GetRespiratoryRateIntent` | ⬜ follow-up |
| **Wrist temperature** | 🆕 `GetWristTemperatureIntent` | ⬜ follow-up |
| **Hydration** (water intake) | 🆕 `GetHydrationIntent` | ⬜ follow-up |
| Training condition | ✅ `GetTrainingConditionIntent` | — |

### Health — goal status reads

| Goal | Intent |
|---|---|
| Steps goal status | ✅ `GetStepsGoalStatusIntent` |
| Weight goal status | ✅ `GetWeightGoalStatusIntent` |
| **Sleep goal status** | 🆕 `GetSleepGoalStatusIntent` |
| **Hydration goal status** | 🆕 `GetHydrationGoalStatusIntent` |

### Health — structured data export (`ReturnsValue<String>`, JSON)

| Export | Intent |
|---|---|
| One day → JSON object | 🆕 `ExportHealthDayJSONIntent` (date optional; defaults to today) |
| Date range → JSON array (one per day) | 🆕 `ExportHealthRangeJSONIntent` |
| Full tracked history → JSON | 🆕 `ExportAllHealthJSONIntent` |

Shared shapes/encoder/builders live in `HealthExportSupport.swift`. These read VA's **own
local store** (not a live HealthKit read), so a Shortcut can run an export intent and "Save
File" the result (e.g. to iCloud Drive) for an external sync. See the JSON schema below.

### Health — mutations

| Action | Intent |
|---|---|
| Log a weight entry | ✅ `AddWeightEntryIntent` |
| Create/replace weight goal | ✅ `CreateWeightGoalIntent` |
| Create/replace steps goal | ✅ `CreateStepsGoalIntent` |
| Create/replace sleep goal | ✅ `CreateSleepGoalIntent` |
| Update / end training condition | ✅ `UpdateTrainingConditionIntent`, `EndTrainingConditionIntent` |
| **Log a hydration entry** | ⬜ follow-up (see below) |
| **Create/replace hydration goal** | ⬜ follow-up (see below) |

### Health — navigation (`.foreground`)

| Destination | Intent |
|---|---|
| Weight history / all entries / weight-goal history | ✅ `ShowWeightHistoryIntent`, `ShowAllWeightEntriesIntent`, `ShowWeightGoalHistoryIntent` |
| Steps history / steps-goal history | ✅ `ShowStepsHistoryIntent`, `ShowStepsGoalHistoryIntent` |
| Sleep history / sleep-goal history | ✅ `ShowSleepHistoryIntent`, `ShowSleepGoalHistoryIntent` |
| Calories history | ✅ `ShowCaloriesBurnedHistoryIntent` |
| Health Trends / Sleep Insights / Correlation Insights | ✅ `ShowHealthTrendsIntent`, `ShowSleepInsightsIntent`, `ShowCorrelationInsightsIntent` |
| Training condition history | ✅ `OpenTrainingConditionHistoryIntent` |
| Heart / respiratory / wrist-temp / hydration history screens | ⬜ follow-up: nav intents into those Health-tab detail screens |

### App, profile, settings

| Action | Intent |
|---|---|
| Open the app | ✅ `OpenAppIntent` |
| Open profile | ✅ `OpenProfileIntent` |
| Open settings | ✅ `OpenSettingsIntent` |
| Open workout preferences / Health / notifications / units settings | ✅ `OpenWorkoutPreferencesIntent`, `OpenAppleHealthSettingsIntent`, `OpenNotificationSettingsIntent`, `OpenUnitSettingsIntent` |
| Restore purchases / view subscription / paywall | ⬜ intentionally omitted — purchase/subscription flows must run in foreground StoreKit UI and aren't a fit for Siri/MCP automation |

---

## Health export JSON schema

All values are **raw / canonical**; the consumer converts to display units. Dates are
ISO8601 (UTC). Optional fields are omitted-as-null when unavailable.

**Day record** (`ExportHealthDayJSONIntent` → object, `ExportHealthRangeJSONIntent` → array of these):

```json
{
  "date": "2026-06-07T05:00:00Z",
  "weightKg": 84.1,
  "sleepSeconds": 27000,
  "steps": 8423,
  "distanceMeters": 6210.4,
  "activeEnergyKcal": 540,
  "restingEnergyKcal": 1680
}
```

**Full export** (`ExportAllHealthJSONIntent`): an object with `exportedAt` plus one array per
store — `weightEntries` (`date`, `weightKg`), `sleepNights` (`date`, `timeAsleepSeconds`,
`timeInBedSeconds`, `remSeconds`, `coreSeconds`, `deepSeconds`, `awakeSeconds`,
`sleepStart`, `sleepEnd`), `stepsDistanceDays` (`date`, `steps`, `distanceMeters`),
`energyDays` (`date`, `activeEnergyKcal`, `restingEnergyKcal`), `heartDays` (`date`,
`restingHeartRate`, `minHeartRate`, `maxHeartRate`, `walkingHeartRateAverage`,
`heartRateVariabilitySDNN`), `respiratoryRateDays` (`date`, `minRate`, `maxRate`),
`wristTemperatureDays` (`date`, `temperatureCelsius`), `hydrationDays` (`date`,
`totalVolumeML`, `goalTargetML`).

Units: weight kg, durations seconds, distance meters, energy kcal, heart rate bpm, HRV ms,
respiratory rate breaths/min, temperature °C, water mL.

---

## Intentional omissions and follow-ups

**Known gap — nutrition / dietary intake.** VA's `HealthDaySnapshot` and stores do **not**
include dietary calories or protein (Bevel logs these into HealthKit, but VA doesn't read
or cache them). The export intents therefore can't include nutrition. To close this:
extend `loadHealthDaySnapshot` / the stores to read HealthKit dietary types, then add the
fields to the export schema. Tracked as a clear follow-up; deliberately not blocked on.

**Deferred (write paths with side effects).** `AddHydrationEntryIntent` and
`CreateHydrationGoalIntent` are real gaps (weight has both; the goal-creation trio covers
steps/weight/sleep but not hydration). They were deferred from build 12 because logging
hydration must replicate the full export/`HydrationDay.reconcile`/widget-reload/goal-
completion-notification flow correctly, and that side-effect surface is higher risk than
additive reads on a shipping build. Add them by mirroring `AddWeightEntryIntent` (entry +
export + reload) and `CreateStepsGoalIntent` (active-goal end/replace), plus
`HydrationDay.reconcile(for:context:)` and the hydration widget reload.

**Deferred (workouts/cardio in the full export).** `ExportAllHealthJSONIntent` covers the
per-day Health caches and the weight log. Workout/cardio session history is relationship-
heavy (sets, performances, route points) and is intentionally left out of the JSON dump;
`LastWorkoutSummaryIntent` / `ViewLastWorkoutIntent` already expose recent workouts.

**Deferred (day-parameterized metric reads + nav).** The four new metric reads
(heart/respiratory/wrist-temp/hydration) are today-only and have no Show* navigation
intent into their Health-tab detail screens. Both are natural follow-ups; the export
intents already give an assistant arbitrary-date access to all of this data.

---

## Voice slots (`VillainArcShortcuts`, 10/10 — full)

Start Today's Workout · Training Summary · Complete Set · Add Exercise · Start Timer ·
Today's Summary · Last Night's Sleep · Today's Steps · Today's Calories · Stop Timer.

Everything else is reachable as a Shortcuts-app action or by an assistant. Displacing a
voice slot is a deliberate trade — only do it when a new phrase clearly out-earns one above.

# HealthKit Integration

This document explains VillainArc’s Apple Health integration: what the app reads and writes, how sync works, how local Health caches are modeled, how Health-backed goals and notifications fit in, and where the platform boundaries still matter.

## Main Files

- `Data/Services/HealthKit/Authorization/HealthAuthorizationManager.swift`
- `Data/Models/Health/HealthKitCatalog.swift`
- `Data/Models/Health/HealthSleepBlock.swift`
- `Data/Models/Health/HealthSleepNight.swift`
- `Data/Services/HealthKit/HealthMirrorSupport.swift`
- `Data/Services/HealthKit/Live/HealthLiveWorkoutSessionCoordinator.swift`
- `Data/Services/HealthKit/Sync/HealthPreferences.swift`
- `Data/Services/HealthKit/Sync/HealthDailyMetricsSync.swift`
- `Data/Services/HealthKit/Sync/HealthSleepSync.swift`
- `Data/Services/HealthKit/Sync/StepsGoalEvaluator.swift`
- `Data/Services/HealthKit/Sync/StepsCoachingEvaluator.swift`
- `Data/Services/HealthKit/Detail/HealthIntradayMetricsLoader.swift`
- `Data/Services/HealthKit/Detail/HealthSleepHistoryLoader.swift`
- `Data/Services/HealthKit/Export/HealthExportCoordinator.swift`
- `Data/Services/HealthKit/Sync/HealthSyncCoordinator.swift`
- `Data/Services/HealthKit/Sync/HealthStoreUpdateCoordinator.swift`
- `Data/Services/App/HealthMetricWidgetReloader.swift`
- `Data/Services/HealthKit/Detail/HealthWorkoutDetailLoader.swift`
- `Data/Services/App/NotificationCoordinator.swift`
- `Data/Services/App/WeeklyHealthCoachingCoordinator.swift`
- `Views/Components/Overlays/ToastManager.swift`
- `Views/Health/Sleep/SleepHistoryView.swift`
- `Intents/Health/*`
- `Root/VillainArcApp.swift`
- `Root/RootView.swift`

## Core Model Split

VillainArc treats Apple Health as an integration layer, not the app’s main source of truth.

### App-Owned Models

- `WorkoutSession`
  - the app’s real workout record
- `WeightEntry`
  - the app’s local weight history record, optionally linked to HealthKit
- `WeightGoal`
  - local weight-goal history
- `StepsGoal`
  - local steps-goal history

### Health Mirror / Cache Models

- `HealthWorkout`
  - mirrored Apple Health workout summary
- `HealthSleepBlock`
  - persisted per-block sleep detail cache for a wake day
- `HealthSleepNight`
  - one-row-per-wake-day sleep rollup cache backed by persisted sleep blocks
- `HealthStepsDistance`
  - per-day steps and walking/running distance cache
- `HealthEnergy`
  - per-day active/resting energy cache
- `HealthSyncState`
  - synced-coverage record for the daily metric caches plus notification dedupe state for steps coaching, sleep goals, and weekly coaching

That split keeps HealthKit from owning the app’s training logic while still letting the app reuse Health data everywhere it makes sense.

## What the App Requests

### Writes

- workouts
- workout effort score
- active energy burned
- resting energy burned
- body mass

### Reads

- workouts and workout routes
- sleep analysis
- date of birth
- biological sex
- height
- body mass
- step count
- walking/running distance
- heart rate
- active energy burned
- resting energy burned
- respiratory rate
- flights climbed
- additional workout-related quantity types used in the workout-detail loader

## Permission Flow

VillainArc can request Health access:

- during new-user onboarding
- during a returning-user standalone Health prompt if the current Health permissions version still needs a request
- later from Settings

The app uses both HealthKit request status and an app-defined handled version.

The prompt rule is:

- `HealthKitCatalog.permissionsCatalogVersion` represents the current read/write permission catalog
- the app stores the last handled permissions version in shared defaults
- onboarding or the standalone launch gate prompt only when:
  - the current permissions version differs from the stored handled version
  - and `statusForAuthorizationRequest(toShare:read:)` still reports `.shouldRequest`
- tapping `Connect to Apple Health` or `Not Now` marks the current permissions version as handled
- merely presenting the blocking screen does not update the stored handled version

Settings remains separate from that handled-version logic:

- if HealthKit still needs a real request, Settings offers `Connect Apple Health`
- if a request was already made, Settings sends the user to the Health access settings flow instead of reusing the onboarding gate

Important nuance:

- write authorization state is directly visible through `authorizationStatus(for:)`
- read availability is less explicit, so sync logic uses conservative anchor-advance rules rather than assuming every empty query result means reads are fully available

## Health Intents and Quick Actions

VillainArc exposes a health-specific App Intents layer that reuses the same local data model as the Health tab.

The split is:

- read-only health intents
  - use fresh read-only `ModelContext`s
  - answer from local app-owned records and Health mirror caches such as `WeightEntry`, `HealthSleepNight`, `HealthStepsDistance`, and `HealthEnergy`
- foreground health intents
  - route through `AppRouter`
  - open the same Health destinations and sheets the foreground Health tab uses

The home-screen `Add Weight Entry` quick action is handled the same way:

- it waits until the app is ready
- routes into the Health tab
- presents the same add-weight sheet used by the tab UI

Intent-donation policy for this surface:

- donations are emitted by foreground app UI actions
- widget and Live Activity intent paths do not emit donations

## Observer and Background Delivery Design

### Observer Installation

Observers are installed from the app delegate on process launch through `HealthStoreUpdateCoordinator.installObserversIfNeeded()`.

That means:

- observers are recreated on normal launches
- observers are recreated on HealthKit background relaunches

### Observer Recovery

If an observer callback fails with HealthKit authorization-state errors such as:

- `errorAuthorizationNotDetermined`
- `errorAuthorizationDenied`

the app clears the stored observer reference for that type. A later ready/settings pass can then reinstall it.

### Background Delivery

Background delivery is enabled for Health types after the relevant request boundary has been crossed.

The app refreshes background delivery registration:

- after onboarding reaches ready
- when returning from Health settings flows

### Platform Boundary

Observer-driven background sync is best-effort. It can be prompt, delayed, or skipped depending on system conditions. That is why the app still needs a strong foreground recovery path via the ready/settings sync pass.

## Live Workout Path

### `.exportOnFinish`

The iPhone-owned live workout path uses `HealthLiveWorkoutSessionCoordinator` to start or recover:

- an `HKWorkoutSession`
- an `HKLiveWorkoutBuilder`

That path:

- starts when the local workout is actively logging
- stores the local `WorkoutSession.id` in Health metadata
- ends when local logging moves to summary
- tries to link the finished `HKWorkout` back into the local `HealthWorkout` mirror immediately

## Export and Reconciliation

### Workouts

Workout export is a repair and reconciliation path.

The normal order is:

1. sync Health workouts first
2. try to relink a matching Health workout by metadata
3. only fall back to exporting a new one if no matching Health workout exists

That minimizes duplicates and keeps the app aligned with the live-workout path.

### Weight Entries

Weight export follows the same idea:

1. look for an existing Health sample linked by the local `WeightEntry.id`
2. relink if found
3. only save a new `.bodyMass` sample when needed

## Health Sync Flow

`HealthStoreUpdateCoordinator.syncNow()` runs:

1. `HealthSyncCoordinator.syncAll()`
2. `HealthExportCoordinator.reconcilePendingExports()`

That order matters. Sync happens first so already-saved Health data can relink before fallback export tries to create anything.

The app-ready path in `RootView` calls `HealthMetricWidgetReloader.reloadAllHealthMetrics()` after `syncNow()`. Settings-triggered Health syncs use `syncNow()` directly and rely on targeted reloads from the sync paths plus widget timeline cadence.

### Workout and Weight Sync

`HealthSyncCoordinator` owns:

- workout sync
- weight sync
- top-level sequencing of sleep and daily-metric sync passes

Those paths:

- use anchored queries
- write through background `ModelContext`s
- use rerun-on-burst behavior instead of dropping overlapping observer callbacks
- only advance anchors when the query result or an allowed foreground probe provides enough evidence that reads are truly progressing
- keep observer/background sync focused primarily on persisted data updates, with targeted widget reloads only where the current sync paths explicitly dispatch them

### Daily Metric Sync

`HealthDailyMetricsSync` owns:

- steps
- walking/running distance
- active energy
- resting energy

The daily-metric design is:

- anchored queries act as change detectors
- the changed samples are collapsed into affected days
- the app reruns daily cumulative statistics queries for the affected range
- one per-day cache row is updated per day, not one row per raw sample
- intraday detail for steps, distance, and energy is not persisted as a second cache model
- instead, the history views can load same-day hourly detail on demand through `HealthIntradayMetricsLoader`

The metrics are coalesced into two sync families:

- movement: steps + walking/running distance
- energy: active + resting energy

That reduces redundant work when related Health types update together.

Widget reload behavior for these metrics follows user-driven changes, such as steps-goal edits, and the app-ready full reload after `syncNow()`. The daily steps, distance, and energy sync paths do not directly reload widgets after observer updates. Walking/running distance still has no dedicated widget.

### Sleep Sync

`HealthSleepSync` owns:

- sleep-analysis change detection
- wake-day summary rebuilds
- sleep anchor advancement
- synced wake-day coverage

The sleep design is:

- one cached `HealthSleepNight` row per wake day
- one persisted `HealthSleepBlock` row per reconstructed block for that wake day
- `HealthSleepNight` stores the primary overnight window, the all-block span, rolled-up asleep/in-bed/awake totals, stage totals, nap total, and current availability in HealthKit
- anchored queries detect additions and deletions on `sleepAnalysis`
- the anchored result is only a change detector
- added or edited samples rebuild a padded wake-day range
- the rebuild fetches overlapping raw sleep samples for that range
- merged sleep blocks are reconstructed first, then assigned to wake day by the block end date using HealthKit timezone metadata when available
- the primary overnight block is selected per wake day, while stored night totals roll up across all same-day sleep blocks
- non-primary same-day sleep becomes `napDuration`
- deletions still rebuild the broader known synced range because deleted objects do not carry the old sample timestamps
- raw per-stage intervals still stay in HealthKit for on-demand stage detail loading

Sleep cache rebuilds run in background sync. When `HealthSleepSync` rebuilds persisted sleep summaries, it dispatches a targeted sleep-widget reload. Sleep widgets also self-correct through timeline cadence and the app-ready full reload after `syncNow()`.

## Anchor Advancement Guard

The app does not blindly advance HealthKit anchors when a result is ambiguous.

The current rule is:

- daily quantity metrics and sleep:
  - additions or deletions advance the anchor
  - empty results can use a lightweight one-sample probe
- workouts and body mass:
  - clearly external additions advance the anchor immediately
  - deletions advance only when the local mirrored record proves the deleted sample was externally sourced
  - empty results and app-owned-only changes stay ambiguous on observer-driven syncs
  - the heavier workout/body-mass read probe runs only on the full foreground/manual sync path

This protects against moving anchors forward while Health reads may still be limited to VillainArc-written data only.

## Health Goals and Notifications

### Weight Goals

`WeightGoal` is purely local app state.

The app keeps one active weight goal at a time through app logic by ending/replacing the previous active goal when a new one is created. Goal completion can present a dedicated full-screen route through `AppRouter`.

### Steps Goals

`StepsGoal` is also purely local app state.

Important conventions:

- it is date-ranged by whole calendar day
- the app keeps one active steps goal at a time through app logic
- replacing a same-day goal deletes the same-day active goal and inserts the new one
- replacing an older active goal ends it on the previous day and inserts the new goal for today

`HealthStepsDistance` stores:

- today’s step count
- today’s goal target
- whether the goal has been completed for that day

`StepsGoalEvaluator` updates those fields whenever:

- daily step sync changes the day’s total
- the current steps goal is changed

### Notification Behavior

Steps goal and coaching events are resolved from the daily step-sync path and delivered through `NotificationCoordinator`.

The steps behavior is:

- the app always attempts to show an in-app toast for a resolved steps event
- local notification scheduling is gated by `AppSettings.stepsNotificationMode`
- `.off`
  - no local steps notification is scheduled
- `.goalOnly`
  - only the real goal-complete transition can schedule a local notification
  - `2x`, `3x`, and `new best` state is still tracked silently
- `.coaching`
  - local notifications can use the richer coaching events:
    - goal complete
    - double goal
    - triple goal
    - new best
    - combined milestone plus new best

The steps-coaching dedupe state lives in `HealthSyncState`:

- `doubleGoalLastTriggeredDay`
- `tripleGoalLastTriggeredDay`
- `bestDailyStepsKnown`
- `newHighStepsLastTriggeredDay`

Important rules:

- the app updates those fields regardless of notification mode
- `3x` also stamps the `2x` day so the lower milestone cannot fire later
- if a sync pass detects both a goal milestone and a new best, one combined event is produced
- goal changes silently reconcile today’s coaching state without scheduling a notification
- initial step import, deletion rebuilds, and nil recovery recompute the historical best daily steps while excluding today

Sleep goal notifications are resolved from `HealthSleepSync` through `SleepGoalEvaluator`:

- the app always attempts to show an in-app toast for a resolved sleep-goal event
- local notification scheduling is gated by `AppSettings.sleepNotificationMode`
- `.off`
  - no local sleep-goal notification is scheduled
- `.goalOnly`
  - sleep-goal completion can schedule a local notification
- `.coaching`
  - sleep-goal completion can schedule a local notification
  - weekly coaching recaps can include sleep averages

Weekly coaching recaps are scheduled and delivered through `WeeklyHealthCoachingCoordinator`:

- the app registers a `BGAppRefreshTask` at launch using `com.villainarc.health.weeklyCoaching`
- `Info.plist` declares that identifier in `BGTaskSchedulerPermittedIdentifiers`
- `UIBackgroundModes` includes `fetch`
- foreground code only schedules or cancels the background refresh request
- foreground code does not compute or deliver weekly coaching recaps
- scheduling is refreshed after onboarding reaches ready, after notification permission/settings changes, and when the notification settings view becomes active
- if both steps and sleep notification modes are not `.coaching`, the pending background task is canceled
- otherwise any existing pending request for the weekly task is replaced with a new request for the next future Sunday at noon
- scheduling does not preflight the current Background App Refresh setting; iOS decides whether and when the submitted refresh task can actually run
- if the user opens the app or changes modes after a missed Sunday noon task, the app schedules the next future Sunday instead of calculating a catch-up recap in the foreground
- if iOS launches the background task late, the task still evaluates the most recently completed Sunday-Saturday report week
- the task reschedules the next Sunday refresh before doing the recap work
- the task requires at least three cached entries for each enabled metric before including that metric:
  - `HealthStepsDistance` rows for steps
  - `HealthSleepNight` wake-day rows for sleep
- if both enabled metrics qualify, one combined notification is scheduled
- if only one enabled metric qualifies, the notification includes only that metric
- if no enabled metric has enough cached entries, no notification is scheduled and the week is not marked delivered
- weekly recaps do not show in-app toasts
- weekly recap dedupe uses `HealthSyncState.weeklyCoachingLastDeliveredWeekStart`
- debug console output logs background task registration, system launches, skipped scheduling prerequisites, successful scheduling with the earliest begin date, submit failures, completion, and expiration

Rest timer notifications use the same notification coordinator and foreground-toast behavior.

Important limitation:

- steps notifications still depend on the app actually receiving the Health update in time
- if the Health observer wake is delayed until foreground, the event is also delayed until foreground
- weekly coaching recaps depend on iOS launching the scheduled background refresh task; missed tasks are not replayed by foreground catch-up logic

## Health Widgets

Health widgets use a hybrid refresh model.

The current design is:

- widget timelines refresh every 30 minutes (`.after`)
- user-driven edits still trigger targeted widget reloads (for example weight entry/goal changes, steps goal changes, and unit changes that affect widget rendering)
- the app-ready path runs `syncNow()` and then reloads every Health widget
- weight and sleep sync paths dispatch targeted widget reloads when they persist relevant changes
- daily movement and energy observer sync paths focus on data persistence and do not directly dispatch widget reloads

That means the widgets can update quickly on direct user edits, stay aligned after manual full sync, and still self-correct on timeline cadence if background observer timing is delayed.

## Removed Data and Retention

When Apple Health deletes a workout, body-mass sample, or all backing samples for a cached sleep night, the app can either:

- retain the local record but mark it unavailable in HealthKit
- or delete it from local storage

That is controlled by `AppSettings.keepRemovedHealthData`.

## History and Detail Surfaces

### Sleep Summary and History

The sleep surface stays summary-first at the card level.

That means:

- the section card reads cached `HealthSleepNight` rows only
- the card does not run a raw HealthKit detail query on open
- retained-but-no-longer-available nights can stay visible in cached summary form

The dedicated `SleepHistoryView` splits into range-specific detail modes:

- `day`
  - loads live HealthKit stage intervals for the selected wake day through `HealthSleepHistoryLoader`
  - renders the stage timeline from raw HealthKit intervals
- `week` and `month`
  - use cached `HealthSleepNight` plus persisted `HealthSleepBlock` data
  - render one cached block bar per stored sleep block so naps and other same-day sleep remain visually separate
- `6M`, `year`, and `all`
  - stay summary-backed from `HealthSleepNight`
  - render grouped windows and rolled-up totals instead of block-level detail

The sleep history surface includes:

- weekday average sleep chart
- monthly and yearly sleep highlights

Current boundary:

- raw stage intervals are still not persisted locally
- the history day view loads them from HealthKit on demand
- persisted sleep blocks provide the local fallback/detail layer when raw stages are unavailable
- broader grouped sleep history remains cache-backed from nightly rollups

### Weight, Steps, and Energy Day Views

The non-sleep history views expose a `day` range.

- weight:
  - day detail is fully local
  - hourly points are derived from persisted `WeightEntry` rows
- steps and distance:
  - broader ranges still read from cached `HealthStepsDistance`
  - `day` uses `HealthIntradayMetricsLoader` to query hourly Apple Health movement totals for the selected/latest day
- energy:
  - broader ranges still read from cached `HealthEnergy`
  - `day` uses `HealthIntradayMetricsLoader` to query hourly active and resting energy totals for the selected/latest day

Important boundary:

- only the `day` views for steps/distance and energy use live intraday HealthKit reads
- broader ranges stay cache-backed
- the intraday loader warms the latest day during the same history-view cache build so the `day` range is usually already ready or partially ready when selected

Those same cache-backed rows are also what the read-only health intents summarize, so the Health tab and the spoken/shortcut answers stay aligned.

### Workout History

`WorkoutsListView` merges:

- visible completed `WorkoutSession`s
- mirrored `HealthWorkout`s

It only shows a `HealthWorkout` row when that Health workout is not already represented by a visible linked `WorkoutSession`.

### Health Workout Detail

`HealthWorkoutDetailLoader` starts from the cached `HealthWorkout` summary and then tries to load richer live HealthKit detail on demand.

That means:

- the cached summary is always the fast baseline
- route/heart-rate/split detail is loaded only when the user opens workout detail
- retained-but-no-longer-available Health workouts still have a useful cached-only detail mode

# HealthKit Integration

This document explains VillainArc’s Apple Health integration: what the app reads and writes, how sync works, how local Health caches are modeled, how Health-backed goals and notifications fit in, and where the platform boundaries still matter.

## Main Files

- `Data/Services/HealthKit/Authorization/HealthAuthorizationManager.swift`
- `Data/Models/Health/HealthKitCatalog.swift`
- `Data/Models/Health/HealthSleepNight.swift`
- `Data/Services/HealthKit/HealthMirrorSupport.swift`
- `Data/Services/HealthKit/Live/HealthLiveWorkoutSessionCoordinator.swift`
- `Data/Services/HealthKit/Sync/HealthPreferences.swift`
- `Data/Services/HealthKit/Sync/HealthDailyMetricsSync.swift`
- `Data/Services/HealthKit/Sync/HealthSleepSync.swift`
- `Data/Services/HealthKit/Sync/StepsGoalEvaluator.swift`
- `Data/Services/HealthKit/Export/HealthExportCoordinator.swift`
- `Data/Services/HealthKit/Sync/HealthSyncCoordinator.swift`
- `Data/Services/HealthKit/Sync/HealthStoreUpdateCoordinator.swift`
- `Data/Services/HealthKit/Detail/HealthWorkoutDetailLoader.swift`
- `Data/Services/App/NotificationCoordinator.swift`
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
- `HealthSleepNight`
  - one-row-per-wake-day sleep summary cache
- `HealthStepsDistance`
  - per-day steps and walking/running distance cache
- `HealthEnergy`
  - per-day active/resting energy cache
- `HealthSyncState`
  - synced-coverage record for the daily metric caches

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
- during a returning-user standalone Health prompt if the current type set still needs a request
- later from Settings

The app relies on HealthKit’s authorization-request status instead of keeping its own “already prompted” flag.

Important nuance:

- write authorization state is directly visible through `authorizationStatus(for:)`
- read availability is less explicit, so sync logic uses conservative anchor-advance rules rather than assuming every empty query result means reads are fully available

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

Observer-driven background sync is best-effort. It can be prompt, delayed, or skipped depending on system conditions. That is why the app also has a strong foreground recovery path via the ready/settings sync pass.

## Live Workout Path

During a live workout, `HealthLiveWorkoutSessionCoordinator` can start or recover:

- an `HKWorkoutSession`
- an `HKLiveWorkoutBuilder`

That live path:

- starts when the local workout is actively logging
- stores the local `WorkoutSession.id` in Health metadata
- ends when local logging moves to summary
- tries to link the finished `HKWorkout` back into the local `HealthWorkout` mirror immediately

This keeps the Apple Health workout closely tied to the app’s live workout runtime.

## Export and Reconciliation

### Workouts

Workout export is mostly a repair path now.

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

The metrics are coalesced into two sync families:

- movement: steps + walking/running distance
- energy: active + resting energy

That reduces redundant work when related Health types update together.

### Sleep Sync

`HealthSleepSync` owns:

- sleep-analysis change detection
- wake-day summary rebuilds
- sleep anchor advancement
- synced wake-day coverage

The sleep design is:

- one cached `HealthSleepNight` row per wake day
- each row stores the overnight window, asleep/in-bed/awake totals, stage totals, nap total, and current availability in HealthKit
- anchored queries detect additions and deletions on `sleepAnalysis`
- changed samples collapse into affected wake days
- the affected wake-day range is rebuilt from raw category samples
- the primary overnight block is selected per wake day and other same-day sleep becomes `napDuration`
- raw stage and interval detail stays in HealthKit for later detail loading

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

Steps-goal notifications are local notifications scheduled through `NotificationCoordinator`.

The behavior is:

- if notification delivery is allowed and the app observes the goal transition in time, schedule a local notification
- if the app is active when the notification arrives, the notification delegate shows a toast instead of a system banner
- if notifications are unavailable or disabled for that mode, fall back to a toast only when the app is active

Rest timer notifications use the same coordinator and the same foreground-toast behavior.

Important limitation:

- goal-completion notifications depend on the app actually getting a Health update in time
- if the Health observer wake is delayed until foreground, the notification will also be delayed until foreground

## Removed Data and Retention

When Apple Health deletes a workout, body-mass sample, or all backing samples for a cached sleep night, the app can either:

- retain the local record but mark it unavailable in HealthKit
- or delete it from local storage

That is controlled by `AppSettings.keepRemovedHealthData`.

## History and Detail Surfaces

### Sleep Summary

The Health tab’s sleep surface is summary-first.

That means:

- the section card reads cached `HealthSleepNight` rows only
- the card does not run a raw HealthKit detail query on open
- retained-but-no-longer-available nights can stay visible in cached summary form
- detailed sleep stages, awake fragments, naps, and sleeping heart-rate range are still a later detail surface

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

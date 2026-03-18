# HealthKit Integration

This document explains the HealthKit side of the app: how VillainArc requests Apple Health access over time, how workout export and workout sync work together, how Health workouts appear in history, how the detail screen loads richer metrics, and what happens when workouts disappear from Apple Health.

## Main Files

- `Data/Services/HealthKit/HealthAuthorizationManager.swift`
- `Data/Services/HealthKit/HealthPreferences.swift`
- `Data/Services/HealthKit/HealthExportCoordinator.swift`
- `Data/Services/HealthKit/HealthWorkoutSyncCoordinator.swift`
- `Data/Services/HealthKit/HealthWorkoutDetailLoader.swift`
- `Data/Models/Health/HealthWorkout.swift`
- `Data/Models/Sessions/WorkoutSession.swift`
- `Views/History/WorkoutsListView.swift`
- `Views/Workout/HealthWorkoutDetailView.swift`

## Core Idea

VillainArc treats Apple Health as an integration layer, not the main source of truth for workouts.

The split is:
- `WorkoutSession` is the app-owned workout record
- `HealthWorkout` is the Apple Health mirror/cache record

That means:
- VillainArc-specific workout behavior stays on `WorkoutSession`
- Apple Health workout identity and cached Health summary data stay on `HealthWorkout`
- richer Health details are loaded on demand instead of being copied into SwiftData

## The Two Workout Records

### `WorkoutSession`

`WorkoutSession` owns:
- exercises and sets
- notes and title
- plan links
- suggestion history
- pre and post workout context
- hidden state for app-side deletion

It is still the record the app learns from and builds suggestions from.

### `HealthWorkout`

`HealthWorkout` is the persisted Apple Health mirror. It stores:
- the HealthKit workout UUID
- an optional linked `WorkoutSession`
- start and end time
- duration
- activity type
- total energy burned
- total distance
- source name
- whether the workout still exists in HealthKit
- the last sync timestamp

It is intentionally a summary/cache layer. It does not store heart-rate chart points, route points, or other richer Health detail samples.

## Health Permission Flow

Health permission is optional and never blocks app readiness.

VillainArc can offer Apple Health access:
- during onboarding after bootstrap and profile setup are complete
- later from settings

### Smart Permission Prompting

VillainArc does not use a simple "already asked once" flag anymore.

Instead, it stores a permission prompt version in shared defaults.

That means:
- if the app has never shown the current Health permission version, onboarding can offer the Health step
- once the user handles that step, the current version is recorded
- if the app later changes the Health read or write scope and bumps the version, onboarding can offer the Health step again

This lets the Health prompt evolve with the app.

So the rule is:
- same Health scope: do not re-offer just because the app relaunched
- expanded Health scope: offer again once for the new version

### Why That Matters

HealthKit itself may show the Apple Health sheet again when an app requests new data types it did not request before.

VillainArc's prompt-version system is the app-side companion to that behavior:
- it avoids re-showing the same onboarding step forever
- but it still lets the app surface the Health step again when the permission set grows

Settings remains the manual override path. Even if onboarding already handled the current version, settings can still ask HealthKit for the current permission set.

## What the App Requests

VillainArc writes:
- workouts

VillainArc reads:
- workouts
- workout routes
- heart rate
- active energy burned
- respiratory rate
- flights climbed
- distance types used by common workout categories
- swim stroke count
- running metrics
- cycling metrics
- HealthKit effort-related workout metrics

The important design rule is:
- `HealthWorkout` stays small
- broader Health reads exist to enrich the detail screen, not to keep expanding the persisted model

## Export Flow

Apple Health export happens after a workout is truly completed.

The main sequence is:
1. the user finishes summary for a `WorkoutSession`
2. the session is finalized as a completed app workout
3. VillainArc attempts Apple Health export if authorization exists and no linked `HealthWorkout` already exists
4. if HealthKit saves successfully, the app inserts a linked `HealthWorkout`

So export is:
- post-completion
- idempotent through the linked `HealthWorkout`
- separate from live workout logging

## Reconciliation Flow

Export can fail at the moment a workout finishes, or the user may connect Apple Health later.

To cover that, VillainArc has a reconciliation pass for completed sessions that still have no Health link.

That pass:
- fetches completed sessions that still need export
- retries Apple Health export for each eligible session

This is what lets the app repair older completed workouts after Health access changes.

## Sync Flow

VillainArc also mirrors Apple Health workouts into local `HealthWorkout` rows.

### When Sync Runs

Once onboarding reaches `.ready`, the app runs a Health post-ready pass:
1. reconcile missing exports from completed app workouts
2. sync Apple Health workouts into the local mirror

That order matters.

The app retries missing exports first so a just-repaired VillainArc workout can already exist in Health before the sync pass starts importing and updating Health workouts.

### How Sync Works

VillainArc uses an anchored workout query for HealthKit workouts.

The anchor is stored in shared defaults, not SwiftData.

That gives the app this behavior:
- first sync with no anchor: backfill all matching workouts
- later syncs: only fetch changes since the last successful sync

The sync pass then:
- upserts returned `HKWorkout`s into `HealthWorkout`
- looks up rows by HealthKit workout UUID
- updates existing rows when found
- inserts new rows when missing

## Deletions From Apple Health

When Apple Health deletes a workout, VillainArc handles it in two stages:

1. sync marks that `HealthWorkout` as no longer available in HealthKit
2. the retention setting decides whether the local mirror should remain or be deleted

That keeps the decision separate:
- HealthKit tells the app the workout disappeared
- the app setting decides whether VillainArc should retain the cached record

### Retention Setting Behavior

VillainArc has a retention setting for removed Apple Health workouts.

When that setting is on:
- the app keeps the `HealthWorkout`
- `isAvailableInHealthKit` becomes `false`
- the workout still appears in VillainArc history as a cached record
- the detail screen falls back to cached summary only

When that setting is off:
- workouts removed from Apple Health are also removed from the local `HealthWorkout` mirror
- stale retained rows are cleaned up when the setting is turned off

So the user can choose between:
- strict mirroring of Apple Health
- keeping VillainArc as a retained historical copy of removed Health workouts

## Merged History Flow

Workout history is now a merged list, not a `WorkoutSession`-only list.

The list combines:
- visible completed `WorkoutSession`s
- `HealthWorkout`s from Apple Health

The merge rule is:
- always show visible app workouts
- only show a `HealthWorkout` row when it is not already represented by a visible linked `WorkoutSession`

That prevents duplicates for exported VillainArc workouts while still letting imported or retained Apple Health workouts appear in the same history surface.

The result is:
- app-owned workouts behave like normal VillainArc history
- Health-only workouts behave as read-only Health rows

## Health Workout Detail Flow

Health workout detail is loaded on demand.

The app does not keep expanding `HealthWorkout` just to support richer screens.

### Loader Behavior

The detail loader starts from the cached `HealthWorkout`, then decides whether it can load live HealthKit details.

The sequence is:
1. use the cached `HealthWorkout` summary as the baseline
2. if the row is already marked unavailable in HealthKit, stay in cached-summary mode
3. otherwise fetch the real `HKWorkout` by the stored HealthKit UUID
4. if that workout still exists, load richer HealthKit data from it
5. if it no longer exists, fall back to cached summary only

So the loader does two different checks:
- does the Health workout still exist at all
- if it does, which richer metrics actually exist for this workout

### What the Detail Screen Shows

The Health detail screen always starts with cached/live summary data like:
- duration
- calories
- distance
- source

Then it conditionally adds richer sections when the live workout provides data:
- heart-rate stats
- interactive heart-rate chart
- richer metric cards from workout statistics
- per-activity breakdowns when the workout contains multiple activities

The key rule is:
- the workout detail screen is modular
- if a metric is missing, that section simply does not appear

## Heart-Rate Detail

Heart rate is the main richer detail layer right now.

The detail loader:
- reads workout heart-rate statistics for average, minimum, and maximum
- queries heart-rate samples associated with that workout
- downsamples them for chart rendering

The chart is interactive, using the same kind of selection pattern as the exercise detail charts:
- horizontal selection
- nearest-point snapping
- selected point callout

## Cached-Only Detail Behavior

If a Health workout is retained locally but no longer exists in Apple Health:
- the detail screen still opens
- cached summary values still render
- richer live Health sections do not render

That is how retained removed workouts stay useful without pretending the live Health workout still exists.

## Distance and Duration Formatting

Two display helpers now matter for Health workout UI:

- distance uses `AppSettings.distanceUnit`
- workout-style durations can use `secondsToTimeWithHours(_:)` so longer workouts render as `H:MM:SS`

That keeps Health workout display consistent with the rest of the app's unit model.

## Current Direction

The current HealthKit architecture is designed to support both:
- workout-centric Health features now
- a broader Health tab later for things like steps, sleep, weight, and total calories

The important rule is that the app now has a reusable pattern:
- request Health access intentionally
- keep a small persisted mirror for list/history use
- load richer Health details on demand
- let retention rules control whether removed Health data should remain visible in VillainArc

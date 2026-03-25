# HealthKit Integration

This document explains the current Apple Health integration in VillainArc: how Health access is requested over time, how workout and body-mass data are exported and synced, how the new Health tab gets its weight data, how Health workouts appear in history, how workout detail loads richer metrics, and what happens when Health data disappears from Apple Health.

## Main Files

- `Data/Services/HealthKit/HealthAuthorizationManager.swift`
- `Data/Services/HealthKit/HealthLiveWorkoutSessionCoordinator.swift`
- `Data/Services/HealthKit/HealthPreferences.swift`
- `Data/Services/HealthKit/HealthExportCoordinator.swift`
- `Data/Services/HealthKit/HealthSyncCoordinator.swift`
- `Data/Services/HealthKit/HealthStoreUpdateCoordinator.swift`
- `Data/Services/HealthKit/HealthWorkoutDetailLoader.swift`
- `Data/Models/Health/HealthWorkout.swift`
- `Data/Models/Health/WeightEntry.swift`
- `Data/Models/Sessions/WorkoutSession.swift`
- `Views/Health/HealthTabView.swift`
- `Views/History/WorkoutsListView.swift`
- `Views/Workout/HealthWorkoutDetailView.swift`
- `Views/AppSettingsView.swift`

## Core Idea

VillainArc treats Apple Health as an integration layer, not the main source of truth for the app.

The current split is:
- workouts use an app-owned `WorkoutSession` plus a mirrored `HealthWorkout`
- weight uses a single local `WeightEntry` row that can be created locally, imported from Apple Health, or linked to both

That means:
- VillainArc-specific workout behavior stays on `WorkoutSession`
- Apple Health workout identity and cached workout summary data stay on `HealthWorkout`
- body-mass samples use `WeightEntry` as the local persistence layer for both app-entered and Health-synced weight history
- richer workout Health details are loaded on demand instead of being copied into SwiftData

## Health Records

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

`HealthWorkout` is the persisted Apple Health workout mirror. It stores:
- the HealthKit workout UUID
- an optional linked `WorkoutSession`
- start and end time
- duration
- activity type
- active energy burned
- resting energy burned
- total distance
- source name
- whether the workout still exists in HealthKit

It is intentionally a summary/cache layer. It does not store heart-rate chart points, route points, or other richer workout detail samples.

### `WeightEntry`

`WeightEntry` is the local body-mass record. It stores:
- the measurement date
- weight in kilograms
- whether the entry has been exported to Apple Health
- the linked Apple Health sample UUID when available
- whether the linked sample still exists in HealthKit

This model serves three cases:
- a purely local entry that has not been exported yet
- a locally created entry that has been linked to Apple Health
- a Health-only body-mass sample imported into the app

That is why body-mass sync does not use a separate mirror model the way workouts do.

## Health Permission Flow

Health permission is optional and never blocks app readiness.

VillainArc can offer Apple Health access:
- during onboarding after bootstrap and the first profile step
- after changes to the app's Health read/write type set
- later from settings

### When the Prompt Appears

VillainArc uses `authorizationAction()` directly to decide whether to offer Health access.

`authorizationAction()` calls `healthStore.statusForAuthorizationRequest(toShare:read:)`:
- `.shouldRequest` → returns `.requestAccess` → offer the Health step
- `.unnecessary` or `.unknown` → onboarding skips the step, and settings becomes the manual path

This means:
- if the user has already gone through the system dialog for the current type set, VillainArc does not need its own prompt-version flag
- if new read or write types are added later, HealthKit can return `.shouldRequest` again and the prompt surfaces automatically

The standalone returning-user sheet shows only "Connect to Apple Health". There is no skip button there. That ensures `requestAuthorization()` is actually called so HealthKit can mark the current type set as handled.

Settings remains the manual override path regardless of what onboarding has handled. When the settings screen becomes active again, VillainArc refreshes authorization state, background delivery registration, and a sync pass.

## What the App Requests

VillainArc writes:
- workouts
- workout effort scores
- active energy burned
- resting energy burned
- body mass

VillainArc reads:
- workouts
- workout routes
- date of birth (for onboarding prefill)
- biological sex (mapped into the app's gender field during onboarding prefill)
- height (for onboarding prefill)
- body mass
- heart rate
- active energy burned
- resting energy burned
- respiratory rate
- flights climbed
- distance types used by common workout categories
- swim stroke count
- running metrics
- cycling metrics
- HealthKit effort-related workout metrics

The important design rules are:
- `HealthWorkout` stays small
- `WeightEntry` stays a lightweight local history record
- richer workout reads exist to support workout detail screens, not to keep inflating the persisted workout mirror

The important runtime rules are:
- live workout collection requires workout write authorization
- workout export and workout reconciliation require workout write authorization
- weight export and weight reconciliation require body-mass write authorization
- sync can still mirror workouts or body-mass samples after the corresponding request boundary has been crossed, even if the user denied some optional write types

## Live Workout Flow

VillainArc starts Apple Health workout collection while a local workout is actively being logged.

The main sequence is:
1. a `WorkoutSession` enters `.active`
2. if workout write authorization exists, `HealthLiveWorkoutSessionCoordinator` starts an `HKWorkoutSession` and `HKLiveWorkoutBuilder`
3. the builder saves metadata including the local `WorkoutSession.id`
4. if HealthKit provides live samples, the builder can collect heart rate and energy-related workout data during the session
5. when the local workout leaves active logging and moves to `.summary`, the coordinator stops the HealthKit session, ends collection, and finishes the workout
6. if HealthKit returns the saved `HKWorkout`, the app inserts or updates a linked `HealthWorkout` immediately

So the primary workout HealthKit path is:
- live during the `.active` workout phase
- finalized when active logging ends, not when summary is dismissed
- linked through Health metadata plus the saved workout UUID
- able to reattach to an already-running HealthKit session when the app resumes an active workout

## Workout Export and Reconciliation

The old post-completion export path still exists, but it is now a repair path.

That fallback is used only when:
- a completed app workout still has `hasBeenExportedToHealth == false`
- no matching Apple Health workout can be found by the stored `WorkoutSession.id` metadata

So workout export is now:
- reconciliation-only
- a repair path for older workouts, authorization changes, or save failures near the end of active logging

The workout reconciliation pass:
- looks for an already-saved Apple Health workout whose metadata contains the local `WorkoutSession.id`
- relinks that Health workout back to the local session when found
- falls back to the older export path only when no matching HealthKit workout exists

## Weight Export and Reconciliation

`HealthExportCoordinator` also owns the body-mass export path for `WeightEntry`.

The weight export sequence is:
1. only consider entries where `hasBeenExportedToHealth == false` and `healthSampleUUID == nil`
2. first query Apple Health for an existing body-mass sample whose metadata contains the local `WeightEntry.id`
3. if found, relink the local row to that sample instead of creating a duplicate
4. otherwise save a new `HKQuantitySample` for `.bodyMass`
5. upsert the local `WeightEntry` with the linked sample UUID and availability state

So weight export is also:
- reconciliation-aware
- metadata-linked
- safe to rerun after temporary save failures or after Health access is granted later

This matters because `WeightEntry` is the single local record. The export path tries hard to relink first so the app does not create duplicate weight rows when the Health sample already exists.

## Sync Flow

VillainArc mirrors both Apple Health workouts and Apple Health body-mass samples into local SwiftData.

### When Sync Runs

Once onboarding reaches `.ready`, the app runs a Health post-ready pass:
1. register observer queries
2. refresh background delivery for workouts and body mass
3. run `syncNow()`

`syncNow()` then does two phases:
1. `HealthSyncCoordinator.shared.syncAll()` syncs workouts first, then weight entries
2. `HealthExportCoordinator.shared.reconcilePendingExports()` reconciles completed workouts, then weight entries that still need export

That order matters.

The app syncs first so already-saved Health data can be relinked before fallback export tries to recreate anything.

The same sequence also runs when the settings screen becomes active after the user returns from changing Health access.

### Background Updates

`HealthStoreUpdateCoordinator` registers:
- an `HKObserverQuery` for workouts
- an `HKObserverQuery` for body mass

It also enables background delivery for each type once that type has crossed the request boundary.

When HealthKit tells the app something changed, the observer path triggers the same serialized sync pipeline.

### How Sync Works

VillainArc uses separate anchored queries for workouts and body mass.

The anchors are stored in shared defaults, not SwiftData:
- `HealthSyncPreferences.workoutAnchor`
- `HealthSyncPreferences.weightEntryAnchor`

That gives the app this behavior:
- first sync with no anchor: backfill all matching workouts and body-mass samples
- later syncs: only fetch changes since the last successful sync for each category

The workout sync pass then:
- upserts returned `HKWorkout`s into `HealthWorkout`
- looks up rows by HealthKit workout UUID
- links rows back to `WorkoutSession` when the workout metadata contains the saved local session id
- updates existing rows when found
- inserts new rows when missing

The weight sync pass then:
- upserts returned `.bodyMass` samples into `WeightEntry`
- first tries to match by Health sample UUID
- otherwise tries to match by `WeightEntry.id` stored in Health metadata
- marks samples as app-owned only when the VillainArc weight-entry metadata key is present
- keeps Health-imported samples non-exported while still linking them by Health UUID
- updates existing rows when found
- inserts new local `WeightEntry` rows for Health-only samples when no local row exists

That is what lets the Health tab show body-mass history even when the data originated in Apple Health instead of in VillainArc.

## Deletions From Apple Health

When Apple Health deletes a workout or body-mass sample, VillainArc handles it in two stages:

1. sync marks the linked local row as no longer available in HealthKit, or deletes it immediately
2. the retention setting decides whether the local copy should remain or be removed

That keeps the decision separate:
- HealthKit tells the app the data disappeared
- the app setting decides whether VillainArc should retain the cached record

### Retention Setting Behavior

VillainArc has a single retention setting for removed Apple Health data.

When `Keep Removed Data` is on:
- removed `HealthWorkout` rows stay in the local mirror
- removed linked `WeightEntry` rows stay in local history
- `isAvailableInHealthKit` becomes `false`
- retained workouts still open in cached-summary mode
- retained weight entries still appear in the Health tab

When `Keep Removed Data` is off:
- workouts removed from Apple Health are also removed from the local `HealthWorkout` mirror
- weight entries whose linked body-mass samples were removed are deleted from local storage
- already-retained unavailable workouts and weight entries are cleaned up when the setting is turned off

So the user can choose between:
- strict mirroring of Apple Health
- keeping VillainArc as a retained local copy of removed Health data

## Merged Workout History Flow

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

## Health Tab

The root `TabView` now has a dedicated Health tab.

`HealthTabView` currently reads `WeightEntry.history` and shows:
- the latest recorded weight
- a simple increasing/decreasing/stable trend based on recent entries
- a small sparkline built from up to the most recent 14 entries
- display values formatted with `AppSettings.weightUnit`

This is intentionally a small first slice of the broader Health surface:
- if there are no local or synced weight rows, the tab shows an empty state
- if body-mass samples sync from Apple Health, they appear here automatically
- if locally created entries are later exported or relinked, the same `WeightEntry` rows continue powering the tab

## Health Workout Detail Flow

Health workout detail is loaded on demand.

The app does not keep expanding `HealthWorkout` just to support richer workout screens.

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

The Health detail screen always starts with cached or live summary data like:
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

Heart rate is the main richer workout detail layer right now.

The detail loader:
- reads workout heart-rate statistics for average, minimum, and maximum
- queries heart-rate samples associated with that workout
- downsamples them for chart rendering

The chart is interactive, using the same selection pattern as the exercise detail charts:
- horizontal selection
- nearest-point snapping
- selected point callout

## Cached-Only Workout Detail Behavior

If a `HealthWorkout` is retained locally but no longer exists in Apple Health:
- the detail screen still opens
- cached summary values still render
- richer live Health sections do not render

That is how retained removed workouts stay useful without pretending the live Health workout still exists.

## Distance and Duration Formatting

Two display helpers matter for current workout Health UI:

- distance uses `AppSettings.distanceUnit`
- workout-style durations can use `secondsToTimeWithHours(_:)` so longer workouts render as `H:MM:SS`

That keeps Health workout display consistent with the rest of the app's unit model.

## Current Direction

The current HealthKit architecture already supports two surfaces:
- workout export, sync, merged history, and richer workout detail
- an initial Health tab backed by `WeightEntry` and Apple Health body-mass sync

The reusable pattern is:
- request Health access intentionally
- keep small persisted local records for list, tab, and history use
- relink with metadata before falling back to export
- load richer workout details on demand
- let retention rules control whether removed Health data should remain visible in VillainArc

# HealthKit Integration

This document explains the current Apple Health integration in VillainArc: how Health access is requested over time, how workout and body-mass data are exported and synced, how daily step/distance and energy aggregates are mirrored, how the Health tab gets its data, how Health workouts appear in history, how workout detail loads richer metrics, and what happens when Health data disappears from Apple Health.

## Main Files

- `Data/Services/HealthKit/Authorization/HealthAuthorizationManager.swift`
- `Data/Services/HealthKit/Live/HealthLiveWorkoutSessionCoordinator.swift`
- `Data/Services/HealthKit/Sync/HealthPreferences.swift`
- `Data/Services/HealthKit/Sync/HealthDailyMetricsSync.swift`
- `Data/Services/HealthKit/Export/HealthExportCoordinator.swift`
- `Data/Services/HealthKit/Sync/HealthSyncCoordinator.swift`
- `Data/Services/HealthKit/Sync/HealthStoreUpdateCoordinator.swift`
- `Data/Services/HealthKit/Detail/HealthWorkoutDetailLoader.swift`
- `Data/Models/Health/HealthWorkout.swift`
- `Data/Models/Health/WeightEntry.swift`
- `Data/Models/Health/HealthStepsDistance.swift`
- `Data/Models/Health/HealthEnergy.swift`
- `Data/Models/Health/WeightGoal.swift`
- `Data/Models/Sessions/WorkoutSession.swift`
- `Views/Tabs/Health/HealthTabView.swift`
- `Views/Health/Weight/WeightHistoryView.swift`
- `Views/Health/Steps/StepsDistanceHistoryView.swift`
- `Views/Health/Energy/HealthEnergyHistoryView.swift`
- `Views/Workout/History/WorkoutsListView.swift`
- `Views/Workout/HealthWorkoutDetailView.swift`
- `Views/Settings/AppSettingsView.swift`

## Core Idea

VillainArc treats Apple Health as an integration layer, not the main source of truth for the app.

The current split is:

- workouts use an app-owned `WorkoutSession` plus a mirrored `HealthWorkout`
- body mass uses a single local `WeightEntry` row that can be created locally, imported from Apple Health, or linked to both
- daily steps and walking/running distance use `HealthStepsDistance` as a per-day aggregate cache
- daily active and resting energy use `HealthEnergy` as a per-day aggregate cache
- weight goals are local VillainArc state through `WeightGoal`, not Apple Health data

That means:

- VillainArc-specific workout behavior stays on `WorkoutSession`
- Apple Health workout identity and cached summary data stay on `HealthWorkout`
- body-mass samples use `WeightEntry` as the local persistence layer for both app-entered and Health-synced weight history
- daily step, distance, and energy reads are mirrored as per-day aggregate caches instead of raw HealthKit samples
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

It remains the record the app learns from and builds suggestions from.

### `HealthWorkout`

`HealthWorkout` is the persisted Apple Health workout mirror. It stores:

- the HealthKit workout UUID
- an optional linked `WorkoutSession`
- start and end time
- duration
- activity type
- indoor/outdoor state when available
- active energy burned
- resting energy burned
- total distance
- source name
- whether the workout still exists in HealthKit

It is intentionally a summary/cache layer. It does not store route points, heart-rate samples, or other heavier detail data directly.

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

### `WeightGoal`

`WeightGoal` is local app state used by the Health tab. It stores:

- a stable local goal ID
- goal type such as cut, bulk, or maintain
- start and optional end date
- target weight
- optional target date
- optional target pace per week
- end reason when an active goal is replaced or finished

Goals are used for chart filtering, goal summaries, goal history, and the local goal-completion flow. They are not used for HealthKit syncing.

### `HealthStepsDistance`

`HealthStepsDistance` is the local per-day steps and walking/running distance cache. It stores:

- the start of the calendar day
- total step count for that day
- total walking/running distance in meters for that day

This model is not a raw HealthKit sample mirror. It is a daily aggregate cache used by the Health tab cards and steps history surfaces.

### `HealthEnergy`

`HealthEnergy` is the local per-day energy cache. It stores:

- the start of the calendar day
- active energy burned
- resting energy burned

Total energy is derived from those two fields rather than stored separately.

## Health Permission Flow

Health permission is optional from a product perspective and is not required to use the rest of the app.

VillainArc can offer Apple Health access:

- during new-user onboarding
- after setup for returning users when the current type set still needs a request
- later from settings

### When the Prompt Appears

VillainArc uses `authorizationAction()` to decide whether to offer Health access.

`authorizationAction()` calls `healthStore.statusForAuthorizationRequest(toShare:read:)`:

- `.shouldRequest` -> return `.requestAccess`
- `.unnecessary` or `.unknown` -> route to a settings-oriented action instead

This means:

- if the user already crossed the system dialog boundary for the current type set, VillainArc does not need its own prompt-version flag
- if new read or write types are added later, HealthKit can return `.shouldRequest` again and the prompt can surface automatically

### New-User Onboarding Step

During new-user onboarding, the Health step is embedded inside the profile flow and can be skipped. If the user connects, VillainArc also tries to prefill birthday, gender, and height for confirmation.

### Returning-User Standalone Prompt

For a returning user with an otherwise complete setup, onboarding can transition into the standalone Health-permission screen.

Current behavior is important:

- the standalone screen shows a connect button only
- the app does not transition from that state to `.ready` until the user taps Connect
- after the request call returns, VillainArc transitions to ready regardless of whether access was granted or denied

So the integration itself remains optional, but the current returning-user prompt is a blocking launch step until the user taps through it once.

### Settings Path

`AppSettingsView` is the manual access-management path after onboarding.

When the settings screen becomes active again, VillainArc:

- refreshes authorization state
- refreshes background delivery registration
- runs a Health sync pass

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
- common distance metrics
- swim stroke count
- running metrics
- cycling metrics
- HealthKit effort-related workout metrics

The important design rules are:

- `HealthWorkout` stays small
- `WeightEntry` stays a lightweight local history record
- daily steps, distance, and energy stay in one-row-per-day aggregate caches
- richer workout reads exist to support detail screens, not to keep inflating the persisted mirror

## Live Workout Flow

VillainArc starts Apple Health workout collection while a local workout is actively being logged.

The main sequence is:

1. a `WorkoutSession` enters `.active`
2. if workout write authorization exists, `HealthLiveWorkoutSessionCoordinator` starts or recovers an `HKWorkoutSession` and `HKLiveWorkoutBuilder`
3. the builder saves metadata including the local `WorkoutSession.id`
4. HealthKit can collect live heart rate and energy-related workout data during the session
5. when the local workout leaves active logging and moves to `.summary`, the coordinator stops the HealthKit session, ends collection, and finishes the workout
6. if HealthKit returns the saved `HKWorkout`, the app inserts or updates a linked `HealthWorkout` immediately

So the primary workout Health path is:

- live during the `.active` workout phase
- finalized when active logging ends, not when summary is dismissed
- linked through metadata plus the saved workout UUID
- able to recover an already-running Health session after app resume

## Workout Export and Reconciliation

The old post-completion export path still exists, but it is now mainly a repair path.

That fallback is used when:

- a completed app workout still has `hasBeenExportedToHealth == false`
- no matching Apple Health workout can be found by the stored `WorkoutSession.id` metadata

So workout export is now:

- reconciliation-aware
- metadata-linked
- mainly a repair path for older workouts, authorization changes, or failures near the end of live collection

The workout reconciliation pass:

- looks for an already-saved Apple Health workout whose metadata contains the local `WorkoutSession.id`
- relinks that Health workout back to the local session when found
- falls back to the older export path only when no matching HealthKit workout exists

## Weight Export and Reconciliation

`HealthExportCoordinator` also owns the body-mass export path for `WeightEntry`.

The reconciliation-oriented weight export sequence is:

1. find entries that still need an Apple Health link or export
2. first query Apple Health for an existing body-mass sample whose metadata contains the local `WeightEntry.id`
3. if found, relink the local row instead of creating a duplicate
4. otherwise save a new `.bodyMass` sample
5. upsert the local `WeightEntry` with the linked sample UUID and availability state

The reconciliation path is intentionally conservative. Direct export helpers are slightly looser, so the reconciliation pass is the safest way to think about normal body-mass syncing behavior.

## Sync Flow

VillainArc mirrors both Apple Health workouts and Apple Health body-mass samples into local SwiftData.

### When Sync Runs

There are two different entry patterns:

#### Ready / Manual / Settings Refresh

`HealthStoreUpdateCoordinator.syncNow()` runs:

1. `HealthSyncCoordinator.shared.syncAll()` to mirror Health data first
2. `HealthExportCoordinator.shared.reconcilePendingExports()` to repair local workout and weight exports afterward

That order matters. Sync happens first so already-saved Health data can be relinked before fallback export tries to create anything.

#### Observer-Triggered Updates

Observer callbacks also trigger `HealthStoreUpdateCoordinator`, but that path currently runs Health sync only. It does not automatically perform export reconciliation afterward.

### Background Updates

`HealthStoreUpdateCoordinator` registers:

- an `HKObserverQuery` for workouts
- an `HKObserverQuery` for body mass
- an `HKObserverQuery` for step count
- an `HKObserverQuery` for walking/running distance
- an `HKObserverQuery` for active energy burned
- an `HKObserverQuery` for resting energy burned

It also enables background delivery for each type once that type has crossed the request boundary.

### How Sync Works

VillainArc uses separate Health sync paths for:

- workouts
- body mass
- daily aggregate metrics

The anchors are stored in shared defaults:

- `HealthSyncPreferences.workoutAnchor`
- `HealthSyncPreferences.weightEntryAnchor`
- `HealthSyncPreferences.stepCountAnchor`
- `HealthSyncPreferences.walkingRunningDistanceAnchor`
- `HealthSyncPreferences.activeEnergyBurnedAnchor`
- `HealthSyncPreferences.restingEnergyBurnedAnchor`

That gives the app this behavior:

- first sync with no anchor: backfill all matching workouts, body-mass samples, and raw samples for the daily metric categories
- later syncs: only fetch changes since the last successful sync for each category

The workout sync pass:

- upserts returned `HKWorkout`s into `HealthWorkout`
- links rows back to `WorkoutSession` when workout metadata contains the saved local session ID
- updates existing rows when found
- inserts new rows when missing

The weight sync pass:

- upserts returned `.bodyMass` samples into `WeightEntry`
- first tries to match by Health sample UUID
- otherwise tries to match by `WeightEntry.id` stored in Health metadata
- marks app-owned entries only when the VillainArc weight-entry metadata key is present
- keeps Health-imported samples non-exported while still linking them by Health UUID
- inserts new local `WeightEntry` rows for Health-only samples when no local row exists

That is what lets the Health tab show weight history even when the data originated in Apple Health instead of in VillainArc.

The daily-metrics sync pass is different:

- anchored queries are used as change detectors for step count, walking/running distance, active energy, and resting energy
- changed samples are collapsed into affected calendar days
- the app then reruns daily cumulative statistics queries for the affected date range
- `HealthStepsDistance` rows are updated only for steps/distance fields
- `HealthEnergy` rows are updated only for active/resting energy fields
- deletion-driven refreshes can rebuild the already-synced coverage range for that metric because `HKDeletedObject` does not expose the deleted sample date

This keeps the local Health tab caches compact: one row per day instead of one row per raw HealthKit sample.

## Deletions From Apple Health

When Apple Health deletes a workout or body-mass sample, VillainArc handles it in two stages:

1. sync marks the linked local row unavailable in HealthKit or deletes it immediately
2. the app retention setting decides whether the local copy should remain

That keeps the decision separate:

- HealthKit says the source data disappeared
- the app decides whether VillainArc should retain the local mirror/cache

### Retention Setting Behavior

VillainArc has a single retention setting for removed Apple Health data:

- `AppSettings.keepRemovedHealthData`

When it is on:

- removed `HealthWorkout` rows stay in the local mirror
- removed linked `WeightEntry` rows stay in local history
- `isAvailableInHealthKit` becomes `false`

When it is off:

- workouts removed from Apple Health are deleted from the local mirror
- linked weight entries whose Health samples were removed are deleted from local storage
- already-retained unavailable rows are cleaned up when the setting is turned off

## Merged Workout History

Workout history is now a merged list, not a `WorkoutSession`-only list.

`WorkoutsListView` combines:

- visible completed `WorkoutSession`s
- mirrored `HealthWorkout`s

The merge rule is:

- always show visible app workouts
- only show a `HealthWorkout` row when it is not already represented by a visible linked `WorkoutSession`

That prevents duplicates for exported VillainArc workouts while still letting imported or retained Apple Health workouts appear in the same history surface.

## Health Tab

The Health tab now combines weight, steps, energy, and Apple Health workout history.

### Tab Root

`HealthTabView` shows:

- `WeightSectionCard`
- `HealthStepsSectionCard`
- `HealthEnergySectionCard`

Those cards summarize:

- the latest recorded weight plus a recent sparkline
- today's steps plus a recent steps bar chart
- today's total and active energy plus a recent stacked energy bar chart

### Weight History

`WeightHistoryView` expands that into:

- charted weight history
- cached range filters for `W / M / 6M / Y / All`
- active goal summary
- app-level goal completion presentation when a new weight entry qualifies or a user manually completes a goal
- links to all entries and goal history

`StepsDistanceHistoryView` expands the steps card into:

- grouped steps history using the shared time-series layout
- distance summary for the currently displayed or selected span
- cached range filters for `W / M / 6M / Y / All`
- aggregate metadata such as average, high, and total values for the visible span

`HealthEnergyHistoryView` expands the energy card into:

- grouped total-energy history with active-energy overlays
- cached range filters for `W / M / 6M / Y / All`
- aggregate metadata such as average total and average active energy for the visible span

### Weight Goals

`WeightGoal` powers:

- the active goal summary in weight history
- reusable goal mini charts in the active card and goal history
- the goal history list
- the full-screen goal completion flow

Creating a new goal automatically ends the previous active goal with a replacement end reason.

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

### What the Detail Screen Can Show

The detail screen always starts with cached or live summary data such as:

- duration
- calories
- distance
- source
- activity type

Then it conditionally adds richer sections when the live workout provides data, including:

- effort summary
- heart-rate stats and chart
- heart-rate zones
- route map
- split summaries when distance data supports them
- per-activity breakdowns
- other metric cards that can be derived from HealthKit statistics

The key rule is:

- the detail screen is modular
- if a metric is missing, that section simply does not appear

## Cached-Only Workout Detail Behavior

If a `HealthWorkout` is retained locally but no longer exists in Apple Health:

- the detail screen still opens
- cached summary values still render
- richer live Health sections do not render

That is how retained removed workouts stay useful without pretending the live Health workout still exists.

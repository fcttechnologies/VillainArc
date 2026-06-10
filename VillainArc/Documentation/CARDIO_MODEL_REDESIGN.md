# Cardio Session Model — Redesign

**Status:** design approved (Fernando, 2026-06-10), pre-prod, executing.
**Why now:** cardio ships first in 1.3 and is **not in production** (live store is 1.2.3 on schema V4; cardio was added in the unreleased V5). So the schema is free to change with no prod migration. Fernando resets the CloudKit dev+prod schema and reinstalls test builds.

---

## Problem

`CardioSession` today is one flat `@Model` with a 4-case `CardioSessionKind` (`outdoor/treadmill × run/walk`) and two type-specific relationships — `routePoints` (GPS) and `treadmillIntervals` (machine) — where whichever doesn't apply sits empty. It can't represent the full range of cardio (cycling, rowing, elliptical, stair stepper, hiking, swimming, HIIT…), each of which stores different data, and the named-type enum would explode combinatorially.

## Principle

**Composition, not `@Model` inheritance** (SwiftData inheritance is unsupported/fragile and unused across the project's 40 models; CloudKit makes it worse). The model is **abstract enough to represent any cardio session**; the "hierarchy" is expressed by a stored **capture mode** + optional capture-specific relationships, with a domain-level computed accessor for type-safe code. Types VillainArc can't natively record fall back to **HealthKit-only** (no app detail; metrics come from the linked HealthKit workout), and the user can browse those too.

## Taxonomy — two axes, not N combos

```swift
enum CardioActivity: String, Codable, CaseIterable, Identifiable {
    case run, walk, hike, cycle, row, elliptical, stairStepper, swim, other
}
enum CardioEnvironment: String, Codable, CaseIterable { case outdoor, indoor }
```

- `CardioActivity` → `HKWorkoutActivityType`, `title`, `shortTitle`, `systemImage`.
- `CardioEnvironment` → `HKWorkoutSessionLocationType` (outdoor/indoor).
- Replaces `CardioSessionKind`. (9 activities × 2 environments would be 18 flat cases — the axes avoid that.)

## Capture mode — the data pattern (stored, user-overridable)

```swift
enum CardioCaptureMode: String, Codable {
    case gpsRoute         // records a CardioRoutePoint track (outdoor distance work)
    case machineIntervals // records CardioMachineInterval entries (treadmill, indoor bike, stair)
    case healthKitOnly    // no app-recorded detail; metrics come from the linked HealthWorkout
}
```

Default derived from (activity, environment) at creation, but **stored** so the user can override (e.g. an outdoor run they want HealthKit-only, or any activity VA can't natively track):

| | outdoor | indoor |
|---|---|---|
| run / walk | gpsRoute | machineIntervals (treadmill) |
| hike | gpsRoute | healthKitOnly |
| cycle | gpsRoute | machineIntervals (bike) |
| stairStepper | — | machineIntervals |
| row / elliptical / swim / other | healthKitOnly | healthKitOnly |

## Models

### `CardioSession` (envelope — one `@Model`)
Universal fields: `id`, `title`, `notes`, `activityRawValue`, `environmentRawValue`, `captureModeRawValue`, `status`, `sourceRawValue`, `startedAt`, `endedAt`, `totalDistanceMeters`, `healthWorkoutUUID`, `healthWorkout` link.
Summary metrics (filled from HealthKit at finish, or for imported HK-only sessions): `averageHeartRateBPM?`, `activeEnergyKilocalories?`, `elevationGainMeters?`.
Capture-specific (only the one matching `captureMode` is populated):
```swift
@Relationship(deleteRule: .cascade, inverse: \CardioRoutePoint.session) var routePoints: [CardioRoutePoint]?
@Relationship(deleteRule: .cascade, inverse: \CardioMachineInterval.session) var machineIntervals: [CardioMachineInterval]?
```
Computed `capture: CardioCapture` (domain enum with associated values) gives type-safe access over the composed storage. `distance` recompute branches on `captureMode` (route Haversine vs interval sum vs HK total).

### `CardioRoutePoint` — **add elevation**
Current: `index, latitude, longitude, timestamp, horizontalAccuracy, speedMetersPerSecond?`.
Add: **`altitude: Double?`** (elevation gain is a core metric and currently uncomputable), `verticalAccuracy: Double?`, `course: Double?`. All optional → CloudKit-safe.
(Future, not now: for very long activities, a compressed polyline blob on the session is far lighter than one row per GPS sample. Rows are fine for v1.)

### `CardioMachineInterval` — generalize `CardioTreadmillInterval`
```swift
var index: Int; var addedAt: Date; var distanceMeters: Double
var speedKPH: Double?         // treadmill / indoor run-walk
var inclinePercent: Double?   // treadmill
var resistanceLevel: Double?  // bike, elliptical, stair
var cadenceRPM: Double?       // bike
var powerWatts: Double?       // bike (optional)
```
Each field optional so a treadmill interval fills speed/incline and a bike interval fills resistance/cadence. Distance recompute stays time-weighted from `speedKPH` where present.

## HealthKit-only + browse

A `healthKitOnly` session records no app detail; its metrics come from the linked `HealthWorkout` mirror (VA already has `HealthWorkout` + `HealthWorkoutMirrorImporter`). **Browse:** surface existing HealthKit cardio workouts (Apple Watch / other apps) inside VA's cardio history via the mirror, optionally materializing a `healthKitOnly CardioSession` on open. (Feature layer, after the core model lands.)

## Refinements (Fernando, 2026-06-10 notes)

**1. HealthKit-preferred capture.** When HealthKit workout recording is available, **prefer `.healthKitOnly`** over app-managed capture — the `HKLiveWorkoutBuilder` already records HR, energy, distance, **and the route** (`HKWorkoutRoute`), so for outdoor sessions we shouldn't maintain our own GPS points, and indoor walkers with HealthKit should be able to use HK data instead of logging intervals. So the default capture mode at session creation is: **HealthKit available → `.healthKitOnly`**; otherwise fall back to `.gpsRoute` (outdoor) / `.machineIntervals` (indoor). `CardioActivity.defaultCaptureMode(in:)` stays the *app-managed* fallback; a creation-time policy layers the HealthKit preference on top. The route/metrics for a `.healthKitOnly` session are read back from the HK workout (`HKWorkoutRoute` query) for map display — a read-from-HealthKit layer after the core. **OPEN FORK for Fernando:** keep app-managed GPS (`CardioRoutePoint` + `CardioRouteRecorder`) as the no-HealthKit fallback, *or* go fully HealthKit for the route and drop app-managed location recording entirely (simpler, but no outdoor tracking without HealthKit auth). The model supports both; pick before finishing the call-site sweep.

**2. Configurable Live Activity metrics.** The cardio Live Activity shows **two** metrics the user picks (stored in `AppSettings`), defaulting to **distance + time**. Other pairs: distance + energy, distance + heart rate. Base/fallback is distance + time when the chosen metric isn't available. Present **maximized** (expanded). This replaces the build-16 fixed priority (HR → energy → intervals). Feature layer after the core model + the HealthKit-capture default land.

## Schema handling

Cardio lives only in **V5** (unreleased 1.3 schema; prod 1.2.3 is V4). The `V4→V5` migration touches only AppSettings/HealthSyncState — **not** cardio — so changing the cardio models doesn't affect prod users migrating V4→V5. Plan:
- Edit the real cardio `@Model` types in place; update `VillainArcSchemaV5.models` (`CardioTreadmillInterval` → `CardioMachineInterval`).
- No V6 / migration stage — cardio is throwaway pre-release.
- **Requires:** Fernando redeploys the CloudKit schema (dev + prod reset) and does a **clean install** on test devices (same-version schema-hash change → existing test stores must be wiped). Prod 1.3 launch is the first cardio release, so prod is clean by construction.

## View rework + effort (Fernando's device-test feedback, 2026-06-10) — build 18

Real-world testing of build 17's first indoor walk surfaced these:

- **Indoor cardio must not show the map.** Only outdoor (GPS route) benefits from a map. `CardioSessionDetailView` today is a full-screen map (`mapLayer` → `outdoorMap`/`indoorMap`) with an **always-presented** `.sheet(isPresented: .constant(true))` for the metrics. The `indoorMap` (a bare `Map` with `UserAnnotation`) is wrong for indoor.
- **The always-presented sheet is the crash/stuck-sheet source.** "View in Health" (`openHealthWorkout` → pushes `.healthWorkoutDetail`) pushes *behind* a sheet that never dismisses (`interactiveDismissDisabled(true)`), so the pushed `HealthWorkoutDetailView` is hidden. Fernando wants the sheet **gone** → safe-area inset.
- **`HealthWorkoutDetailView` is the target "regular health-workout view."** It already renders the route map **only when** `routeCoordinates.count >= 2`, plus summary stats, HR chart, zones, splits, metrics, and an effort card — for any activity type. So the real direction: a finished cardio session with a linked `healthWorkout` should present **through `HealthWorkoutDetailView`** (map-or-not handled for free). "A lot needs updating since all different workout types" = this routing across all cardio types.

**Build-18 scope (conservative, addresses the concrete bugs; the full HealthWorkoutDetailView routing is the follow-up to confirm with Fernando):**
- Remove the `.sheet(isPresented: .constant(true))` from `CardioSessionDetailView`.
- **Outdoor (gpsRoute):** keep the route map; move the metrics to a `.safeAreaInset(edge: .bottom)` card (no blocking sheet) — "View in Health" then navigates cleanly.
- **Indoor / machine / healthKitOnly:** no map — a plain scrolling metrics detail (the `CardioMetricsSheet` content as a normal view), with "View in Health" → the rich `HealthWorkoutDetailView` when a `healthWorkout` is linked.
- **Effort rating** (mirror the workout flow): add `postEffort: Int = 0` to `CardioSession` (schema-free, pre-prod); a cardio effort prompt at finish gated by `promptForPostWorkoutEffort`; a cardio effort sample (mirror `HealthWorkoutEffortSampleBuilder.makeSample(for: WorkoutSession)`) + `relateWorkoutEffortSample` in the cardio coordinator's finish; display in the detail.
- **Double-workout hardening:** cardio `finishIfRunning` gets the strength flow's pre-save dedup guard (`findSavedCardioWorkout(for: cardioSessionID)` on the `cardioSessionID` metadata key → link instead of re-save); `recoverIfPossible` ends any non-matching active session instead of orphaning it. Mirror across both coordinators; respects the sync (mirror import dedups by HK UUID).

**Follow-up (confirm with Fernando):** route *all* finished-cardio detail through `HealthWorkoutDetailView` (full navigation change), and the configurable Live Activity metrics + HealthKit-preferred capture default.

## Build 19 — capture-mode choice (the keystone) + cardio UX (Fernando, 2026-06-10)

**Capture mode is now a user choice at start, not just a default.** The model already has `CardioCaptureMode` (gpsRoute / machineIntervals / healthKitOnly); the start flow must let the user pick **Manual vs Apple Health**, so a HealthKit-only session needs no route/interval input to begin. Cover *all* cases:

- **Outdoor** (run/walk/hike/cycle): **Track Route** (`gpsRoute`, app records GPS) **vs Apple Health** (`healthKitOnly`).
- **Indoor** (treadmill/bike/stair): **Log Intervals** (`machineIntervals`) **vs Apple Health** (`healthKitOnly`).
- **Apple Health** is offered only when `HealthAuthorizationManager.canWriteWorkouts`; otherwise only the Manual option. When Health is available it is the recommended/default (Fernando's HealthKit-preferred direction).
- **`healthKitOnly`:** the session starts immediately (no map, no interval section). `CardioHealthWorkoutCoordinator` already runs the live `HKLiveWorkoutBuilder` → live HR/energy/distance; finish reads the saved HK workout's distance/HR/energy into the session summary. The active view shows just the live metrics.

**Distance source — one source per mode (this is the pace bug fix).** `CardioActivityManager.contentState` currently does `distance = max(session.totalDistanceMeters, healthCoordinator.distanceMeters ?? 0)` and `pace = duration/distance` — mixing the manual-interval distance with the Watch's HK estimate gives a *different* pace in the Live Activity than the in-app interval view. Fix: each mode uses ONLY its own source everywhere (Live Activity + `CardioMetricGrid` + detail): `gpsRoute` → route distance; `machineIntervals` → interval distance (`session.totalDistanceMeters`); `healthKitOnly` → HK distance. Never `max()` across sources.

**Active-session view by mode:** `gpsRoute` → map + live metrics; `machineIntervals` → interval input + live metrics; `healthKitOnly` → live metrics only (no map, no interval section).

### Cardio UX fixes (build 19)
- **Recent cardio in the Cardio tab shows ALL cardio**, not just outdoor (`CardioTabView` recent list filters `isOutdoor` — drop that filter). The **route map** stays outdoor-only.
- **The routes map must not be interactive when there are no routes for the selected range** (disable pan/zoom/rotate when the filtered route set is empty).
- **Block saving a 0-distance indoor session** — a `machineIntervals` session with no intervals (0 distance) can't be finished/saved (the finish action is disabled / shows a guard). `healthKitOnly` indoor is exempt (HK provides distance).
- **The cardio detail share button:** today it shares plain text. Either remove it, or (preferred) make it **something nice** — a shareable summary card/image (Strava-style), not bare text.

## Execution order

1. Models + enums (`CardioSession.swift`): add `CardioActivity`/`CardioEnvironment`/`CardioCaptureMode`, rebuild `CardioSession`, add altitude to `CardioRoutePoint`, rename+generalize `CardioMachineInterval`, add the `CardioCapture` domain accessor.
2. `VillainArcSchemaV5.models` list.
3. Call sites: `CardioHealthWorkoutCoordinator`, `CardioActivityManager` + `CardioLiveActivity`, `CardioSessionContainer`, cardio views (`CardioTabView`, `CardioRoutesMapView`, `CardioSessionDetailView`, `CardioMetricGrid`), `AppRouter`, `CardioRouteRecorder`, sample/screenshot/seed data, tests.
4. Build-verify (full scheme, iOS 27 SDK) → fold into the next archived build.

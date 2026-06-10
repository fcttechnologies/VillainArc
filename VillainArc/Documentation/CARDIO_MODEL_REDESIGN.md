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

## Schema handling

Cardio lives only in **V5** (unreleased 1.3 schema; prod 1.2.3 is V4). The `V4→V5` migration touches only AppSettings/HealthSyncState — **not** cardio — so changing the cardio models doesn't affect prod users migrating V4→V5. Plan:
- Edit the real cardio `@Model` types in place; update `VillainArcSchemaV5.models` (`CardioTreadmillInterval` → `CardioMachineInterval`).
- No V6 / migration stage — cardio is throwaway pre-release.
- **Requires:** Fernando redeploys the CloudKit schema (dev + prod reset) and does a **clean install** on test devices (same-version schema-hash change → existing test stores must be wiped). Prod 1.3 launch is the first cardio release, so prod is clean by construction.

## Execution order

1. Models + enums (`CardioSession.swift`): add `CardioActivity`/`CardioEnvironment`/`CardioCaptureMode`, rebuild `CardioSession`, add altitude to `CardioRoutePoint`, rename+generalize `CardioMachineInterval`, add the `CardioCapture` domain accessor.
2. `VillainArcSchemaV5.models` list.
3. Call sites: `CardioHealthWorkoutCoordinator`, `CardioActivityManager` + `CardioLiveActivity`, `CardioSessionContainer`, cardio views (`CardioTabView`, `CardioRoutesMapView`, `CardioSessionDetailView`, `CardioMetricGrid`), `AppRouter`, `CardioRouteRecorder`, sample/screenshot/seed data, tests.
4. Build-verify (full scheme, iOS 27 SDK) → fold into the next archived build.

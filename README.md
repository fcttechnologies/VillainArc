# Villain Arc

Villain Arc is an iOS strength training app focused on structured progression.
It combines workout planning, live workout logging, and intelligent suggestions in a product designed for daily use and long-term evolution.

## Status

Platform rebuild (iOS 27+ minimum): built on FCTFoundation, synced through the FCT platform under
the mandatory FCT account.

## What it does

- Build and manage workout plans.
- Create weekly or rotation-based workout splits.
- Log workouts with set-level detail (reps, weight, set type, rest, RPE).
- Track outdoor and treadmill cardio sessions with routes, intervals, and optional Apple Health metrics.
- Review post-workout summaries and progression suggestions.
- Use Siri / Shortcuts / Spotlight to trigger key workflows faster.
- Use rest timer controls with Live Activities and widget support.
- Control the rest timer and glance at the live session from the Apple Watch companion app.

## Core capabilities

### Training workflow
- Split planning with day-level plan assignment.
- Session lifecycle management (`pending -> active -> summary -> done`).
- Dedicated cardio flow for outdoor run/walk route recording and manual treadmill intervals.
- Rep-range and rest-time policy editing.
- Exercise filtering by muscle groups.

### Suggestion engine
- Deterministic rule engine for progression and safety adjustments.
- On-device AI inference (Foundation Models) to assist in low-confidence pattern cases.
- Outcome resolution for accepted/rejected suggestions in later sessions.

### Apple ecosystem integrations
- SwiftUI app architecture.
- SwiftData persistence, local-first, synced through the FCT platform (FCTServerSync).
- App Intents + App Shortcuts.
- Spotlight indexing.
- Widget + Live Activity extensions.
- MapKit and Core Location for app-owned cardio routes.

## Tech stack

- Swift / SwiftUI
- SwiftData (local-first) + FCTFoundation (FCTServerSync/FCTBlobSync/FCTAccount/FCTMetrics)
- Foundation Models (on-device)
- ActivityKit / WidgetKit
- App Intents / Core Spotlight

## Project structure

- `VillainArc/` — main app target
- `VillainArcWatchApp/` — Apple Watch companion app (rest timer, live-workout glance, stats)
- `VillainArcIntentsExtension/` — SiriKit intents extension
- `VillainArcWidgetExtension/` — widget + Live Activity UI
- `VillainArcTests/` — test target

## Requirements

- Xcode 27+
- iOS 27+ deployment target
- FCTFoundation checked out as a sibling (`../FCTFoundation`, local path dependency)

## Getting started

1. Clone the repository.
2. Open `VillainArc.xcodeproj` in Xcode.
3. Select the `VillainArc` scheme.
4. Set your signing team / bundle settings as needed.
5. Run on an iOS 27 simulator (or supported device).

## Run tests

From Xcode:
- Product -> Test

Or CLI:

```bash
xcodebuild \
  -project VillainArc.xcodeproj \
  -scheme VillainArc \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test
```

## Notes

- AI usage and rationale are documented in `VillainArc/Data/AI_USAGE.md`.
- Architecture notes live under `VillainArc/Documentation/`.

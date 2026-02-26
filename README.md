# Villain Arc

Villain Arc is an iOS strength training app focused on structured progression.
It combines workout planning, live workout logging, and intelligent suggestions in a product designed for daily use and long-term evolution.

## Status

Beta testing (iOS 26+ target).

## What it does

- Build and manage workout plans.
- Create weekly or rotation-based workout splits.
- Log workouts with set-level detail (reps, weight, set type, rest, RPE).
- Review post-workout summaries and progression suggestions.
- Use Siri / Shortcuts / Spotlight to trigger key workflows faster.
- Use rest timer controls with Live Activities and widget support.

## Core capabilities

### Training workflow
- Split planning with day-level plan assignment.
- Session lifecycle management (`pending -> active -> summary -> done`).
- Rep-range and rest-time policy editing.
- Exercise filtering by muscle groups.

### Suggestion engine
- Deterministic rule engine for progression and safety adjustments.
- On-device AI inference (Foundation Models) to assist in low-confidence pattern cases.
- Outcome resolution for accepted/rejected suggestions in later sessions.

### Apple ecosystem integrations
- SwiftUI app architecture.
- SwiftData persistence (CloudKit sync enabled).
- App Intents + App Shortcuts.
- Spotlight indexing.
- Widget + Live Activity extensions.

## Tech stack

- Swift / SwiftUI
- SwiftData + CloudKit
- Foundation Models (on-device)
- ActivityKit / WidgetKit
- App Intents / Core Spotlight

## Project structure

- `VillainArc/` — main app target
- `VillainArcIntentsExtension/` — SiriKit intents extension
- `VillainArcWidgetExtension/` — widget + Live Activity UI
- `VillainArcTests/` — test target

## Requirements

- Xcode 26+
- iOS 26+ deployment target

## Getting started

1. Clone the repository.
2. Open `VillainArc.xcodeproj` in Xcode.
3. Select the `VillainArc` scheme.
4. Set your signing team / bundle settings as needed.
5. Run on an iOS 26 simulator (or supported device).

## Run tests

From Xcode:
- Product -> Test

Or CLI:

```bash
xcodebuild \
  -project VillainArc.xcodeproj \
  -scheme VillainArc \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' \
  test
```

## Notes

- AI usage and rationale are documented in `VillainArc/Data/AI_USAGE.md`.
- Architecture notes live under `VillainArc/Documentation/`.

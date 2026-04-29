# Workout Split Flow

This document explains how VillainArc models workout splits, resolves today’s training, and connects split state to Home, quick actions, App Intents, Spotlight, and workout starts.

## Main Files

- `Data/Models/WorkoutSplit/WorkoutSplit.swift`
- `Data/Models/WorkoutSplit/WorkoutSplitDay.swift`
- `Data/Models/Enums/SplitMode.swift`
- `Data/Services/Training/SplitScheduleResolver.swift`
- `Views/WorkoutSplit/WorkoutSplitView.swift`
- `Views/WorkoutSplit/WorkoutSplitDayView.swift`
- `Views/WorkoutSplit/WorkoutSplitListView.swift`
- `Views/WorkoutSplit/SplitBuilderView.swift`
- `Views/WorkoutSplit/SplitBuilderSupport.swift`
- `Views/Tabs/Home/Sections/WorkoutSplitSectionView.swift`
- `Intents/WorkoutSplit/*`
- `Data/Services/App/AppRouter.swift`
- `Data/Services/App/SpotlightIndexer.swift`

## Core Model

`WorkoutSplit` is the schedule container. It stores:

- title
- mode
- active/inactive state
- weekly offset state
- rotation progress state
- child `WorkoutSplitDay` rows

`WorkoutSplitDay` is one scheduled day. It stores:

- display name
- weekly weekday or rotation index
- rest-day flag
- target muscles
- optional linked `WorkoutPlan`

A split day can be descriptive without a linked plan. Home can still show the day and its target muscles, but starting today’s workout requires a linked plan.

## Split Modes

VillainArc supports two modes.

### Weekly

Weekly splits map days onto calendar weekdays.

The important scheduling field is `weeklySplitOffset`. It lets the user shift the week when they miss or move a day without rewriting every `WorkoutSplitDay`.

`normalizedWeeklyOffset` always wraps the offset into the supported weekday range before resolving a day.

### Rotation

Rotation splits move through ordered split days independent of weekday labels.

The important scheduling fields are:

- `rotationCurrentIndex`
- `rotationLastUpdatedDate`

When an active rotation split is resolved for today, the resolver advances the current index by the number of elapsed calendar days since the last recorded update. Manual previous/next controls update the current index and stamp today as the last update day.

## Active Split Rule

The app treats one split as active through app logic.

When a split is activated:

- other splits are marked inactive
- weekly splits keep their weekday structure
- rotation splits reset to index `0` and stamp today as `rotationLastUpdatedDate`

Inactive splits stay stored and can be managed from the split list.

## Builder and Editing

`SplitBuilderView` creates splits from either:

- a scratch weekly or rotation template
- a guided template in `SplitBuilderSupport`

Guided templates can create weekly schedules or rotation cycles. Rotation templates can include rest days between training days, after the cycle, or not at all depending on the chosen template support.

`WorkoutSplitView` edits the stored split directly. Users can:

- rename the split
- set it active
- create or manage splits
- edit day names, rest status, target muscles, and linked plans
- add, delete, reorder, rotate, or swap days depending on mode
- shift or reset weekly offsets
- move rotation progress forward or backward

Plan assignment uses `WorkoutPlanPickerView`. A day with a linked plan resolves muscles from that plan; a day without a linked plan uses its own target-muscle list.

## Schedule Resolution

`SplitScheduleResolver` is the shared source for “what is today?”

It returns a `SplitScheduleResolution` containing:

- the split
- the requested date
- the resolved split day
- any active training condition
- the effective schedule date

The resolver also applies active training condition state:

- `contextOnly`
  - today still resolves normally, with condition context available for UI text
- `trainModified`
  - today still resolves normally, with adjusted-training context available for UI text
- `pauseTraining`
  - workouts are blocked and the effective schedule date is pinned to the pause start day

For rotation splits, a paused training condition prevents rotation progress from advancing while paused.

## Home Surface

`WorkoutSplitSectionView` reads the active split and resolves today through `SplitScheduleResolver`.

Home can show:

- empty state when no split exists
- no-active-split state when splits exist but none are active
- active day card
- rest-day state
- paused-training state
- linked plan shortcut when today has a plan

The section donates relevant foreground intents when users open, create, or manage split surfaces.

## Starting Today’s Workout

Today’s workout can start from:

- Home expanded quick action
- `StartTodaysWorkoutIntent`
- split-related shortcut routes

All paths enforce the same practical gates:

- setup is complete
- no workout or plan authoring flow is active
- an active split exists
- the active split has days
- training is not paused
- today is not a rest day
- today has a linked workout plan
- a visible workout for the same plan has not already been started today

When those checks pass, the app starts a normal plan-backed `WorkoutSession` through `AppRouter.startWorkoutSession(from:)`. That means deferred suggestion gates, plan-target auto-fill, weight-unit conversion, Live Activities, and Health live-workout startup all follow the same session path as starting from a plan detail screen.

## App Intents and Spotlight

Split intents use fresh `ModelContext`s and the shared setup guards.

Important split intents include:

- create a split
- manage workout splits
- open the active split
- open today’s plan
- start today’s workout
- summarize training for a selected date

`WorkoutSplitEntity` projects enough split content for Shortcuts and Spotlight without exposing the full SwiftData graph. Search prefers active and title-matched splits, then falls back to plan/day/muscle content.

Spotlight indexes splits and reindexes linked splits when plans are saved or deleted so linked-plan summaries stay current.

## Relationship to Plans

Splits reference completed `WorkoutPlan` records from their days. Plans are still authored and edited by the plan flow; split days only point to them.

When a plan changes, `SpotlightIndexer.reindexLinkedWorkoutSplits(for:)` keeps split search summaries current. When a plan is deleted, linked split indexing is refreshed and a day whose plan relationship is null behaves like an unassigned training day.

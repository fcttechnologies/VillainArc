# Exercise History Flow

This document explains how VillainArc maintains cached exercise analytics and how that cache is used across the app.

## Main Files

- `Data/Services/Workout/ExerciseHistoryUpdater.swift`
- `Data/Models/Exercise/ExerciseHistory.swift`
- `Data/Models/Exercise/ProgressionPoint.swift`
- `Data/Models/Exercise/Exercise.swift`
- `Views/Tabs/Home/Sections/RecentExercisesSectionView.swift`
- `Views/Exercise/ExercisesListView.swift`
- `Views/Exercise/ExerciseDetailView.swift`
- `Views/Exercise/ExerciseHistoryView.swift`
- `Data/Services/Workout/WorkoutDeletionCoordinator.swift`
- `Data/Services/App/SpotlightIndexer.swift`

## Core Idea

VillainArc separates:

- raw workout data in `ExercisePerformance` and `SetPerformance`
- cached per-exercise analytics in `ExerciseHistory`

`ExerciseHistory` is the read-optimized layer used for:

- completed-workout recency
- totals and PR-style aggregates
- chart points
- exercise Spotlight eligibility

It is rebuilt at transition points. It is not updated live while the user is still logging sets.

## When Histories Rebuild

### Completed Workout Finalization

The main rebuild point is `WorkoutSummaryView.finishSummary()`.

That flow:

1. finalizes current-session suggestion state
2. cleans up active-only prescription links
3. calls `ExerciseHistoryUpdater.updateHistoriesForCompletedWorkout(...)`
4. marks the workout `.done`
5. saves and dismisses

Important detail:

- the rebuild includes the current summary workout even before the workout is marked `.done`

That lets the cache reflect the just-finished workout immediately.

### Workout Deletion / Hiding

Completed workout deletion flows through `WorkoutDeletionCoordinator`.

That path:

- removes the workout from Spotlight
- hides or deletes the workout depending on retention settings
- deletes related suggestion-learning artifacts when hard-deleting
- collects affected exercise `catalogID`s
- rebuilds or removes `ExerciseHistory` rows for those exercises

If the user later disables `Retain for Improved Accuracy`, the app purges previously hidden workouts through the same deletion pipeline.

## What `ExerciseHistoryUpdater` Does

For completed workouts, the updater:

- collects affected exercise `catalogID`s
- batch-fetches matching completed performances
- batch-fetches existing history rows
- batch-fetches matching catalog exercises
- rebuilds each affected history from scratch
- updates Spotlight for those exercises

For deleted/hidden workouts, the updater:

- assumes the target workout is already hidden or deleted
- fetches remaining completed performances
- recalculates surviving histories
- deletes history rows that no longer have completed data
- updates Spotlight accordingly

## The `ExerciseHistory` Cache

`ExerciseHistory` stores one row per exercise `catalogID`.

The cache includes:

- `lastCompletedAt`
- total sessions
- total sets and reps
- cumulative volume
- latest and best estimated 1RM
- best weight
- best volume
- best reps
- `progressionPoints`

The cache is recalculated from scratch from completed performances. That avoids drift from trying to incrementally patch derived stats.

Important detail:

- one workout can contain multiple `ExercisePerformance` rows for the same exercise
- the cache groups those by workout so session-level totals stay correct

## `ProgressionPoint`

`ProgressionPoint` is the chart-point model used by `ExerciseDetailView`.

Each point stores:

- date
- top weight
- total reps
- volume
- estimated 1RM

The detail charts read these cached points directly instead of rebuilding chart series from raw performed data on every view load.

## User-Facing Surfaces

### Home Recent Exercises

`RecentExercisesSectionView` uses:

- `ExerciseHistory`
- `ExerciseHistoryOrdering`
- matching catalog `Exercise` rows

This surface is based on completed-workout recency, not picker recency.

### Exercises List

`ExercisesListView` combines:

- catalog identity and search metadata from `Exercise`
- completed-workout recency from `ExerciseHistory`

That is why favorites, search, and workout-based recency can all coexist in one list.

### Exercise Detail

`ExerciseDetailView` is the cached analytics screen.

It reads:

- the catalog exercise
- its `ExerciseHistory` row

It uses the cache for:

- stat cards
- progression chart series
- PR-style aggregates

### Exercise History View

`ExerciseHistoryView` is the raw-performance drill-down.

It queries completed `ExercisePerformance` rows directly and shows literal performed set data.

That split is intentional:

- `ExerciseDetailView` = cached analytics
- `ExerciseHistoryView` = raw historical data

## PR Detection

`WorkoutSummaryView` checks PRs against the previous cached history before rebuilding the cache.

That order matters. If the app rebuilt history first, the just-finished workout would be compared against itself.

## Spotlight Eligibility

Exercise Spotlight indexing is history-backed.

That means:

- an exercise can be indexed when it has completed history
- if its last completed performance disappears, the history row is removed and Spotlight eligibility disappears with it

The catalog `Exercise` row still exists; only the history-backed indexing changes.

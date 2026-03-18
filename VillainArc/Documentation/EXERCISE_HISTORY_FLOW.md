# Exercise History Flow

This document explains the exercise-history side of the app: when VillainArc rebuilds cached exercise analytics, how that cache powers exercise-facing screens, and where the app still reads raw performed data directly.

## Main Files

- `Data/Services/ExerciseHistoryUpdater.swift`
- `Data/Models/Exercise/ExerciseHistory.swift`
- `Data/Models/Exercise/ProgressionPoint.swift`
- `Data/Models/Exercise/Exercise.swift`
- `Views/HomeSections/RecentExercisesSectionView.swift`
- `Views/Exercise/ExercisesListView.swift`
- `Views/Exercise/ExerciseDetailView.swift`
- `Views/Exercise/ExerciseHistoryView.swift`
- `Data/Services/SpotlightIndexer.swift`

## Core Idea

VillainArc separates two kinds of exercise data:

- raw workout data in `ExercisePerformance` and `SetPerformance`
- cached analytics in `ExerciseHistory`

`ExerciseHistory` is the read-optimized layer used for:
- completed-workout recency
- totals and PR-style aggregates
- chart points
- exercise Spotlight eligibility

It is not updated live while the user is logging sets. Instead, it is rebuilt at workout transition points.

## When Histories Update

### Completion Path

The main rebuild point is `WorkoutSummaryView.finishSummary()`.

The important sequence is:
1. defer still-pending suggestions
2. clear active-only prescription links if needed
3. call `ExerciseHistoryUpdater.updateHistoriesForCompletedWorkout(...)`
4. mark the workout `.done`
5. save and dismiss

So the rule is:
- exercise history updates when summary is finalized
- not while the user is still logging the workout

### Deletion Path

Completed workout deletion now depends on the workout-history retention setting.

When a completed workout is deleted from:
- `WorkoutsListView`
- `WorkoutDetailView`

the app:
- always removes the workout from Spotlight
- either marks the workout `isHidden = true` so its performance snapshots stay available for suggestion learning, or hard-deletes the `WorkoutSession`
- when hard-deleting, also removes suggestion-learning records tied to that workout:
  - suggestion events created from that session
  - suggestion events anchored to performances in that session
  - suggestion evaluations sourced from that session
- collects the affected exercise `catalogID`s
- rebuilds histories for those affected exercises through `updateHistoriesForDeletedCatalogIDs(...)`

If the user later turns off `Retain Performance Snapshots for Suggestion Learning`, the app also finds already-hidden workouts and purges them through the same hard-delete path.

### Manual Repair Path

`ExerciseDetailView` also exposes a `Refresh History` action that rebuilds one exercise's history row from completed performances:
- `ExerciseHistoryUpdater.updateHistory(for: catalogID, ...)`

That is useful for debugging or repair without touching unrelated exercises.

## What `ExerciseHistoryUpdater` Does

`ExerciseHistoryUpdater` is a batch rebuild pipeline.

### For Completed Workouts

`updateHistoriesForCompletedWorkout(_ session, context:)`:
- collects the workout's `catalogID`s
- batch-fetches completed performances for those exercises
- explicitly includes the current workout even though it is still in `.summary`
- batch-fetches existing `ExerciseHistory` rows
- batch-fetches the matching catalog `Exercise` rows
- rebuilds each affected history from scratch
- reindexes those exercises in Spotlight

The "include the current summary workout" behavior is important. History needs to see the just-finished session before the workout has been marked `.done`.

### For Hidden Workouts

`updateHistoriesForDeletedCatalogIDs(...)`:
- assumes the workout has already been hidden
- fetches remaining completed performances for the affected exercises
- recalculates histories that still have data
- deletes histories that no longer have any completed performances
- removes or updates exercise Spotlight entries accordingly

## The `ExerciseHistory` Model

`ExerciseHistory` stores one row per exercise `catalogID`.

The cache includes:
- `lastCompletedAt`
- `totalSessions`
- `totalCompletedSets`
- `totalCompletedReps`
- `cumulativeVolume`
- `latestEstimated1RM`
- `bestEstimated1RM`
- `bestWeight`
- `bestVolume`
- `bestReps`
- `progressionPoints`

The key method is `recalculate(using performances:)`.

It:
- resets to empty if no performances exist
- groups performances by workout session
- collapses multiple same-exercise entries from one workout into one session summary
- recalculates totals and PR values from scratch
- stores progression points for all completed sessions

That grouping behavior matters because one workout can contain more than one `ExercisePerformance` for the same `catalogID`.

## `ProgressionPoint`

`ProgressionPoint` is the chart point model used by `ExerciseDetailView`.

Each point stores:
- date
- top weight
- total reps
- volume
- estimated 1RM

Charts read these cached points directly rather than rebuilding chart data from raw performances on every view load.

## Exercise Surfaces

### Home Section

`RecentExercisesSectionView` is the home exercise card.

It is driven by:
- `ExerciseHistory.recentCompleted(limit: 3)`
- `ExerciseHistoryOrdering`
- fetched catalog `Exercise` rows for those recent history IDs

It does not use picker recency such as `Exercise.lastAddedAt`.

### Exercises List

`ExercisesListView` combines:
- all catalog `Exercise` rows
- all recent `ExerciseHistory` rows
- `ExerciseHistoryOrdering`
- search helpers

Important behavior:
- default ordering is based on completed-workout recency from `ExerciseHistory`
- search still runs against catalog/search metadata from `Exercise`
- favorites are stored on `Exercise`

So the list is a blend of:
- catalog identity and searchability from `Exercise`
- workout-based recency from `ExerciseHistory`

### Exercise Detail

`ExerciseDetailView` is the cached analytics screen for one exercise.

It reads:
- `Exercise.withCatalogID(...)`
- `ExerciseHistory.forCatalogID(...)`

That history fetch also prefetches `progressionPoints`, so the detail screen can build chart series from the cached progression data without querying raw performances.

It uses `ExerciseHistory` for:
- total sessions
- total sets and reps
- cumulative volume
- best reps
- best weight
- latest estimated 1RM
- best volume
- progression chart points

It does not query raw performances for its main stat cards or charts. The chart view reads `ExerciseHistory.chronologicalProgressionPoints` directly and derives each metric series from that single cached array.

### Exercise History View

`ExerciseHistoryView` is the raw-performance drill-down.

It queries:
- `ExercisePerformance.matching(catalogID: ...)`

That performance fetch prefetches both `sets` and `repRange`, which matches what the history list headers and rows render.

It shows literal performed set data:
- set type
- reps
- weight
- effective rest
- visible RPE
- notes

So the split is intentional:
- `ExerciseDetailView` = cached analytics
- `ExerciseHistoryView` = raw historical performances

## PR Detection

`WorkoutSummaryView` calculates PRs against the previous cached history before the rebuild happens.

That is why PR detection still works correctly:
- compare the just-finished workout to the old cache first
- then rebuild the cache during final summary save

If the app rebuilt history first, the workout would be comparing against itself.

## Spotlight and Eligibility

Exercise Spotlight indexing is history-backed, not catalog-backed.

That means:
- when an exercise has completed history, it can be indexed
- when its last completed performance disappears, the `ExerciseHistory` row is deleted and Spotlight removes the exercise

The catalog `Exercise` row still exists. Only its history-backed search eligibility changes.

## Recency Rules

VillainArc uses two different recency concepts:

- `Exercise.lastAddedAt`
  - picker/add-replace recency
- `ExerciseHistory.lastCompletedAt`
  - completed-workout recency

User-facing exercise ordering in the home card and exercises list uses completed-workout recency through `ExerciseHistory`.

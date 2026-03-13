# Exercise History Flow

This document explains the exercise-history side of the app: how histories are updated when a workout is truly saved, how that cached data powers the exercise-related screens, and where raw performance history is still used directly.

## Main Files

- `Data/Services/ExerciseHistoryUpdater.swift`
- `Data/Models/Exercise/ExerciseHistory.swift`
- `Data/Models/Exercise/ProgressionPoint.swift`
- `Data/Models/Exercise/Exercise.swift`
- `Views/HomeSections/RecentExercisesSectionView.swift`
- `Views/Exercise/ExercisesListView.swift`
- `Views/Exercise/ExerciseDetailView.swift`
- `Views/Exercise/ExerciseHistoryView.swift`
- `Views/Exercise/ExerciseProgressionFeedbackSheet.swift`
- `Data/Services/SpotlightIndexer.swift`

## Core Idea

VillainArc separates two kinds of exercise data:

- raw workout data in `ExercisePerformance` and `SetPerformance`
- cached exercise analytics in `ExerciseHistory`

`ExerciseHistory` is the read-optimized layer used for recency, stats, charts, and most exercise-facing UI. It is not updated during logging. Instead, it is rebuilt at workout transition boundaries.

That means the exercise area is mostly powered by a derived cache, not by scanning every workout every time the user opens an exercise screen.

## The Moment Histories Actually Update

The main rebuild point is `WorkoutSummaryView.finishSummary()`.

When a workout is really finalized, summary does this sequence:
1. defer still-pending suggestions
2. clear active-only prescription links when needed
3. call `ExerciseHistoryUpdater.updateHistoriesForCompletedWorkout(workout, context: context)`
4. mark the workout `.done`
5. save and dismiss

So the important rule is:

- exercise history updates when the summary is finalized, not when the user is still logging sets

This is why the exercise home section, exercises list ordering, charts, and PR baselines all reflect only completed workout history.

## ExerciseHistoryUpdater

`Data/Services/ExerciseHistoryUpdater.swift` is the rebuild pipeline.

### Completion Path

`updateHistoriesForCompletedWorkout(_ session, context:)` is called from `WorkoutSummaryView.finishSummary()`.

It:
- collects the `catalogID`s from the workout’s exercises
- batch-fetches matching `ExercisePerformance` rows
- explicitly includes the just-finished session even though it is still in `.summary`
- batch-fetches any existing `ExerciseHistory` rows
- batch-fetches matching `Exercise` catalog rows
- rebuilds each affected history from scratch
- reindexes those exercises in Spotlight

That “include the current session” behavior is important. The workout is not yet `.done`, but the rebuild still needs to see it.

### Deletion Path

When a completed workout is deleted from `WorkoutsListView` or `WorkoutDetailView`, the app calls:

- `updateHistoriesForDeletedCatalogIDs(...)`

That path:
- assumes the workout has already been deleted from context
- fetches the remaining completed performances for the affected exercises
- recalculates histories that still have data
- deletes histories that no longer have any completed performances
- updates exercise Spotlight indexing accordingly

So histories are rebuilt on both:
- workout completion
- workout deletion

## ExerciseHistory Model

`Data/Models/Exercise/ExerciseHistory.swift` stores one history row per exercise `catalogID`.

The cache contains:
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
- resets to empty when there are no performances
- groups performances by workout session
- creates one session summary per workout
- computes totals and PR-style aggregates from those summaries
- stores up to 10 `ProgressionPoint` rows for charting

This grouping behavior matters because one workout can contain more than one `ExercisePerformance` for the same `catalogID`. The history layer collapses those into one workout-level summary before calculating sessions and chart points.

## ProgressionPoint

`Data/Models/Exercise/ProgressionPoint.swift` is the chart point model used by exercise detail charts.

Each point stores:
- date
- top weight
- total reps
- volume
- estimated 1RM

`ExerciseDetailView` uses these cached points instead of rebuilding chart data from raw performances on demand.

## Exercise Home Section

`Views/HomeSections/RecentExercisesSectionView.swift` is the home exercise card.

It does not use `Exercise.lastAddedAt`. Instead, it uses:
- all catalog `Exercise` rows
- recent `ExerciseHistory` rows from `ExerciseHistory.recentCompleted(limit: 3)`
- `ExerciseHistoryOrdering`

That means the home card is driven by completed-workout recency, not picker recency.

The display rows come from `Views/Components/ExerciseSummaryRow.swift`, and tapping through routes into the exercise area through `AppRouter`.

If the home section looks wrong, the first files to inspect are:
- `RecentExercisesSectionView.swift`
- `ExerciseHistory.swift`
- `ExerciseHistoryUpdater.swift`

## Exercises List

`Views/Exercise/ExercisesListView.swift` is the full exercise browser.

It combines:
- all `Exercise` catalog rows
- all recent `ExerciseHistory` rows
- `ExerciseHistoryOrdering`
- `Helpers/ExerciseSearch.swift`
- `Helpers/TextNormalization.swift`

The important behavior is:
- default ordering is based on `ExerciseHistory.lastCompletedAt`
- search is still run against the catalog/search metadata in `Exercise`
- favorites are stored on `Exercise`

So the exercise list is a blend of:
- catalog identity and searchability from `Exercise`
- workout-based recency from `ExerciseHistory`

If ordering is wrong but search looks fine, the issue is usually history-related, not list-UI-related.

## Exercise Detail View

`Views/Exercise/ExerciseDetailView.swift` is the main analytics screen for one exercise.

It queries:
- `Exercise.withCatalogID(...)` for the catalog row
- `ExerciseHistory.forCatalogID(...)` for the cached analytics

It does not scan `ExercisePerformance` directly for its stat tiles or chart data.

The detail view uses `ExerciseHistory` for:
- total sessions
- completed sets and reps
- cumulative volume
- best reps
- best weight
- latest estimated 1RM
- best volume
- chart points through `progressionPoints`

It also gates the AI progression surface through:
- `ExerciseProgressionContextBuilder.minimumSessionCount`

And it links to:
- `ExerciseHistoryView` for raw completed performances
- `ExerciseProgressionFeedbackSheet` for AI progression feedback

This split is intentional:
- `ExerciseDetailView` is the cached analytics surface
- `ExerciseHistoryView` is the raw-performance drill-down

## Exercise History View

`Views/Exercise/ExerciseHistoryView.swift` is the raw history screen.

Unlike `ExerciseDetailView`, this screen does query actual performances:
- `ExercisePerformance.matching(catalogID: ...)`

It shows:
- one section per completed performance
- set grids
- set type labels
- reps, weight, rest
- visible RPE badges
- performance notes

This is where you go when you need the literal performed sets rather than cached aggregates.

So the distinction is:
- `ExerciseHistory` cache drives summary analytics
- `ExercisePerformance` rows drive raw performance history

## Exercise Progression Feedback

`Views/Exercise/ExerciseProgressionFeedbackSheet.swift` is the AI coaching surface attached to exercise detail.

It depends on:
- `Data/Services/AI/ExerciseProgression/ExerciseProgressionContextBuilder.swift`
- `Data/Services/AI/ExerciseProgression/ExerciseProgressionAssistant.swift`
- cached history from `ExerciseHistory`
- a small recent-performance window from `ExercisePerformance`

This feature does not mutate plans or suggestions. It is exercise-focused feedback layered on top of the exercise detail area.

## PR Detection and History

`WorkoutSummaryView` uses `ExerciseHistoryUpdater.batchFetchHistories(...)` before the history rebuild to compare the just-finished workout against the previous cache.

That is how PR detection works correctly:
- compare current workout values against the old cache first
- then rebuild the cache when summary is finalized

If the app rebuilt history before checking PRs, the workout would be comparing against itself and the PR logic would be useless.

## Spotlight and Exercise Eligibility

Exercise Spotlight behavior is tied to history presence, not just catalog existence.

`SpotlightIndexer` only keeps exercises indexed when completed history exists.

That means:
- when a history row is created or updated, the exercise can be indexed
- when the last completed performance disappears, the history row is deleted and the exercise is removed from Spotlight

The catalog row itself still exists. Only its history-backed visibility changes.

## Recency Rules

VillainArc has two different recency concepts:

- `Exercise.lastAddedAt`: picker/add-replace recency
- `ExerciseHistory.lastCompletedAt`: completed-workout recency

User-facing exercise ordering in the home section and exercises list uses completed-workout recency through `ExerciseHistory`, not `lastAddedAt`.

That distinction is important when debugging “why is this exercise showing up here?” behavior.

## Common Edge Cases

### No-load or bodyweight exercises

Weight-based fields may stay zero, but history still works because reps-based totals and progression points still exist.

### First-ever completion of an exercise

The catalog `Exercise` row already exists, but the `ExerciseHistory` row is created on demand the first time the exercise appears in a completed workout.

### Deleting the only workout for an exercise

The catalog `Exercise` remains, but:
- `ExerciseHistory` is deleted
- the exercise disappears from history-driven Spotlight indexing
- exercise detail falls back to its empty state

### Multiple entries for the same exercise in one workout

History aggregation collapses those rows into one workout-level summary before computing session counts and chart points.

## What To Read By Problem

- History did not update after finishing a workout: `WorkoutSummaryView.swift`, `ExerciseHistoryUpdater.swift`
- Exercise disappeared or stayed in Spotlight incorrectly: `ExerciseHistoryUpdater.swift`, `SpotlightIndexer.swift`
- Home exercise section ordering is wrong: `RecentExercisesSectionView.swift`, `ExerciseHistory.swift`
- Exercises list ordering is wrong: `ExercisesListView.swift`, `ExerciseHistoryOrdering`
- Detail screen stats or charts are wrong: `ExerciseDetailView.swift`, `ExerciseHistory.swift`, `ProgressionPoint.swift`
- Raw exercise performance history is wrong: `ExerciseHistoryView.swift`, `ExercisePerformance.matching(...)`

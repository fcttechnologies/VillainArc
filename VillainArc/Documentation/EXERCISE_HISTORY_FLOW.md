# Exercise History & Progression System

This document describes how VillainArc tracks exercise history, caches analytics, detects personal records, and drives the progression chart surfaces.

It is based on the current code in:

- `Data/Models/Exercise/ExerciseHistory.swift`
- `Data/Models/Exercise/ProgressionPoint.swift`
- `Data/Services/ExerciseHistoryUpdater.swift`
- `Data/Models/Exercise/Exercise.swift`
- `Data/Models/Sessions/ExercisePerformance.swift`
- `Data/Models/Sessions/SetPerformance.swift`
- `Views/Workout/WorkoutSummaryView.swift`
- `Views/Exercise/ExerciseDetailView.swift`
- `Views/Exercise/ExerciseHistoryView.swift`
- `Views/History/WorkoutsListView.swift`
- `Data/Services/SpotlightIndexer.swift`

## Core Design

`ExerciseHistory` is a **derived analytics cache** — one record per unique `catalogID`. It is always rebuilt from scratch by scanning all completed `ExercisePerformance` records for that exercise.

Why full rebuild instead of incremental updates:

- **Correctness after deletions**: When a workout is deleted, incremental subtraction is error-prone. Full rebuild guarantees accuracy.
- **Simplicity**: No drift, no accumulation bugs, no need to track deltas.
- **Acceptable performance**: Typical rebuild is 50-200ms for 50 sessions. It runs after workouts (not during), so it does not affect logging UX.

The tradeoff is that rebuilds get slower as history grows. For the current app scale this is fine.

## ExerciseHistory Model

One record per `catalogID`. Stores:

**Session counts:**
- `lastCompletedAt` — timestamp of the most recent completed performance for this exercise
- `totalSessions` — number of unique completed workout sessions for this exercise
- `totalCompletedSets` — total sets across all sessions
- `totalCompletedReps` — total reps across all sessions
- `cumulativeVolume` — total weight × reps across all sessions
- `latestEstimated1RM` — estimated 1RM from the most recent session

**Personal Records:**
- `bestEstimated1RM` — highest estimated 1RM ever achieved
- `bestWeight` — heaviest weight ever used (any set)
- `bestVolume` — highest single-session volume
- `bestReps` — highest reps in a single set

**Progression data:**
- `progressionPoints` — array of `ProgressionPoint` (cascade delete), stores the last 10 sessions for charting

### recalculate(using:)

This is the core method. Given an array of `ExercisePerformance`:

1. If the array is empty, calls `reset()` which nils `lastCompletedAt`, zeros everything else, and clears progression points
2. Collapses duplicate `ExercisePerformance` rows from the same `WorkoutSession` into one session summary
3. Sorts those session summaries by date descending so recency fields are deterministic
4. Sets `lastCompletedAt` and `latestEstimated1RM` from the most recent session summary
5. Counts sessions by unique workout session, while still summing all sets, reps, and volume performed across duplicate blocks in that workout
6. Calculates PRs from the session summaries: max estimated 1RM, max weight, max volume, max reps
7. Stores progression data: takes the last 10 session summaries and creates one `ProgressionPoint` row per workout session

## ProgressionPoint

One timeseries data point for charting. Stores:

- `date` — when the performance happened
- `weight` — top weight used in that session
- `totalReps` — total completed reps in that session
- `volume` — total volume (weight × reps) for the session
- `estimated1RM` — best estimated 1RM from that session

These points drive the charts in `ExerciseDetailView`. The view uses a picker to let users switch between charting weight, volume, estimated 1RM, or reps over time.

## ExerciseHistoryUpdater

The rebuild pipeline. All methods are `@MainActor` and `static`.

### updateHistoriesForCompletedWorkout

Called from `WorkoutSummaryView.finishSummary()`. This is the primary update path.

1. Collects all `catalogID`s from the workout's exercises
2. Batch-fetches all matching `ExercisePerformance` rows in one query using `ExercisePerformance.matching(catalogIDs:includingSessionID:)`, with `sets` prefetched so recalc does not trigger per-performance faults
3. Batch-fetches existing `ExerciseHistory` rows in one query, with progression points prefetched internally during rebuild so chart-point resets do not fault one history at a time
4. Batch-fetches matching `Exercise` rows in one query for Spotlight reindexing
5. Rebuilds each affected history from the grouped performance map, creating `ExerciseHistory` on demand when the exercise is being completed for the first time
6. Reindexes each affected exercise in Spotlight

The `includingSessionID` parameter is important. At the time this runs, the workout is still in `.summary` status, not `.done`. The fetch descriptor normally only returns `.done` sessions. The `includingSessionID` override ensures the current session's data is included in the rebuild.

### updateHistoriesForDeletedWorkout

Called after a workout session is deleted. It delegates to `updateHistoriesForDeletedCatalogIDs`, which batch-fetches all remaining completed performances for the affected exercises, batch-fetches matching histories and exercises, then either recalculates or deletes each history depending on whether any completed performances remain. It must be called AFTER the session is deleted from context, so the fetch won't include the deleted performances.

### updateHistoriesForDeletedCatalogIDs

This is the shared deletion path used by workout list/detail delete actions and workout delete intents:

1. Collect the affected `catalogID`s before deleting the workout(s)
2. Delete the workout session rows from context and remove their workout Spotlight entries
3. Batch-fetch all remaining completed performances for those `catalogID`s
4. Batch-fetch existing histories plus matching `Exercise` rows for exercise Spotlight maintenance
5. For each affected `catalogID`:
   - If performances remain: recalculate history and reindex the exercise
   - If no performances remain: delete history and remove the exercise from Spotlight
6. Save once at the end (or let the caller own the final save in intent flows)

### updateHistory (single exercise)

Updates or creates history for one `catalogID`. Three behaviors:

- **No performances exist**: Deletes history if it exists, removes exercise from Spotlight
- **Performances exist, no history**: Creates new history, recalculates, indexes in Spotlight
- **Both exist**: Recalculates existing history

### batchFetchHistories

Fetches all `ExerciseHistory` records for a set of `catalogID`s in a single query. Returns a dictionary keyed by `catalogID` for O(1) lookup. Used by both the updater and `WorkoutSummaryView.loadPRs()`.

## When History Updates Happen

| Trigger | Method Called | Context |
|---------|-------------|---------|
| Workout completed (summary dismissed) | `updateHistoriesForCompletedWorkout` | Includes current session |
| Single workout deleted | `updateHistoriesForDeletedCatalogIDs` | After session deleted from context |
| All workouts deleted | `updateHistoriesForDeletedCatalogIDs` | After bulk deletion |
| Workout deleted from detail view | `updateHistoriesForDeletedCatalogIDs` | After session deleted |

History is never updated during active workout logging. It only runs at transition boundaries.

## PR Detection

`WorkoutSummaryView.loadPRs()` detects PRs by comparing the just-finished workout against cached history:

1. Batch-fetches histories for all exercises in the workout
2. For each exercise, calls `prTypesAndValues(for:history:)`:
   - **Estimated 1RM PR**: `exercise.bestEstimated1RM > history.bestEstimated1RM` (or history is zero/missing)
   - **Weight PR**: `exercise.bestWeight > history.bestWeight` (or history is zero/missing)
   - **Volume PR**: combined workout volume for that `catalogID` is `> history.bestVolume` (or history is zero/missing)
3. First-time exercises (no history yet) get PRs for any non-zero metrics

PR detection runs before exercise history is rebuilt. This is by design — comparing against the pre-updated cache is what makes the comparison meaningful. If history were rebuilt first, every session would match its own records.

## Exercise Detail View

`ExerciseDetailView` is the read-only analytics screen for one exercise. It uses:

- `@Query(Exercise.withCatalogID)` for the exercise catalog data
- `@Query(ExerciseHistory.forCatalogID)` for the cached metrics

It does NOT scan `ExercisePerformance` directly. All data comes from the cache.

Display:
- **Stat tiles** (`SummaryStatCard`): Shows non-zero metrics from the history (total sessions, total sets, total reps, best weight, best volume, best estimated 1RM, etc.)
- **Progression chart**: Line chart with point marks using `ProgressionPoint` data. A picker lets users switch between weight, volume, estimated 1RM, and reps over time
- **Footer button**: Links to `ExerciseHistoryView` for the full performance list

## Exercise History View

`ExerciseHistoryView` shows every completed performance for one `catalogID`, sectioned by workout date. Each section displays a set grid with:

- Set label/type
- Weight and reps
- Rest time
- Rep range
- Per-set RPE badges (`RPEBadge`)
- Notes

This view uses `@Query(ExercisePerformance.matching(...))` to fetch directly from performances, not from the cache. It's the detailed drill-down, not the analytics summary.

## Spotlight Integration

Exercise Spotlight eligibility is driven by `ExerciseHistory` presence:

- **Indexing**: When `ExerciseHistoryUpdater` creates or updates a history, it calls `SpotlightIndexer.index(exercise:)` for that exercise
- **Deindexing**: When history is deleted (no performances remain), it calls `SpotlightIndexer.deleteExercise(catalogID:)`

This means only exercises that have been used at least once appear in Spotlight search. Unused catalog exercises are not indexed.

## History Lifecycle

**Creation**: An `ExerciseHistory` record is created the first time a workout is completed that includes that exercise. The rebuild pipeline creates it on demand when performances exist but no cached history row does.

**Updates**: Every subsequent workout completion triggers a full recalculate for each exercise in that workout.

**Deletion**: When the last completed performance for an exercise is removed (typically by deleting the only workout containing it), `updateHistory` finds zero performances and deletes the history record. The exercise is also removed from Spotlight.

## Edge Cases

### Bodyweight / no-load exercises

Exercises with `weight == 0` on all sets still get valid history. `totalCompletedReps` and `bestReps` are the meaningful metrics. `ProgressionPoint.totalReps` provides the chart data. The detail view shows rep-based stats and hides weight-based ones when they're zero.

### Exercises with no completed sets

If a workout includes an exercise but no sets were marked complete, that exercise still appears in the performance history (it has a `ExercisePerformance` record). However, all metrics would be zero. The recalculation handles this gracefully — zero-metric sessions still count toward `totalSessions`.

### Deleting the only workout with an exercise

The exercise catalog entry (`Exercise`) is never deleted — it remains in the catalog. But the `ExerciseHistory` record is deleted, the exercise is removed from Spotlight, and the detail view shows empty state.

### Multiple exercises with same catalogID in one workout

Each exercise in a workout still has its own `ExercisePerformance`, and the rebuild fetch returns all of them. But `ExerciseHistory.recalculate(using:)` now collapses rows with the same `catalogID` and `workoutSession.id` into one session summary before computing totals, PRs, and progression points.

That means:
- `totalSessions` counts the workout once
- `bestVolume` uses the combined volume for that exercise across the whole workout
- progression charts show one point for that workout
- `totalCompletedSets`, `totalCompletedReps`, and `cumulativeVolume` still include all work performed across duplicate exercise blocks

### History rebuild during summary

The history rebuild in `finishSummary()` uses `includingSessionID` to include the current session. This means the session's data is reflected in the cache even before the session transitions to `.done`. Once it does transition, subsequent fetches (which filter on `.done` status) will naturally include it.

# SwiftData Audit


### 4. Plan cards trigger nested relationship reads in list and picker flows

Files:
- `Views/WorkoutPlan/WorkoutPlansListView.swift:6`
- `Views/WorkoutPlan/WorkoutPlanPickerView.swift:7`
- `Views/Components/WorkoutPlanCardView.swift:27`
- `Data/Models/Plans/WorkoutPlan.swift:153`

Why it matters:
- `WorkoutPlanCardView` iterates `workoutPlan.sortedExercises` and immediately reads `exercise.sets?.count`.
- The list, picker, home recent-plan card, and plan App Entity flows all rely on plan queries that only prefetch `exercises`, not nested `sets`.
- As plan count and plan size grow, rendering a page of plans becomes an avoidable N+1 fault pattern.

Recommendation:
- Add nested prefetching for plan card and entity consumers, or introduce a lightweight precomputed plan summary for card/list use.

## Medium Priority Findings

### 5. Workout and plan indexes do not match the actual hot query shapes

Files:
- `Data/Models/Sessions/WorkoutSession.swift:6`
- `Data/Models/Sessions/WorkoutSession.swift:195`
- `Data/Models/Plans/WorkoutPlan.swift:6`
- `Data/Models/Plans/WorkoutPlan.swift:153`
- `Data/Models/Sessions/ExercisePerformance.swift:6`

Why it matters:
- The dominant reads are compound:
  - `WorkoutSession`: `status == done && isHidden == false` sorted by `startedAt`
  - `WorkoutPlan`: `completed && !isEditing` sorted by `lastUsed`
  - `ExercisePerformance`: `catalogID` filtered and sorted by `date`
- The current schema mostly declares separate single-column indexes rather than indexes aligned to those full query shapes.
- `WorkoutSession` and `WorkoutPlan` also rely heavily on custom UUID lookups through intents/router flows without an explicit `id` index.

Recommendation:
- When you do the next schema version, add indexes that match the real filter/sort paths and add explicit `id` indexes for models frequently fetched by custom UUID.

### 6. Workout queries under-prefetch for list rows and entity serialization

Files:
- `Data/Models/Sessions/WorkoutSession.swift:195`
- `Views/Components/WorkoutRowView.swift:27`
- `Intents/Workout/WorkoutSessionEntity.swift:109`

Why it matters:
- `WorkoutSession.completedSessions` only prefetches `exercises`.
- `WorkoutRowView` immediately reads `exercise.sets?.count` for every row in the history list and home-card style surfaces.
- `WorkoutSessionEntity.init` also reads `preWorkoutContext` and every `exercise.sortedSets`.
- That produces avoidable relationship faults in the workout list, Spotlight, Siri, and Shortcuts.

Recommendation:
- Introduce a central workout descriptor for “card/entity” use that prefetches the full graph those flows actually read.

### 7. Plan entity and by-ID intent fetches miss the child graph they immediately traverse

Files:
- `Intents/WorkoutPlan/WorkoutPlanEntity.swift:83`
- `Intents/WorkoutPlan/StartWorkoutWithPlanIntent.swift:24`
- `Intents/WorkoutPlan/OpenWorkoutPlanIntent.swift:20`
- `Intents/WorkoutPlan/DeleteWorkoutPlanIntent.swift:19`
- `Intents/Workout/SaveWorkoutAsPlanIntent.swift:19`

Why it matters:
- These flows fetch a root `WorkoutPlan` by ID, then immediately walk exercises, sets, split links, or suggestion-cleanup relationships.
- The project already prefers extracted descriptors, but these paths still duplicate root-only fetches.
- That inconsistency makes the most expensive app-intent paths pay repeated child faults.

Recommendation:
- Add centralized by-ID descriptors for plans with the appropriate prefetched children and reuse them across intents, routing, and entity queries.

### 8. Exercise history rebuilds still do extra store work

Files:
- `Data/Models/Exercise/ExerciseHistory.swift:152`
- `Data/Models/Sessions/ExercisePerformance.swift:317`
- `Data/Services/ExerciseHistoryUpdater.swift:140`
- `Data/Services/SpotlightIndexer.swift:172`

Why it matters:
- `ExerciseHistory.recalculate(using:)` groups performances by `performance.workoutSession?.id`.
- The batch performance descriptors prefetch `sets`, but not `workoutSession`, so rebuilds can still fault the parent session per performance row.
- After rebuilding one history row, `ExerciseHistoryUpdater` calls `SpotlightIndexer.index(exercise:)`, which re-fetches the same `ExerciseHistory` row again for priority/description work.

Recommendation:
- Prefetch `workoutSession` where rebuild grouping depends on it.
- Avoid re-fetching `ExerciseHistory` during the same rebuild loop when the updated row is already in memory.

### 9. Exercise entity search uses full-table scans

Files:
- `Intents/Exercise/ExerciseEntity.swift:52`

Why it matters:
- `suggestedEntities()` backfills by fetching all exercises even though it only returns 30.
- `entities(matching:)` fetches the whole `Exercise` table and the recent-history table, then ranks in memory.
- That is manageable with a small catalog, but it scales poorly for live Shortcuts/App Intents search.

Recommendation:
- Constrain the candidate set earlier.
- Reuse extracted descriptors for recent/history-backed exercise suggestions.
- Avoid full-table fetches on every search update.

### 10. Workout split entity search expands every split before filtering

Files:
- `Intents/WorkoutSplit/WorkoutSplitEntity.swift:117`

Why it matters:
- Split entity matching fetches all splits, builds full `WorkoutSplitEntity` values, and only then filters by text.
- Entity construction walks split days and linked plan summaries, so each search keystroke does more store and CPU work than necessary.

Recommendation:
- Filter at the model-fetch layer first where possible, then build entities only for the filtered result set.

### 11. Plan detail subscribes to all splits for one toolbar decision

Files:
- `Views/WorkoutPlan/WorkoutPlanDetailView.swift:9`
- `Views/WorkoutPlan/WorkoutPlanDetailView.swift:29`

Why it matters:
- `WorkoutPlanDetailView` fetches all splits and scans them in memory just to determine whether this plan is today’s active split plan.
- That makes the screen react to unrelated split changes and can fault split-day/plan relationships it does not otherwise need.

Recommendation:
- Use the extracted active-split descriptor or pass the needed state in from the caller instead of subscribing to the full split store.

### 12. Exercise detail and history descriptors can still prefetch more accurately

Files:
- `Data/Models/Sessions/ExercisePerformance.swift:303`
- `Data/Models/Exercise/ExerciseHistory.swift:175`
- `Views/Exercise/ExerciseDetailView.swift:157`

Why it matters:
- `ExercisePerformance.matching(catalogID:)` prefetches `sets` but not `repRange`, even though the history screen reads both.
- `ExerciseHistory.forCatalogID(_:)` does not prefetch `progressionPoints`, even though exercise detail immediately builds chart data from them.
- `ExerciseDetailView` also re-sorts progression points multiple times from the same history object.

Recommendation:
- Prefetch the relationships those screens actually consume.
- Cache the derived chart series once per render rather than rebuilding from the same relationship repeatedly.

### 13. Row-level `AppSettings` queries also exist on exercise list cards

Files:
- `Views/Components/ExerciseSummaryRow.swift:5`

Why it matters:
- `ExerciseSummaryRow` performs its own `@Query(AppSettings.single)` for visible rows in the exercises browser and home recent-exercises section.
- This is lower impact than the set-grid case, but it is the same unnecessary row-level singleton observer pattern.

Recommendation:
- Pass `weightUnit` from the parent list instead of querying `AppSettings` in each row.

## Notes

- The project already has several good extracted fetch descriptors.
- The biggest consistency gap is that many of the most expensive intent/entity/widget/list paths still bypass those extracted descriptors or only prefetch the first relationship layer.
- The removed low-priority note about `Exercise.recentlyAdded` is intentionally omitted here because that flow is used by the exercise add/filter ranking surfaces.

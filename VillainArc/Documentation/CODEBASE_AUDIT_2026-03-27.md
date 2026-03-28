# VillainArc Codebase Audit

Date: 2026-03-27

This audit captures verified issues and improvement opportunities across documentation, accessibility, localization, and modularity. It is written as a planning artifact, not as a changelog.

## Highest Priority

1. Weight history accessibility text is wrong in non-kg locales
   - Files:
     - `Views/Health/Weight/WeightHistoryView.swift`
     - `Helpers/WeightFormatting.swift`
   - Evidence:
     - `displayedWeightValue` is already converted from kg into the selected display unit.
     - `chartAccessibilityValue` then calls `formattedWeightValue(..., unit: weightUnit)` again, which converts the already-converted number a second time.
   - Impact:
     - VoiceOver can announce incorrect values for the chart when the user prefers pounds.
     - This is the strongest “real bug” found in the accessibility/localization pass.

2. Core workout flow still ignores Reduce Motion
   - Files:
     - `Views/Workout/WorkoutSessionContainer.swift`
     - `Views/Components/Cards/SummaryStatCard.swift`
     - `Views/WorkoutSplit/WorkoutSplitDayView.swift`
     - `Views/WorkoutPlan/WorkoutPlansListView.swift`
     - `Views/Workout/History/WorkoutsListView.swift`
     - `Views/Workout/RestTimerView.swift`
     - `Views/Components/Inputs/TimerDurationPicker.swift`
     - `Views/WorkoutSplit/WorkoutSplitView.swift`
     - `Views/WorkoutSplit/WorkoutSplitListView.swift`
   - Evidence:
     - several containers still use `.animation(...)`, `withAnimation(...)`, and move transitions without checking `accessibilityReduceMotion`
     - the core session state router is affected, not just decorative UI
   - Impact:
     - users who explicitly disable motion still get directional transitions and spring animations in frequent flows

3. Documentation is stale in a few important flow descriptions
   - Files:
     - `Documentation/PROJECT_GUIDE.md`
     - `Documentation/SUGGESTION_AND_OUTCOME_FLOW.md`
     - `Documentation/ONBOARDING_FLOW.md`
     - `Documentation/ARCHITECTURE.md`
   - Evidence:
     - `Awaiting Outcome` is documented as accepted-only, but current grouping/UI includes rejected unresolved items too
     - project guide still describes `ContentView` as owning two full-screen flows even though it now owns three
     - onboarding doc places CloudKit import monitor startup later than the current code path
   - Impact:
     - these docs are good overall, but the stale parts now describe the wrong app flow and are likely to mislead future refactors

4. Measurement, unit, and pacing text is fragmented across the codebase
   - Files:
     - `Data/Models/Enums/Units/WeightUnit.swift`
     - `Data/Models/Enums/Units/DistanceUnit.swift`
     - `Data/Models/Enums/Units/HeightUnit.swift`
     - `Views/Health/Weight/WeightHistoryView.swift`
     - `Views/Health/Steps/StepsDistanceHistoryView.swift`
     - `Views/Health/Energy/HealthEnergyHistoryView.swift`
     - `Views/Workout/HealthWorkoutDetailView.swift`
     - `Views/Workout/WorkoutLiveStatsView.swift`
   - Evidence:
     - unit types mostly emit string-concatenated abbreviations
     - higher-level views rebuild additional strings like `/wk`, `cal`, `bpm`, pace suffixes, and accessibility summaries on top of those
   - Impact:
     - localization will stay expensive
     - accessibility output will drift
     - modularity is weaker because each screen re-solves the same formatting problem differently

## Documentation

### Verified stale or missing flow descriptions

1. `Awaiting Outcome` is no longer accepted-only
   - Files:
     - `Documentation/PROJECT_GUIDE.md`
     - `Documentation/SUGGESTION_AND_OUTCOME_FLOW.md`
     - `Data/Models/Suggestions/SuggestionGrouping.swift`
     - `Views/Suggestions/WorkoutPlanSuggestionsSheet.swift`
   - Evidence:
     - docs describe the tab as focused on accepted changes only
     - current grouping helpers and sheet data include rejected unresolved items too
   - Recommendation:
     - update both docs to describe the current data source and UI behavior precisely

2. Some docs place workout history / Health workout detail under the wrong tab
   - Files:
     - `Documentation/PROJECT_GUIDE.md`
     - `Documentation/HEALTHKIT_INTEGRATION.md`
     - `Documentation/ARCHITECTURE.md`
     - `Views/Tabs/Home/HomeTabView.swift`
     - `Views/Tabs/Health/HealthTabView.swift`
   - Evidence:
     - current navigation ownership puts workout history and health workout detail under the Home tab stack
     - the Health tab only owns weight, steps, energy, all weight entries, and goal history destinations
   - Recommendation:
     - correct the tab ownership language in all three docs so flow diagrams match the router

3. `ContentView` description needs to include weight-goal completion
   - Files:
     - `Documentation/PROJECT_GUIDE.md`
     - `Views/AppShell/ContentView.swift`
   - Evidence:
     - `ContentView` now presents workout, plan, and weight-goal completion full-screen flows
     - the guide still lists only workout and plan
   - Recommendation:
     - update the shell overview to mention the third app-level full-screen route

4. Onboarding monitor order is slightly outdated
   - Files:
     - `Documentation/ONBOARDING_FLOW.md`
     - `Data/Services/App/OnboardingManager.swift`
   - Evidence:
     - docs imply `CloudKitImportMonitor` starts at the explicit import wait step
     - code starts monitoring earlier to avoid missing an import-complete event
   - Recommendation:
     - adjust the timeline wording so it reflects why the monitor is started early

5. Weight-goal completion flow deserves its own fuller explanation
   - Files:
     - `Documentation/PROJECT_GUIDE.md`
     - `Documentation/ARCHITECTURE.md`
     - `Views/Health/Weight/NewWeightEntryView.swift`
     - `Views/Health/Weight/WeightGoalHistoryView.swift`
     - `Views/AppShell/ContentView.swift`
   - Evidence:
     - docs mention the presentation route
     - docs do not explain the two actual triggers: auto-presentation from a qualifying entry and manual presentation from goal history
   - Recommendation:
     - add a short dedicated subsection or separate flow note

6. First-bootstrap Spotlight reindex description does not match the “continue without iCloud” path
   - Files:
     - `Documentation/ONBOARDING_FLOW.md`
     - `Documentation/PROJECT_GUIDE.md`
     - `Data/Services/App/OnboardingManager.swift`
   - Evidence:
     - docs describe first bootstrap as seeding then reindexing Spotlight
     - `continueWithoutiCloud()` seeds and creates singleton records but currently does not reindex
   - Recommendation:
     - either fix the code path or narrow the docs so they only claim reindexing where it actually happens

### Notes

- `PLAN_EDITING_FLOW.md`, `SESSION_LIFECYCLE_FLOW.md`, and `EXERCISE_HISTORY_FLOW.md` were materially closer to the current code than the items above.

## Accessibility and Localization

### High Priority

1. Reduce Motion coverage is incomplete in important flows
   - Files:
     - `Views/Workout/WorkoutSessionContainer.swift`
     - `Views/Workout/RestTimerView.swift`
     - `Views/Components/Inputs/TimerDurationPicker.swift`
     - `Views/WorkoutSplit/WorkoutSplitView.swift`
     - `Views/WorkoutSplit/WorkoutSplitListView.swift`
     - `Views/Components/Cards/SummaryStatCard.swift`
     - `Views/WorkoutSplit/WorkoutSplitDayView.swift`
     - `Views/WorkoutPlan/WorkoutPlansListView.swift`
     - `Views/Workout/History/WorkoutsListView.swift`
   - Recommendation:
     - centralize motion policy or add a shared helper so new views do not keep making the same decision ad hoc

2. Split calendar/day presentation is not localization-safe and still communicates state visually
   - Files:
     - `Views/WorkoutSplit/WorkoutSplitView.swift`
     - `Helpers/Accessibility.swift`
   - Evidence:
     - weekday initials are hardcoded in English
     - today/current-day indication is a dot and is not fully surfaced in VoiceOver output
   - Recommendation:
     - build one locale-aware day presenter for visible labels and accessibility text

3. Unit formatting is still raw-string based instead of measurement-style based
   - Files:
     - `Data/Models/Enums/Units/WeightUnit.swift`
     - `Data/Models/Enums/Units/DistanceUnit.swift`
     - `Data/Models/Enums/Units/HeightUnit.swift`
     - `Views/Health/Weight/WeightHistoryView.swift`
     - `Views/Health/Weight/NewWeightGoalView.swift`
     - `Views/Health/Weight/WeightGoalHistoryView.swift`
     - `Views/Health/Weight/WeightGoalCompletionView.swift`
     - `Views/Workout/HealthWorkoutDetailView.swift`
     - `Views/Workout/WorkoutLiveStatsView.swift`
   - Recommendation:
     - create one formatting layer for visible text, accessibility text, and pace/range composition

### Medium Priority

1. Reusable accessibility text still contains plain English literals
   - Files:
     - `Views/Components/Rows/ExerciseSetRowView.swift`
     - `Views/Components/RPEBadge.swift`
     - `Views/Workout/ExerciseView.swift`
     - `Views/Workout/HealthWorkoutDetailView.swift`
     - `Views/Health/Weight/WeightGoalCompletionView.swift`
     - `Views/Health/Weight/NewWeightGoalView.swift`
     - `Views/Health/Weight/WeightSectionCard.swift`
     - `Views/WorkoutSplit/SplitBuilderView.swift`
     - `Views/WorkoutSplit/SplitBuilderSupport.swift`
     - `Data/Models/Sessions/WorkoutSession.swift`
   - Evidence:
     - examples include `"Reference"`, `"Target"`, `"Use Previous"`, `"Live Stats"`, `"Complete Goal"`, `"Maintain"`, `"New Workout"`, `"set"/"sets"`, and template-day labels
   - Recommendation:
     - move repeated visible and spoken copy into localized helpers or the string catalog before adding more locales

2. Some Dynamic Type layouts are still risky
   - Files:
     - `Views/Workout/RestTimerView.swift`
     - `Views/WorkoutSplit/WorkoutSplitView.swift`
     - `Views/Health/Weight/WeightGoalCompletionView.swift`
   - Evidence:
     - large timer typography inside narrow layouts
     - fixed split-day capsule sizing
     - goal-completion hero composition built around fixed visual proportions
   - Recommendation:
     - verify with accessibility sizes and reflow, rather than relying on truncation and scale factors

3. Favorite state is hidden visually without a spoken replacement in at least one reusable card
   - File:
     - `Views/Components/Cards/WorkoutPlanCardView.swift`
   - Recommendation:
     - make sure favorite state is part of the accessible summary, not just the visible star

## Modularity

### High ROI refactors

1. Health history screens still duplicate too much chart controller code
   - Files:
     - `Views/Health/Weight/WeightHistoryView.swift`
     - `Views/Health/Steps/StepsDistanceHistoryView.swift`
     - `Views/Health/Energy/HealthEnergyHistoryView.swift`
     - `Helpers/TimeSeriesCharting.swift`
   - Evidence:
     - time-series extraction helped, but each screen still owns its own range cache, selected-point handling, metadata footer, empty/progress states, and range picker
   - Recommendation:
     - next extraction should be a reusable chart-card scaffold, not more isolated helper functions

2. Exercise picker flow is duplicated and already diverging
   - Files:
     - `Views/Workout/AddExerciseView.swift`
     - `Views/Workout/ReplaceExerciseView.swift`
     - `Views/Workout/FilteredExerciseListView.swift`
   - Evidence:
     - add and replace rebuild the same search/filter/sort/muscle-sheet stack while owning different confirmation rules
   - Recommendation:
     - extract a shared `ExercisePickerScreen` with configurable mode and injected commit/cancel behavior

3. Workout editor and workout-plan editor are near-parallel shells
   - Files:
     - `Views/Workout/WorkoutView.swift`
     - `Views/WorkoutPlan/WorkoutPlanView.swift`
     - `Views/Workout/ExerciseView.swift`
     - `Views/Components/Rows/ExerciseSetRowView.swift`
   - Evidence:
     - title menus, title/notes sheets, add/edit exercise flows, empty states, and set-editing affordances are highly similar
     - the plan version already has its own `WorkoutPlanSetRowView`, while the workout version composes `ExerciseSetRowView`
   - Recommendation:
     - extract a shared authoring scaffold and smaller shared exercise-editor pieces instead of maintaining two broad containers

### Medium Priority

1. Edit-mode list management is repeated across multiple screens
   - Files:
     - `Views/Workout/History/WorkoutsListView.swift`
     - `Views/WorkoutPlan/WorkoutPlansListView.swift`
     - `Views/Health/Weight/AllWeightEntriesListView.swift`
   - Evidence:
     - each screen recreates the same `EditMode` binding, delete-all confirmation, toolbar branching, and empty-state overlay
   - Recommendation:
     - extract either a reusable screen scaffold or at least shared toolbar/delete-all helpers

2. Motion policy is not centralized
   - Files:
     - `Views/Workout/WorkoutSessionContainer.swift`
     - `Views/Components/Inputs/TimerDurationPicker.swift`
     - `Views/WorkoutSplit/WorkoutSplitListView.swift`
     - `Views/Components/Cards/SummaryStatCard.swift`
   - Impact:
     - accessibility fixes are harder than they need to be because animation policy is repeated per view
   - Recommendation:
     - create a shared reduce-motion animation helper or wrapper

3. Calendar presentation logic is split across view code and helpers
   - Files:
     - `Views/WorkoutSplit/WorkoutSplitView.swift`
     - `Views/WorkoutSplit/WorkoutSplitDayView.swift`
     - `Helpers/Accessibility.swift`
   - Recommendation:
     - centralize weekday labels, initials, and “today/current day” phrasing into one feature-local presenter

4. Several small support structs are stranded inside large view files
   - Files:
     - `Views/Health/Weight/WeightHistoryView.swift`
     - `Views/Health/Steps/StepsDistanceHistoryView.swift`
     - `Views/Health/Energy/HealthEnergyHistoryView.swift`
   - Recommendation:
     - move feature-local support types into dedicated support files once the main extractions begin, so each screen is easier to reason about

## Suggested Order

1. Fix correctness issues first:
   - weight chart accessibility double-conversion
   - any doc/code mismatch you want to resolve immediately, especially onboarding reindex behavior

2. Close accessibility/localization gaps next:
   - reduce-motion coverage
   - split weekday/current-day localization and VoiceOver state
   - unit/measurement formatting centralization
   - remaining hard-coded assistive strings

3. Do modularity refactors after the formatting/accessibility decisions settle:
   - health chart scaffold
   - shared exercise picker
   - shared workout/plan authoring pieces
   - shared editable-list scaffolding

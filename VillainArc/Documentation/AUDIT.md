# Audit

This file records potential bugs and product-flow mismatches found while verifying the documentation against the current codebase.

## Findings

### High: Finish intent can store set weights in the wrong unit

`WorkoutView.finishWorkout(...)` converts displayed set weights back to canonical kg before saving, but `FinishWorkoutIntent` calls `WorkoutSession.finish(...)` and saves without running that conversion first.

Impact:

- workouts finished through the intent path can persist lbs values as if they were kg
- that can corrupt workout history, PRs, suggestions, and plan creation derived from those workouts

Relevant files:

- `Intents/Workout/FinishWorkoutIntent.swift`
- `Views/Workout/WorkoutView.swift`
- `Data/Models/Sessions/WorkoutSession.swift`

### Medium: Suggestions button can lead to an empty Awaiting Outcome sheet

`pendingOutcomeSuggestionEvents(...)` collects accepted and rejected unresolved events, and `WorkoutPlanDetailView` uses that broader helper to decide whether the plan has suggestion-sheet content. But `WorkoutPlanSuggestionsSheet` filters the Awaiting Outcome tab down to accepted events only.

Impact:

- the suggestions button can appear even when the only unresolved outcome state comes from rejected events
- tapping into Awaiting Outcome can then show an empty state that looks inconsistent with the button's presence

Relevant files:

- `Data/Models/Suggestions/SuggestionGrouping.swift`
- `Views/WorkoutPlan/WorkoutPlanDetailView.swift`
- `Views/Suggestions/WorkoutPlanSuggestionsSheet.swift`

### Medium: Resume selection is nondeterministic when multiple stranded records exist

`WorkoutSession.incomplete` and `WorkoutPlan.resumableIncomplete` both use `fetchLimit = 1` without a sort order. `AppRouter.checkForUnfinishedData()` resumes the first matching record returned by SwiftData.

Impact:

- if more than one incomplete workout or resumable plan exists, the app may reopen an older record instead of the most recent or most relevant one

Relevant files:

- `Data/Models/Sessions/WorkoutSession.swift`
- `Data/Models/Plans/WorkoutPlan.swift`
- `Data/Services/AppRouter.swift`

### Medium: Returning-user Health permission step blocks readiness until tapped

The current standalone Health-permission screen for returning users shows only a connect action and does not transition to `.ready` until the user taps it once.

Impact:

- this conflicts with the broader product message that Apple Health is optional and never blocks readiness
- users who do not want to make a Health decision on that launch are still forced through the screen

Relevant files:

- `Views/Onboarding/OnboardingView.swift`
- `Data/Services/OnboardingManager.swift`
- `Root/RootView.swift`

### Medium: Siri cancel only works when the active workout is already in memory

`handleSiriCancelWorkout` checks `activeWorkoutSession` in memory instead of looking up persisted incomplete workout state.

Impact:

- a cold-launch Siri cancel can no-op until normal resume restores the workout into memory

Relevant files:

- `Data/Services/AppRouter.swift`
- `Root/RootView.swift`

### Low: `Skip All` is stronger than the label suggests

In deferred pre-workout review, `Skip All` marks all pending/deferred events as `rejected` before proceeding to `.active`.

Impact:

- the label sounds like a temporary bypass, but the implementation is a final rejection action
- this is mainly a wording/product-alignment issue unless that behavior is intended

Relevant files:

- `Views/Suggestions/DeferredSuggestionsView.swift`

### Low: `com.villainarc.siri.endWorkout` is registered but has no handler

The activity type is still registered in app entry, but the handler body is empty.

Impact:

- the handoff surface exists without real behavior

Relevant files:

- `Root/VillainArcApp.swift`

### Low: Health status can read as denied even when core workout writes still work

`HealthAuthorizationManager.currentAuthorizationState` collapses all share-type statuses into one state and returns `.denied` if any share type is denied.

Impact:

- the Settings UI can present Apple Health as denied even when core workout writes are available and only some optional share types were declined

Relevant files:

- `Data/Services/HealthKit/HealthAuthorizationManager.swift`

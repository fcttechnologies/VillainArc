# VillainArc Project Guide

This file is the high-level walkthrough for the app. It explains how a user moves through VillainArc, which screens and services are involved, and where to look first when working on a feature. For file-by-file structure, read `Documentation/ARCHITECTURE.md`. For tricky subsystems, use the dedicated deep-dive docs linked throughout this guide.

## What VillainArc Is

VillainArc is a SwiftUI + SwiftData workout app for planning workouts, logging sessions, tracking exercise progress, and improving plans with suggestion feedback. The app also integrates with iOS system features like App Intents, Shortcuts, Spotlight, widgets, and Live Activities.

The main app areas are:
- onboarding and setup
- home dashboard
- workout sessions
- workout plans
- exercise detail and history
- workout splits
- suggestion review and outcome evaluation

The most important top-level files are:
- `Root/VillainArcApp.swift`
- `Views/ContentView.swift`
- `Data/Services/AppRouter.swift`
- `Data/SharedModelContainer.swift`

## App Launch and Onboarding

The app starts in `Root/VillainArcApp.swift`, which creates `RootView`, injects `SharedModelContainer.container`, and forwards Siri/Spotlight activities into `AppRouter.shared`.

`Root/RootView.swift` owns startup bootstrap. It creates `OnboardingManager` once per app launch, cleans up abandoned editing copies, refreshes shortcut parameters, and calls `OnboardingManager.startOnboarding()`.

`Views/ContentView.swift` is the foreground app shell. It owns:
- the `NavigationStack`
- the home screen sections
- the full-screen workout flow (`WorkoutSessionContainer`)
- the full-screen plan flow (`WorkoutPlanView`)

The onboarding state machine lives in `Data/Services/OnboardingManager.swift` and is responsible for:
- checking connectivity through `Helpers/NetworkMonitor.swift`
- checking iCloud and CloudKit through `Helpers/CloudKitStatusChecker.swift`
- seeding exercises through `Data/Services/DataManager.swift`
- rebuilding Spotlight on fresh setup through `Data/Services/SpotlightIndexer.swift`
- ensuring `UserProfile` and `AppSettings` exist through `Data/Services/SystemState.swift`

The onboarding UI lives in `Views/Onboarding/OnboardingView.swift`. It first shows bootstrap/progress/error states, then runs the profile flow for name, birthday, and height. Once onboarding reaches `.ready`, `RootView` asks `AppRouter.checkForUnfinishedData()` whether it should reopen an incomplete workout session or resumable incomplete plan.

## Home Screen

The home screen is a scroll view inside `ContentView` made of four main sections plus the bottom-bar "+" menu.

### Splits Section

`Views/HomeSections/WorkoutSplitSectionView.swift` shows the active split state. It is the app's "what should I do today?" card. It refreshes split rotation when needed and can route to:
- the split editor in `Views/WorkoutSplit/WorkoutSplitView.swift`
- today's plan in `Views/WorkoutPlan/WorkoutPlanDetailView.swift`
- split creation when no split exists

Its data comes from `Data/Models/WorkoutSplit/WorkoutSplit.swift`.

### Recent Workout Section

`Views/HomeSections/RecentWorkoutSectionView.swift` shows the latest completed workout and links to workout history. It uses `Views/Components/WorkoutRowView.swift` and routes to:
- `Views/History/WorkoutsListView.swift`
- `Views/Workout/WorkoutDetailView.swift`

### Recent Workout Plan Section

`Views/HomeSections/RecentWorkoutPlanSectionView.swift` shows the latest completed plan and links to:
- `Views/WorkoutPlan/WorkoutPlansListView.swift`
- `Views/WorkoutPlan/WorkoutPlanDetailView.swift`

It uses `Views/Components/WorkoutPlanRowView.swift`.

### Recent Exercises Section

`Views/HomeSections/RecentExercisesSectionView.swift` shows the most recently completed exercises, using `ExerciseHistory` ordering rather than picker recency. It links to:
- `Views/Exercise/ExercisesListView.swift`
- `Views/Exercise/ExerciseDetailView.swift`

It uses `Views/Components/ExerciseSummaryRow.swift`.

### Home Menu Actions

The "+" menu in `ContentView` exposes two main entrypoints:
- `router.startWorkoutSession()` for an empty workout
- `router.createWorkoutPlan()` for a new plan

## Navigation and Active Flows

`Data/Services/AppRouter.swift` is the navigation coordinator. It owns:
- stack navigation through `path`
- the active full-screen workout session through `activeWorkoutSession`
- the active full-screen plan through `activeWorkoutPlan`
- the original plan backing an edit-copy flow through `activeWorkoutPlanOriginal`
- intent-driven sheet flags for split builder, rest timer, workout settings, and pre-workout context

The important rule is that VillainArc only allows one active flow at a time. Router entrypoints such as `startWorkoutSession()`, `startWorkoutSession(from:)`, `createWorkoutPlan()`, and `editWorkoutPlan(_:)` all go through the same guard logic so UI actions, Spotlight launches, and App Intents behave consistently.

## Starting a Workout Session

There are two main session entry paths.

### Empty Workout

An empty workout usually starts from the home "+" menu or `StartWorkoutIntent`. That goes through `AppRouter.startWorkoutSession()`, creates a new `WorkoutSession`, saves it, and presents the full-screen workout flow.

### Plan-Based Workout

A plan-based workout starts from:
- `Views/WorkoutPlan/WorkoutPlanDetailView.swift`
- `Intents/WorkoutPlan/StartWorkoutWithPlanIntent.swift`
- `Intents/WorkoutSplit/StartTodaysWorkoutIntent.swift`

All of those go through `AppRouter.startWorkoutSession(from:)`, which creates `WorkoutSession(from: plan)`. If the plan has pending or deferred suggestion events, the new workout starts in `.pending` state so the user sees `DeferredSuggestionsView` before regular logging begins.

The status-driven container for workouts is `Views/Workout/WorkoutSessionContainer.swift`:
- `.pending` -> `Views/Suggestions/DeferredSuggestionsView.swift`
- `.active` -> `Views/Workout/WorkoutView.swift`
- `.summary` and `.done` -> `Views/Workout/WorkoutSummaryView.swift`

## Working Out

The active workout UI lives in `Views/Workout/WorkoutView.swift`. This screen owns:
- the exercise pages/list
- add exercise flow
- finish and cancel actions
- rest timer sheet
- workout settings sheet
- pre-workout context sheet
- intent-driven sheet presentation

Each exercise page is `Views/Workout/ExerciseView.swift`. That screen handles:
- the exercise's sets
- notes
- rep-range editor
- rest editor
- exercise replacement
- exercise history sheet

Each set row is `Views/Components/ExerciseSetRowView.swift`. That is where reps, weight, completion state, set type, quick actions, and timer auto-start logic meet.

The rest timer is handled by:
- `Views/Workout/RestTimerView.swift`
- `Data/Services/RestTimerState.swift`
- `Helpers/RestTimerNotifications.swift`
- `Data/LiveActivity/WorkoutActivityManager.swift`

Pre-workout context lives in:
- `Data/Models/Sessions/PreWorkoutContext.swift`
- `Views/Workout/PreWorkoutContextView.swift`

Workout-scoped settings live in:
- `Views/Workout/WorkoutSettingsView.swift`
- `Data/Models/AppSettings.swift`

## Finishing a Workout and Reaching Summary

Finishing a workout starts in `WorkoutView`, but the core cleanup logic lives in `Data/Models/Sessions/WorkoutSession.swift` in `finish(...)`.

That finish path does not blindly jump to summary. First it resolves incomplete data:
- unfinished sets can be completed or removed
- empty exercises are pruned
- if the workout ends up with no exercises left, the workout itself can be deleted instead of reaching summary

Once the workout is ready, `WorkoutSessionContainer` routes into `Views/Workout/WorkoutSummaryView.swift`.

`WorkoutSummaryView` is one of the app's most important orchestration files. It is where these systems meet:
- post-workout stats and UI
- suggestion outcome resolution
- generation of new suggestions
- suggestion review
- save-as-plan flow
- exercise history rebuild

The related read-only completed-workout screens are:
- `Views/History/WorkoutsListView.swift`
- `Views/Workout/WorkoutDetailView.swift`

Those screens also matter because deleting a workout must update derived exercise history and Spotlight state.

## Exercise History Updating

VillainArc does not recalculate exercise analytics live inside every exercise screen. Instead, completed sessions feed a derived cache.

That cache is `Data/Models/Exercise/ExerciseHistory.swift`. It stores:
- session count
- recency
- PR-style aggregates
- progression points for charts

The rebuild logic is `Data/Services/ExerciseHistoryUpdater.swift`. It runs after:
- workout completion from `WorkoutSummaryView`
- workout deletion from `WorkoutsListView`
- workout deletion from `WorkoutDetailView`

It batch-fetches performances, rebuilds each affected history from scratch, and also updates exercise Spotlight eligibility through `SpotlightIndexer`.

If something looks wrong in exercise recency, charts, or exercise Spotlight results, this is the first subsystem to inspect.

## Suggestions: Review, Deferral, Outcome Resolution, and New Suggestions

The suggestion system is only relevant for plan-based training. It is the feedback loop that compares what happened in the workout against the plan and adjusts future prescriptions.

The key files are:
- `Views/Suggestions/DeferredSuggestionsView.swift`
- `Views/Suggestions/SuggestionReviewView.swift`
- `Views/Workout/WorkoutSummaryView.swift`
- `Data/Services/Suggestions/Generation/SuggestionGenerator.swift`
- `Data/Services/Suggestions/Generation/RuleEngine.swift`
- `Data/Services/Suggestions/Outcomes/OutcomeResolver.swift`
- `Data/Services/Suggestions/Outcomes/OutcomeRuleEngine.swift`

### Pre-Workout Review

If a plan has pending or deferred suggestions, the next plan-based workout opens in `DeferredSuggestionsView` first.

From there:
- accepting a suggestion applies the change to the live plan immediately
- rejecting a suggestion keeps the plan as-is and marks that event rejected
- "Accept All" applies every pending/deferred event, then starts the workout
- "Skip" marks pending/deferred events rejected, then starts the workout

The screen only moves to `.active` workout logging after there are no undecided events left.

### Post-Workout Summary Review

When `WorkoutSummaryView` appears for a completed plan-based workout, it first runs older outcome evaluation, then generates new suggestions for the future.

The post-workout order is:
1. `OutcomeResolver.resolveOutcomes(...)`
2. `SuggestionGenerator.generateSuggestions(...)`
3. render generated groups through `SuggestionReviewView`

At this stage:
- accept = mark accepted and mutate the plan immediately through `applyChange(...)`
- reject = mark rejected and leave the plan unchanged
- defer = leave the suggestion unresolved for the next plan-based workout

When the summary is dismissed, any remaining pending suggestions are auto-converted to `deferred`.

### Outcome Resolution

Outcome resolution evaluates how earlier suggestions actually played out after the next workout. That happens in:
- `Data/Services/Suggestions/Outcomes/OutcomeResolver.swift`
- `Data/Services/Suggestions/Outcomes/OutcomeRuleEngine.swift`

The deterministic path uses performed workout data. `AIOutcomeInferrer` is only a fallback for lower-confidence cases.

### New Suggestion Generation

New suggestion generation happens in:
- `Data/Services/Suggestions/Generation/SuggestionGenerator.swift`
- `Data/Services/Suggestions/Generation/RuleEngine.swift`
- `Data/Services/Suggestions/Generation/SuggestionDeduplicator.swift`

The generator uses:
- `MetricsCalculator` for deterministic training-style and progression logic
- `AITrainingStyleClassifier` only when style detection is ambiguous
- frozen suggestion context from `ExercisePerformance.originalTargetSnapshot`
- frozen set matching from `SetPerformance.linkedTargetSetIndex`

## Workout Plans and Plan Editing

Plans are the blueprint layer of the app. The main files are:
- `Data/Models/Plans/WorkoutPlan.swift`
- `Data/Models/Plans/ExercisePrescription.swift`
- `Data/Models/Plans/SetPrescription.swift`
- `Views/WorkoutPlan/WorkoutPlanView.swift`
- `Views/WorkoutPlan/WorkoutPlanDetailView.swift`
- `Views/WorkoutPlan/WorkoutPlansListView.swift`
- `Views/WorkoutPlan/WorkoutPlanPickerView.swift`

### Creating a Plan

Plans can be created from:
- the home "+" menu through `AppRouter.createWorkoutPlan()`
- `WorkoutPlanPickerView`
- a completed workout via "Save as Workout Plan" from `WorkoutSummaryView` or `WorkoutDetailView`

The full-screen editor is always `WorkoutPlanView`.

### Editing a Plan

Plan editing uses the copy-merge pattern. The original plan is not edited directly.

The flow is:
1. `WorkoutPlanDetailView` calls `AppRouter.editWorkoutPlan(_:)`
2. `WorkoutPlan.createEditingCopy(context:)` creates a temporary editing copy
3. `WorkoutPlanView` edits the copy
4. `WorkoutPlan.applyEditingCopy(...)` or cancel logic resolves the flow

This matters because manual edits can invalidate unresolved suggestions. `WorkoutPlan+Editing.swift` reconciles the edited copy against the original and deletes stale pending-outcome changes when needed.

## Exercise Detail and History Flow

The exercise area has three main user-facing screens:
- `Views/Exercise/ExercisesListView.swift`
- `Views/Exercise/ExerciseDetailView.swift`
- `Views/Exercise/ExerciseHistoryView.swift`

### Exercise List

`ExercisesListView` is the searchable catalog/detail launcher. Its ordering is based on completed workout history, not add-to-workout recency. It relies on:
- `Data/Models/Exercise/Exercise.swift`
- `Data/Models/Exercise/ExerciseHistory.swift`
- `Helpers/ExerciseSearch.swift`
- `Helpers/TextNormalization.swift`

### Exercise Detail

`ExerciseDetailView` is the analytics screen for one exercise. It reads cached `ExerciseHistory` data for:
- recent performance context
- stat tiles
- chart data
- progression trend context

It can open:
- `ExerciseHistoryView` for raw completed-performance history
- `ExerciseProgressionFeedbackSheet` for AI progression analysis

### Exercise Progression Feedback

The exercise progression AI path is:
- `Views/Exercise/ExerciseProgressionFeedbackSheet.swift`
- `Data/Services/AI/ExerciseProgression/ExerciseProgressionContextBuilder.swift`
- `Data/Services/AI/ExerciseProgression/ExerciseProgressionAssistant.swift`

This feature is intentionally separate from the suggestion engine. It is exercise-detail coaching rather than plan mutation.

If something looks wrong in exercise detail, inspect both the UI and the underlying `ExerciseHistoryUpdater` path.

## Workout Splits

Workout splits are the scheduling layer that decide what "today" means.

The main files are:
- `Data/Models/WorkoutSplit/WorkoutSplit.swift`
- `Data/Models/WorkoutSplit/WorkoutSplitDay.swift`
- `Views/WorkoutSplit/WorkoutSplitView.swift`
- `Views/WorkoutSplit/WorkoutSplitListView.swift`
- `Views/WorkoutSplit/WorkoutSplitDayView.swift`
- `Views/WorkoutSplit/SplitBuilderView.swift`

The user-facing split flow is:
- create a split in `SplitBuilderView`
- manage it in `WorkoutSplitView`
- edit each day in `WorkoutSplitDayView`
- assign plans through `WorkoutPlanPickerView`
- surface today's plan through `WorkoutSplitSectionView`

`WorkoutSplit` owns the schedule logic itself:
- weekly mode
- rotation mode
- current day resolution
- `todaysSplitDay`
- `todaysWorkoutPlan`
- `refreshRotationIfNeeded(...)`

This same split state is used by:
- the home split card
- `StartTodaysWorkoutIntent`
- widget surfaces

So if split behavior changes, the home screen, intents, and widgets are all coupled to that model.

## Intents, Spotlight, Widgets, and Other Cross-Cutting Systems

These are not separate product areas, but they touch many core flows.

### App Intents and Shortcuts

The intent surface lives under `Intents/`. The most important glue files are:
- `Intents/IntentDonations.swift`
- `Intents/VillainArcShortcuts.swift`
- `Data/Services/SetupGuard.swift`

Intent entrypoints generally reuse existing app logic rather than inventing separate code paths. They typically validate state with `SetupGuard`, then route through `AppRouter` or shared services/models.

### Spotlight

Spotlight indexing is handled by `Data/Services/SpotlightIndexer.swift`. It indexes:
- completed workouts
- completed plans
- eligible exercises

The app re-enters from Spotlight through `AppRouter.handleSpotlight(...)`.

### Live Activity and Rest Timer

Live Activity behavior is shared across:
- `Data/Services/RestTimerState.swift`
- `Data/LiveActivity/WorkoutActivityManager.swift`
- `Data/LiveActivity/WorkoutActivityAttributes.swift`
- `VillainArcWidgetExtension/*`
- `Intents/LiveActivity/*`

This is why timer, active set state, and current workout status have cross-feature impact.

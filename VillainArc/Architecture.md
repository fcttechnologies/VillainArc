# Architecture Map (Work in Progress)

This document is updated as we walk through files for the Swift 6 migration.

## Root
- `Root/VillainArcApp.swift`
  - App entry point.
  - Creates the main `WindowGroup` with `ContentView`.
  - Injects the SwiftData container via `SharedModelContainer.container`.

## Data
- `Data/SharedModelContainer.swift`
  - Central SwiftData container factory shared by the app, router, App Intents, and future widgets.
  - Builds a `Schema` that includes workouts, templates, and supporting models.
  - Uses the App Group container at `group.com.fcttechnologies.VillainArc` and stores `VillainArc.store`.
  - Falls back to the default SwiftData location if the App Group container is unavailable.
  - Notes:
    - Module default actor isolation is `MainActor`, so this container is main-actor isolated by default.
- `Data/SampleData.swift`
  - Preview-only model container and sample data for SwiftUI previews.
  - `@MainActor` initialization and fetch helpers return sample workouts/templates.

## Data / Models
- `Data/Models/Muscle.swift`
  - Muscle enum with major/minor classification and `allMajor` list.
  - `isMajor` is `nonisolated` to allow use in key paths under Swift 6.
- `Data/Models/Exercise.swift`
  - Catalog exercise model with search index/tokens and favorite/last-used metadata.
  - Uses `Muscle.isMajor` to format `displayMuscles`.
- `Data/Models/WorkoutExercise.swift`
  - Per-workout exercise with sets, rep/rest policies, and display helpers.
  - Uses `Muscle.isMajor` to choose `displayMuscle`.
- `Data/Models/TemplateExercise.swift`
  - Per-template exercise with sets, rep/rest policies, and display helpers.
  - Uses `Muscle.isMajor` to choose `displayMuscle`.
- `Data/Models/ExerciseCatalog.swift`
  - Static exercise catalog used for seeding and previews.
  - Catalog constants are `nonisolated` for Swift 6 access outside `MainActor`.

## Views
- `Views/ContentView.swift`
  - Entry view for the main UI, hosted by `VillainArcApp`.
  - Injects and uses `AppRouter.shared` for navigation state and full-screen flows.
  - Seeds the exercise catalog via `DataManager.seedExercisesIfNeeded(context:)` on `.task`.
  - Calls `router.checkForUnfinishedData()` to resume in-progress workout/template.
  - Triggers intent donation in `startWorkout()` and `createTemplate()`.
- `Views/WorkoutsListView.swift`
  - Lists completed workouts via `@Query(Workout.completedWorkouts)`.
  - Uses `WorkoutRowView` for each workout row.
  - Deletes workouts and saves via `saveContext(context:)`.
- `Views/Template/TemplatesListView.swift`
  - Lists templates via `@Query(WorkoutTemplate.all)` with favorites filtering.
  - Uses `TemplateRowView` for each template row.
  - Toggles favorites and deletes templates; saves via `saveContext(context:)`.
- `Views/Workout/WorkoutDetailView.swift`
  - Displays a completed workout summary and sets.
  - Uses `AppRouter` to start a workout from an existing one and donates "start last workout again" when applicable.
  - Deletes workouts via `saveContext(context:)` and dismisses the view.
- `Views/Template/TemplateDetailView.swift`
  - Displays a template summary.
  - Uses `AppRouter` to start a workout from a template and donates "start workout with template".
  - Toggles favorites and deletes templates; saves via `saveContext(context:)`.
- `Views/Components/RecentWorkoutSectionView.swift`
  - Shows the most recent completed workout via `@Query(Workout.recentWorkout)`.
  - Navigates to `WorkoutsListView` using `AppRouter`.
  - Donates the "show workout history" and "view last workout" intents.
- `Views/Components/RecentTemplatesSectionView.swift`
  - Shows recent templates via `@Query(WorkoutTemplate.recents)`.
  - Navigates to `TemplatesListView` using `AppRouter` and donates "show templates list".
- `Views/Components/WorkoutRowView.swift`
  - Compact workout card that navigates to `WorkoutDetailView` via `AppRouter`.
- `Views/Components/TemplateRowView.swift`
  - Compact template card that navigates to `TemplateDetailView` via `AppRouter`.
- `Views/Workout/WorkoutView.swift`
  - Main workout session UI with paging vs list modes.
  - Presents sheets for add exercise, rest timer, and settings.
  - Uses `RestTimerState` environment and `IntentDonations` on workout completion.
  - Saves/deletes workouts via `saveContext(context:)`.
- `Views/Workout/WorkoutSettingsView.swift`
  - Workout edit/finish sheet; normalizes title and schedules saves.
  - Handles finish actions and delete confirmation.
- `Views/Workout/RestTimerView.swift`
  - Rest timer sheet driven by `RestTimerState` and recent `RestTimeHistory`.
  - Records recent rest times and saves via `saveContext(context:)`.
- `Views/Workout/AddExerciseView.swift`
  - Exercise picker sheet for workouts/templates.
  - Uses `FilteredExerciseListView` and `MuscleFilterSheetView`.
  - Dedupe catalog via `DataManager.dedupeCatalogExercisesIfNeeded(context:)`.
- `Views/Workout/MuscleFilterSheetView.swift`
  - Chip-based muscle filter selector with custom flow layout.
- `Views/Workout/FilteredExerciseListView.swift`
  - Exercise catalog list with search, favorites, and muscle filters.
  - Saves favorite toggles via `saveContext(context:)`.
- `Views/Workout/ExerciseView.swift`
  - Per-exercise editing view used in the workout session.
  - Looks up previous completed sets via `@Query`.
  - Presents `RepRangeEditorView` and `RestTimeEditorView`.
- `Views/Workout/RepRangeEditorView.swift`
  - Sheet to edit rep range policy; saves on changes and on dismiss.
- `Views/Workout/RestTimeEditorView.swift`
  - Sheet to edit rest time policy for an exercise or template exercise.
  - Saves on changes and on dismiss; uses `TimerDurationPicker`.
- `Views/Template/TemplateView.swift`
  - Template editor with add exercise sheet and per-exercise edit sections.
  - Uses `RepRangeEditorView` and `RestTimeEditorView` for template exercises.

## Data / Classes
- `Data/Classes/AppRouter.swift`
  - `@MainActor` + `@Observable` singleton that owns navigation path and active workout/template.
  - Reads/writes via `SharedModelContainer.container.mainContext`.
  - Starts or resumes workouts/templates, inserts into SwiftData, and saves via `saveContext`.
  - Note: any use from non-main contexts (e.g., App Intents, background tasks) must hop to `MainActor`.

- `Data/Classes/DataManager.swift`
  - `@MainActor` utility for seeding and deduping the exercise catalog.
  - Uses `UserDefaults` versioning and SwiftData fetches/inserts/deletes.
  - Exposes `saveContext` and `scheduleSave` helpers (main-actor isolated).

## Helpers
- `Helpers/Haptics.swift`
  - `@MainActor` haptics helper that wraps UIKit feedback generators.
  - Used across UI interactions (e.g., selection, success, warning, error).
- `Helpers/TextNormalization.swift`
  - Pure text normalization and fuzzy-search helpers.
  - Marked `nonisolated` for use from model code under Swift 6.

## Intents
- `Intents/IntentDonations.swift`
  - Convenience wrappers for donating App Intents from UI flows.
- `Intents/WorkoutTemplateEntity.swift`
  - AppEntity support for template selection in Shortcuts via `WorkoutTemplateEntity`.
- `Intents/StartWorkoutIntent.swift`
  - App Intent to start a new empty workout.
  - Uses `SharedModelContainer.container.mainContext` and `AppRouter.shared`.
  - Opens the app via `OpenAppIntent` on success.
- `Intents/StartWorkoutWithTemplateIntent.swift`
  - App Intent to start a workout from a selected template.
  - Uses `SharedModelContainer.container.mainContext` and `AppRouter.shared`.
  - Opens the app via `OpenAppIntent` on success.
- `Intents/StartLastWorkoutAgainIntent.swift`
  - App Intent to start a workout based on the most recent completed workout.
  - Uses `SharedModelContainer.container.mainContext` and `AppRouter.shared`.
  - Opens the app via `OpenAppIntent` on success.
- `Intents/ResumeActiveSessionIntent.swift`
  - App Intent to resume an active workout or template session.
  - Uses `SharedModelContainer.container.mainContext` and `AppRouter.shared`.
  - Opens the app via `OpenAppIntent` on success.
- `Intents/CreateTemplateIntent.swift`
  - App Intent to create or resume a template.
  - Uses `SharedModelContainer.container.mainContext` and `AppRouter.shared`.
  - Opens the app via `OpenAppIntent` on success.
- `Intents/ViewLastWorkoutIntent.swift`
  - App Intent to navigate to the most recent completed workout.
  - Uses `ModelContext(SharedModelContainer.container)` and `AppRouter.shared`.
  - Defines `OpenAppIntent` and opens the app after navigation setup.
- `Intents/ShowWorkoutHistoryIntent.swift`
  - App Intent to open the workouts list via `AppRouter.shared`.
  - Opens the app via `openAppWhenRun = true` after navigation setup.
- `Intents/ShowTemplatesListIntent.swift`
  - App Intent to open the templates list via `AppRouter.shared`.
  - Opens the app via `openAppWhenRun = true` after navigation setup.
- `Intents/LastWorkoutSummaryIntent.swift`
  - App Intent that speaks a summary of the last workout without opening the app.
  - Uses `ModelContext(SharedModelContainer.container)`.
- `Intents/VillainArcShortcuts.swift`
  - Registers Siri shortcut phrases for all App Intents.

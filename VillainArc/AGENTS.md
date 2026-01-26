# Repository Guidelines

## Project Overview
VillainArc is a SwiftUI iOS workout tracker using SwiftData. Workouts contain ordered exercises with sets, backed by a seeded exercise catalog.

## Architecture Overview
- `Root/VillainArcApp.swift` builds the SwiftData model container, launches `ContentView`, updates App Shortcut parameters, and routes Spotlight continuations when no session is active.
- `Views/ContentView.swift` loads workouts, seeds the catalog via `DataManager`, and presents `WorkoutView`/`TemplateView` using `AppRouter`.
- `Views/Components/RecentWorkoutSectionView.swift` surfaces the most recent completed workout or an empty prompt and links to the full history.
- `Views/WorkoutsListView.swift` lists completed workouts with edit/delete controls.
- `Views/Components/WorkoutRowView.swift` renders a compact summary/link for a workout in lists or sections.
- `Views/Workout/WorkoutDetailView.swift` displays a completed workout summary and can start or edit a workout.
- `Views/Workout/WorkoutView.swift` coordinates the workout session UI, paging vs list, and sheet flows.
- `Views/Workout/ExerciseView.swift` manages per-exercise editing, previous set lookup, notes, and the rep/rest editors.
- `Data/Classes/AppRouter.swift`: singleton navigation router handling `NavigationPath`, deep linking, and active workout/template sessions.
- `Data/Classes/SpotlightIndexer.swift`: Core Spotlight indexing and removal for completed workouts, templates, and catalog exercises.
- `Data/Classes/RestTimerState.swift`: shared rest timer state for UI and App Intents with persisted end date.
- `Data/SharedModelContainer.swift`: shared SwiftData container using App Groups for potential future cross-process access.

## App Intents
The app supports Siri Shortcuts via in-app App Intents (no separate extension target):
- `Intents/OpenAppIntent.swift`: opens the app for foregrounding flows.
- `Intents/Workout/StartWorkoutIntent.swift`: starts a new empty workout (errors if a workout/template is active).
- `Intents/Workout/StartWorkoutWithTemplateIntent.swift`: starts a workout from a selected template.
- `Intents/Workout/StartLastWorkoutAgainIntent.swift`: starts a workout based on the most recent completed workout.
- `Intents/Workout/ResumeActiveSessionIntent.swift`: resumes an active workout or template.
- `Intents/Template/CreateTemplateIntent.swift`: creates or resumes a workout template.
- `Intents/Workout/FinishWorkoutIntent.swift`: finishes the active workout and stops the rest timer.
- `Intents/Workout/CompleteActiveSetIntent.swift`: completes the next incomplete set in the active workout.
- `Intents/Exercise/AddExerciseIntent.swift`: adds a single exercise to the active workout or template.
- `Intents/Exercise/AddExercisesIntent.swift`: adds exercises to the active workout or template.
- `Intents/Workout/CancelWorkoutIntent.swift`: cancels the active workout and stops the rest timer.
- `Intents/RestTimer/StartRestTimerIntent.swift`: starts a rest timer during an active workout for a specified duration.
- `Intents/RestTimer/PauseRestTimerIntent.swift`: pauses the running rest timer.
- `Intents/RestTimer/ResumeRestTimerIntent.swift`: resumes the paused rest timer.
- `Intents/RestTimer/StopRestTimerIntent.swift`: stops the active rest timer.
- `Intents/Workout/ViewLastWorkoutIntent.swift`: opens the app to the last completed workout (errors if none).
- `Intents/Workout/ShowWorkoutHistoryIntent.swift`: opens the app to the workouts list.
- `Intents/Template/ShowTemplatesListIntent.swift`: opens the app to the templates list.
- `Intents/Workout/LastWorkoutSummaryIntent.swift`: spoken response with last workout info (no app open).
- `Intents/Template/WorkoutTemplateEntity.swift`: AppEntity wrapper for template selection in Shortcuts.
- `Intents/Exercise/ExerciseEntity.swift`: AppEntity wrapper for exercise selection in Shortcuts.
- `Intents/VillainArcShortcuts.swift`: registers all intents with Siri phrases.

**Note:** App Intents are defined in the main app target (not an extension) to avoid provisioning issues without a paid Apple Developer account. Keep the App Shortcuts list capped at 10 (comment out extras in `Intents/VillainArcShortcuts.swift`).

## Project Structure & File Guide
- `Root/VillainArcApp.swift`: app entry, model container setup, App Shortcut parameter refresh, Spotlight continuation routing.
- `Views/ContentView.swift`: latest workout summary, start/resume flow, navigation to `RecentWorkoutSectionView`.
- `Views/Components/RecentWorkoutSectionView.swift`: shows the most recent completed workout or empty state plus a link to `WorkoutsListView`.
- `Views/Components/RecentTemplatesSectionView.swift`: shows recent templates and a link to `TemplatesListView`.
- `Views/WorkoutsListView.swift`: completed workout history list and bulk delete.
- `Views/Template/TemplatesListView.swift`: lists saved workout templates.
- `Views/Template/TemplateView.swift`: editor for creating or editing a workout template.
- `Views/Template/TemplateDetailView.swift`: details view for a template with start/edit actions.
- `Views/Workout/WorkoutView.swift`: session UI, list vs paging, save/delete flows, plus sheets for add/edit/rest timer settings.
- `Views/Workout/WorkoutDetailView.swift`: completed workout details with start/edit/delete actions.
- `Views/Components/WorkoutRowView.swift`: compact row card for a workout throughout lists and sections, now with shared accessibility helpers.
- `Views/Components/TemplateRowView.swift`: row view for a workout template.
- `Views/Workout/WorkoutSettingsView.swift`: workout settings sheet with finish/delete actions and accessibility-aware toolbar/button flow.
- `Views/Workout/ExerciseView.swift`: per-exercise editing, prior-set lookup, notes, rep/rest editors, and embedded set rows.
- `Views/Components/ExerciseSetRowView.swift`: edit reps/weight/type, toggle completion, and launch rest timers; now exposes accessibility identifiers/hints.
- `Views/Workout/RepRangeEditorView.swift`: rep range editor sheet with confirm/cancel actions.
- `Views/Workout/RestTimeEditorView.swift`: rest time editor sheet, mode selection, and duration slider rows.
- `Data/Classes/RestTimerState.swift`: observable rest timer state with persistence and shared singleton access.
- `Views/Workout/RestTimerView.swift`: rest timer sheet for start/pause/stop and countdown display.
- `Views/Components/TimerDurationPicker.swift`: tick-based duration slider for rest time picking with VoiceOver adjustable support.
- `Views/Workout/AddExerciseView.swift`: exercise picker, search, muscle filters, and accessible toolbar flows.
- `Views/Workout/FilteredExerciseListView.swift`: catalog filtering and selection UI with accessible row metadata and empty states.
- `Views/Workout/MuscleFilterSheetView.swift`: sheet with chip-based muscle filters, clear/close/confirm actions.
- `Views/Components/Navbar.swift`: shared inline-large title + reusable close button used by the custom nav bars across sheets.
- `Helpers/Accessibility.swift`: centralized identifiers/labels for workout flows, lists, sheets, and editors.
- `Helpers/KeyboardDismiss.swift`: shared keyboard dismissal helper.
- `Helpers/Haptics.swift`: reusable UIKit haptics helper for impact/selection/notifications.
- `Helpers/TimeFormatting.swift`: shared date/time formatting helpers.
- `Data/Models/Workout.swift`: workout model, ordering helpers, Spotlight summary text.
- `Data/Models/WorkoutExercise.swift`: per-workout exercise state and set helpers.
- `Data/Models/ExerciseSet.swift`: set data (type, reps, weight, complete).
- `Data/Models/WorkoutTemplate.swift`: template model containing exercises and sets, Spotlight summary text.
- `Data/Models/TemplateExercise.swift`: exercise within a template.
- `Data/Models/TemplateSet.swift`: set configuration within a template.
- `Data/Models/Exercise.swift`: catalog exercise, aliases, `lastUsed` tracking.
- `Data/Models/ExerciseSetType.swift`: set type labels, short codes, tint colors.
- `Data/Models/RestTimeHistory.swift`: global rest time history entries with last-used tracking.
- `Data/Models/RestTimePolicy.swift`: rest timing policy and per-type defaults.
- `Data/Models/RepRangePolicy.swift`: rep target class and display text, rep range mode.
- `Data/Models/Muscle.swift`: muscle enum, `isMajor`, `allMajor`.
- `Data/Models/ExerciseCatalog.swift`: exercise catalog entries, aliases, and muscle-target mapping.
- `Data/Classes/DataManager.swift`: seeds/syncs catalog using `UserDefaults` versioning and keeps Spotlight exercise entries updated.
- `Data/Classes/SpotlightIndexer.swift`: Core Spotlight indexing/removal for workouts, templates, and exercises.
- `Data/SampleData.swift`: sample workouts/sets and preview container helper.
- `Data/AI_USAGE.md`: AI usage log.
- `Data/Assets.xcassets`: app icons and accent color.

## Build, Test, and Development Commands
- Xcode: open `../VillainArc.xcodeproj`, Product > Run/Test.
- CLI build: `xcodebuild -project ../VillainArc.xcodeproj -scheme VillainArc -destination 'platform=iOS Simulator,name=iPhone 15' build`.

## Coding Style & Naming Conventions
- 4-space indentation; follow Xcode's default formatting.
- `PascalCase` types, `lowerCamelCase` properties/functions.
- File names match primary type (e.g., `WorkoutView.swift` -> `WorkoutView`).

## Testing Guidelines
- No automated test targets in this repo.
- Use SwiftUI previews with `sampleDataConainer()` for completed workouts and `sampleDataContainerIncomplete()` for in-progress flows.


## Data & AI Usage Notes
- When adding exercises, update `ExerciseCatalog` and bump `ExerciseCatalog.catalogVersion` so `DataManager` re-syncs.
- Log AI help in `Data/AI_USAGE.md` only when the user approves.
- Accessibility and testing: every new view/sheet/action should push accessibility metadata at the same time.
  - Use `Helpers/Accessibility.swift` for shared identifiers/text and give key controls explicit `accessibilityIdentifier`, `accessibilityLabel`, `accessibilityHint`, or trait overrides.
  - Keep the custom `navBar`/`CloseButton` in `Views/Components/Navbar.swift` fully labeled so any sheet inherits the same semantics.
  - When wiring new flows, call out identifiers in the relevant view and worksheet (e.g., add identifier hints to modals, lists, buttons, and helper rows) before relying on UI automation.

# Repository Guidelines

## Project Overview
VillainArc is a SwiftUI iOS workout tracker using SwiftData. Workouts contain ordered exercises with sets, backed by a seeded exercise catalog.

## Architecture Overview
- `Root/VillainArcApp.swift` builds the SwiftData model container and launches `ContentView`.
- `Views/ContentView.swift` loads workouts, seeds the catalog via `DataManager`, and presents `WorkoutView`.
- `Views/Workout/WorkoutView.swift` coordinates session UI and add/delete/move actions on exercises.
- `Views/Workout/ExerciseView.swift` queries previous completed sets and edits notes/sets.

## Project Structure & File Guide
- `Root/VillainArcApp.swift`: app entry, model container setup.
- `Views/ContentView.swift`: workout list, start/resume, navigation to `WorkoutView`.
- `Views/Workout/WorkoutView.swift`: session UI, list vs paging, save/delete flows.
- `Views/Workout/ExerciseView.swift`: per-exercise editing, prior-set lookup, notes.
- `Views/Workout/ExerciseSetRowView.swift`: edit reps/weight/type, toggle completion.
- `Views/Workout/RepRangeEditorView.swift`: rep range editor sheet with confirm/cancel actions.
- `Views/Workout/RestTimeEditorView.swift`: rest time editor sheet and mode selection.
- `Views/Workout/AddExerciseView.swift`: exercise picker, search, muscle filters.
- `Views/Workout/FilteredExerciseListView.swift`: catalog filtering and selection UI.
- `Data/Models/Workout.swift`: workout model, ordering helpers.
- `Data/Models/WorkoutExercise.swift`: per-workout exercise state and set helpers.
- `Data/Models/ExerciseSet.swift`: set data (type, reps, weight, complete).
- `Data/Models/Exercise.swift`: catalog exercise, `lastUsed` tracking.
- `Data/Models/ExerciseSetType.swift`: set type labels, short codes, tint colors.
- `Data/Models/RestTimePolicy.swift`: rest timing policy and per-type defaults.
- `Data/Models/RepRangePolicy.swift`: rep target class and display text, rep range mode.
- `Data/Models/Muscle.swift`: muscle enum, `isMajor`, `allMajor`.
- `Data/Models/ExerciseDetails.swift`: catalog entries and muscle-target mapping.
- `Data/DataManager.swift`: seeds catalog using `UserDefaults` versioning.
- `Data/SampleData.swift`: sample workouts/sets and preview container helper.
- `Data/AI_USAGE.md`: AI usage log.
- `Data/Assets.xcassets`: app icons and accent color.
- `Haptics.swift`: reusable UIKit haptics helper for impact/selection/notifications.

## Build, Test, and Development Commands
- Xcode: open `../VillainArc.xcodeproj`, Product > Run/Test.
- CLI build: `xcodebuild -project ../VillainArc.xcodeproj -scheme VillainArc -destination 'platform=iOS Simulator,name=iPhone 15' build`.

## Coding Style & Naming Conventions
- 4-space indentation; follow Xcode's default formatting.
- `PascalCase` types, `lowerCamelCase` properties/functions.
- File names match primary type (e.g., `WorkoutView.swift` -> `WorkoutView`).

## Testing Guidelines
- No automated test targets in this repo.
- Use SwiftUI previews with `sampleDataConainer()` for UI checks.


## Data & AI Usage Notes
- When adding exercises, update `ExerciseDetails` and ensure `DataManager` seeding still covers new items.
- Log AI help in `Data/AI_USAGE.md` only when the user approves.

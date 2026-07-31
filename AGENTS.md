# AGENTS.md — Villain Arc

Standing instructions for any agent working in this repo. Pointers only: read the file named, don't assume its contents.

- **This is a two-state repo — name which branch you're on before reading or changing anything.** `main` is the shipped pre-iOS-27 line (1.3, App-Store-submittable on a release Xcode); the **`ios27` branch** holds the 1.4 line (the FM assistant, SpotlightSearchTool, IntentExecutionPolicies). A survey reading only `main` wrongly concludes the iOS-27 work doesn't exist.
- **Read first: [`VillainArc/Documentation/PROJECT_GUIDE.md`](VillainArc/Documentation/PROJECT_GUIDE.md)**, then the flow doc for the area (`SESSION_LIFECYCLE_FLOW`, `HEALTHKIT_INTEGRATION`, `PLAN_EDITING_FLOW`, …). Intent coverage: `APP_INTENTS_AUDIT.md`, same folder.
- **Structure is pre-Kit-package:** all code lives in the app target — no `Package.swift`, no FCTFoundation. That's context, not something to fix.
- **Build with a CONCRETE arm64 sim destination** (`-destination 'platform=iOS Simulator,name=iPhone 17 Pro'`), never `generic/platform=iOS Simulator` — the x86_64 slice fails on cross-import overlays (`AskVillainArcAssistant.swift`).
- **The widget extension is NOT a synchronized group** — every new file under `Data/` it compiles against (schema versions, shared config types, any entity `SpotlightIndexer` references) must be added to its exception set in `project.pbxproj`, or the widget target silently breaks.
- **HealthKit: read `HEALTHKIT_INTEGRATION.md` first, and never "fix" the deprecated `HKWorkout` initializer by adopting `HKWorkoutBuilder.finishWorkout`** — it writes real workouts into the user's actual HealthKit store; the warning-silencing shim pattern is in `~/Jarvis/skills/apple-development/references/gotchas.md`.
- **The production CloudKit schema is deployed: additive-only, permanent.** A schema change follows the freeze-and-version workflow in the workspace learnings; a preference that doesn't need sync goes in App-Group `UserDefaults`, never the `AppSettings` model.
- The full map (release-SDK ship path, signing, sim seeding, dead-end backlog items): `~/Jarvis/projects/portfolio/villain-arc/learnings.md`.

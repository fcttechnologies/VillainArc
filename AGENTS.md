# VillainArc — Agent Instructions

## Project Documentation

Before making changes, read the relevant documentation:

- **`VillainArc/Documentation/PROJECT_GUIDE.md`** — Start here. Conceptual overview, user flows, architecture diagram, and a feature→file map covering every major area of the app. If you need to find where a feature lives or debug something, this is the first file to read.
- **`VillainArc/Documentation/ARCHITECTURE.md`** — Full file-by-file index of every Swift source file in the project with purpose, dependencies, and key behaviors.
- **`VillainArc/Documentation/WORKOUT_PLAN_SUGGESTION_FLOW.md`** — Deep dive into the suggestion engine lifecycle (generation, review, outcome resolution). Read this before touching anything in `Data/Services/Suggestions/`.

## Keep Documentation Updated

When you make architectural changes — adding files, moving files, changing folder structure, adding models, changing key behaviors — update the relevant documentation file. Small implementation changes don't need doc updates; structural changes do.

## Key Conventions

- Navigation via `AppRouter.shared` (singleton, `@Observable`) — never push views directly
- SwiftData direct in views: `@Query` reads, `@Bindable` writes, `saveContext()`/`scheduleSave()` for persistence
- Plan editing uses the copy-merge pattern — never edit originals directly
- One active flow at a time enforced by `AppRouter.hasActiveFlow()`

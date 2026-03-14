# AI Usage

## Approach

AI is used as a collaborator on specific, bounded tasks — not as an autonomous builder. The division is intentional:

- **I own**: architecture decisions, product behavior, data model design, user experience, code review, and understanding of every line shipped.
- **AI assists with**: research and API discovery, generating boilerplate once a pattern is established, exhaustive list generation, surfacing edge cases I might miss, and writing documentation.

The test I apply: if I couldn't explain a piece of code in a code review or debug it under pressure, it shouldn't ship. AI output always gets reviewed and often rewritten before it goes in.

---

## Usage Log

### Architecture Research — SwiftData + CloudKit
- **What AI did**: Compared persistence options (Core Data, SwiftData, GRDB) and surfaced CloudKit sync gotchas (app-group stores, schema migration constraints, CloudKit container setup).
- **What I decided**: SwiftData with CloudKit backing via a shared app-group store, with awareness of its migration limitations. The schema design and model relationships are mine.

### Exercise Catalog Architecture
- **What AI did**: Listed trade-offs between embedding catalog data in code vs seeding from a bundle file vs fetching remotely.
- **What I decided**: Seed from code on first launch with a catalog hash to detect updates, deduplicate by `catalogID`. AI surfaced the rename/reclassification edge case; I designed the deduplication logic.

### Exercise Seeding + iCloud Timing
- **What AI did**: Helped think through race conditions between CloudKit initial sync and local seeding — specifically the case where a returning user on a new device might get duplicate catalog entries.
- **What I decided**: Check for existing entries before seeding, gate seeding behind CloudKit readiness. My logic, AI helped stress-test it.

### RepRange Data Type Design
- **What AI did**: Laid out pros and cons of modeling rep ranges as a class, enum, struct, or embedded value. Helped me think through what query patterns I'd need.
- **What I decided**: Chose the embedded policy approach (`RepRangePolicy`) that fits SwiftData's relationship model without unnecessary object overhead.

### Suggestion Engine Design
- **What AI did**: Helped document the rule structure and walked through edge cases in outcome evaluation (rejected-but-followed suggestions, same-session evaluation guard, snapshot-based prescription reconstruction).
- **What I decided**: The closed-loop architecture (generation → review → outcome → learning signal), the event-first grouped suggestion model, the set-level plus exercise-level rule split, and the AI/deterministic merge strategy are product decisions I designed. AI helped formalize the documentation once the design was stable.

### App Intents + Siri Integration
- **What AI did**: API reference for App Intents lifecycle, `@AppShortcutsProvider`, entity resolution, and Live Activity intent patterns — areas where the Apple docs are sparse.
- **What I decided**: Which intents to expose, how to organize them, when to donate, and the interaction model between Siri and the active workout session.

### Live Activities
- **What AI did**: Explained `ActivityKit` lifecycle (start/update/end), the `ActivityAttributes` + `ContentState` split, and lock screen widget layout constraints.
- **What I decided**: What state to surface on the lock screen, the interaction design (complete set, add exercise, pause timer from lock screen), and the data model.

### Accessibility Instrumentation
- **What AI did**: Applied `accessibilityIdentifier`, `accessibilityLabel`, and `accessibilityHint` across workout flows once I established the naming convention and coverage goals.
- **What I decided**: The identifier naming scheme (`AccessibilityIdentifiers` enum), which controls need labels vs hints vs both, and the coverage standard.

### Muscle Enum + Exercise Data
- **What AI did**: Generated the exhaustive `Muscle` enum (43 variants) and helped fill out muscle targeting for catalog exercises — tedious list work.
- **What I decided**: The taxonomy, grouping into major/minor muscles, and which muscles map to which exercises. I reviewed and corrected the catalog entries.

### Sample Data
- **What AI did**: Generated varied `SampleData.swift` fixture data for development and UI previews.
- **What I decided**: The data shapes, edge cases to cover (empty states, long names, PRs, incomplete workouts), and which previews need live data vs static fixtures.

### iOS API Research
- **What AI did**: Quick lookup for SwiftUI modifiers, NavigationStack patterns, SwiftData `@Query` predicate syntax, and CoreSpotlight indexing APIs.
- **What I decided**: How these APIs fit into the app's existing patterns. API research doesn't change the architecture — it just saves time reading documentation.

### Weight and Height Unit System
- **What AI did**: Propagated the unit system across ~20 files once the design was established — `WeightUnit`/`HeightUnit` enums, display/input conversion sites, rule engine threshold recalibration, Live Activity unit passing, and test assertion updates.
- **What I decided**: Canonical kg storage with conversion only at display/input boundaries, enum storage on `AppSettings`, the Live Activity strategy for passing units without SwiftData access, and which rule thresholds to recalibrate.

### Codebase Documentation
- **What AI did**: Generated `PROJECT_GUIDE.md`, `ARCHITECTURE.md`, and `SUGGESTION_AND_OUTCOME_FLOW.md` by reading the full codebase and synthesizing it. Also caught discrepancies between docs and actual code behavior.
- **What I decided**: The documentation structure, what an AI agent needs to be useful on this codebase, and which discrepancies to fix. I reviewed every section for accuracy.


---

## What AI Doesn't Do Here

- Write features autonomously without a clear spec from me
- Make product decisions (what to build, what behavior users should see)
- Review its own output — I do that
- Touch the suggestion engine rules without me understanding the behavioral change
- Commit or deploy anything

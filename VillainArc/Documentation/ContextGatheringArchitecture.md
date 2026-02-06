# Context Gathering Architecture

## Purpose

Describes how workout context is gathered and provided to both rule-based and AI suggestion systems.

---

## Current Implementation (Feb 2026)

### Rule-Based Suggestions

Rules receive context through `ExerciseSuggestionContext` struct:
- `session: WorkoutSession` - Current workout session
- `performance: ExercisePerformance` - What user just performed
- `prescription: ExercisePrescription` - What user was supposed to do
- `history: [ExercisePerformance]` - Last 3 performances for this exercise
- `historySummary: ExerciseHistory?` - Cached aggregate stats
- `plan: WorkoutPlan` - The workout plan being followed
- `resolvedTrainingStyle: TrainingStyle` - Heuristic style with AI fallback when unknown
- `inferredRepRangeCandidate: RepRangeCandidateKind?` - Inferred rep range when prescription is not set

**Location**: `VillainArc/Data/Classes/Suggestions/SuggestionGenerator.swift`
**How**: Context built per exercise, passed directly to `RuleEngine.evaluate()`

### AI Suggestions

AI receives context through `AIExerciseSuggestionInput` struct:
- `catalogID: String` - Exercise identifier
- `exerciseName: String` - Display name
- `primaryMuscle: String` - Primary muscle targeted
- `prescription: AIExercisePrescriptionSnapshot` - Target sets/reps/rest
- `performance: AIExercisePerformanceSnapshot` - Actual sets/reps/rest with ISO 8601 date string

**Location**: `VillainArc/Data/Classes/Suggestions/AISuggestionGenerator.swift`
**How**: Snapshots created from domain models, passed directly in prompt

**Additional Context (on-demand via tools)**:
- `getExerciseHistoryContext` - Returns cached aggregate stats
- `getRecentExercisePerformances` - Returns last N detailed performances

---

## Context Sources

### 1. ExerciseHistory (Cached Aggregates)

**What**: Pre-computed statistics across ALL completed sessions for an exercise
**Model**: `VillainArc/Data/Models/Exercise/ExerciseHistory.swift`
**Updater**: `VillainArc/Data/Classes/ExerciseHistoryUpdater.swift`
**When Updated**: After workout completion, workout deletion, or manual rebuild

**Contains**:
- Session counts (total, last 30 days)
- PRs (best 1RM, best weight, best volume, best reps at weight)
- Recent averages (last 3 sessions: weight, volume, set count, rest)
- Typical patterns (set count, rep range, rest time)
- Progression trend (improving, stable, declining, insufficient)
- Progression points (last 10 sessions for charting)

**Access**:
- Rules: Passed as `historySummary` in context
- AI: Available via `getExerciseHistoryContext` tool

### 2. ExercisePerformance (Detailed History)

**What**: Individual workout performances with set-by-set data
**Model**: `VillainArc/Data/Models/Sessions/ExercisePerformance.swift`
**Query**: `ExercisePerformance.matching(catalogID:)` with fetch limit

**Contains** (per performance):
- Date of workout (stored as Date, serialized as ISO 8601 for AI snapshots)
- Sets performed (weight, reps, rest per set)
- Rep range configuration at time of workout
- Rest time policy at time of workout
- Notes and muscle targets

**Access**:
- Rules: Last 3 fetched and passed as `history` array
- AI: Available via `getRecentExercisePerformances` tool (max 5)

### 3. ExercisePrescription (Current Target)

**What**: What user is supposed to do for this exercise
**Model**: `VillainArc/Data/Models/Plans/ExercisePrescription.swift`

**Contains**:
- Sets with targets (weight, reps, rest per set)
- Rep range configuration (mode, bounds, target)
- Rest time policy (mode, seconds)
- Notes and muscle targets

**Access**:
- Rules: Passed directly in context
- AI: Converted to `AIExercisePrescriptionSnapshot`, passed in prompt

### 4. ExercisePerformance (Current Session)

**What**: What user actually did in current session
**Model**: `VillainArc/Data/Models/Sessions/ExercisePerformance.swift`

**Contains**:
- Completed sets (weight, reps, rest per set)
- Rep range used
- Rest time policy used
- Date of performance (stored as Date, serialized as ISO 8601 for AI snapshots)

**Access**:
- Rules: Passed directly in context
- AI: Converted to `AIExercisePerformanceSnapshot`, passed in prompt

---

## AI Tools Implementation

**Location**: `VillainArc/Data/Classes/Suggestions/AISuggestionTools.swift`

### Tool 1: ExerciseHistoryContextTool

**Name**: `getExerciseHistoryContext`
**Purpose**: Fetch cached aggregate statistics
**Arguments**: `catalogID: String`
**Returns**: `AIExerciseHistoryContext`

**When AI uses**:
- Needs PRs to compare against current performance
- Needs progression trend (improving/stable/declining)
- Needs typical patterns to understand what's normal for this exercise
- Wants token-efficient summary vs detailed history

**Implementation**:
- Fetches `ExerciseHistory` by catalogID from SwiftData
- Converts to `AIExerciseHistoryContext` snapshot
- Returns empty/default struct if no history exists

### Tool 2: RecentExercisePerformancesTool

**Name**: `getRecentExercisePerformances`
**Purpose**: Fetch detailed set-by-set history
**Arguments**: `catalogID: String`, `limit: Int` (max 5)
**Returns**: `[AIExercisePerformanceSnapshot]`

**When AI uses**:
- Needs set-by-set progression data
- Analyzing plateaus or regression patterns
- Checking consistency vs variability
- Understanding recency (gaps between sessions)

**Implementation**:
- Fetches last N `ExercisePerformance` records by catalogID
- Limits to 5 max for token efficiency
- Converts each to `AIExercisePerformanceSnapshot`
- Sorted most recent first

---

## Data Flow Summary

### Rule-Based Flow

```
SuggestionGenerator
    ↓
Fetch history (last 3 performances)
Fetch historySummary (ExerciseHistory)
    ↓
Build ExerciseSuggestionContext
    ↓
RuleEngine.evaluate(context)
    ↓
PrescriptionChange[]
```

### AI Flow

```
AISuggestionGenerator
    ↓
Check model availability
    ↓
Build AIExerciseSuggestionInput
(includes prescription + performance snapshots)
    ↓
LanguageModelSession with tools
    ↓
AI may call:
  - getExerciseHistoryContext (for summary stats)
  - getRecentExercisePerformances (for detailed history)
    ↓
AI generates suggestions
    ↓
Map to PrescriptionChange[]
```

---

## Why This Architecture

### Direct Pass vs Provider Pattern

**Prescription/Performance**: Passed directly because they're always needed upfront
- Rules need them immediately for all logic
- AI needs them in every prompt for context
- No benefit to lazy loading

**Exercise History**: Available via tool for AI because:
- Not all suggestions need historical context
- Token budget savings when not needed
- AI can request on-demand when relevant
- Rules get it passed directly (no async needed)

### Snapshot Conversion

**Why**: Domain models are mutable (SwiftData), AI models require immutable (@Generable)
**Where**: Conversion happens in generators before passing to rules/AI
**Benefit**: Clean separation, no pollution of domain models

### Tool Descriptions

Comprehensive descriptions guide AI on:
- When to use each tool
- What data each tool provides
- Best practices (token efficiency, limits)
- Trade-offs between tools

---

## Key Files Reference

- **Models**:
  - `VillainArc/Data/Models/Exercise/ExerciseHistory.swift`
  - `VillainArc/Data/Models/Sessions/ExercisePerformance.swift`
  - `VillainArc/Data/Models/Plans/ExercisePrescription.swift`

- **Generators**:
  - `VillainArc/Data/Classes/Suggestions/SuggestionGenerator.swift`
  - `VillainArc/Data/Classes/Suggestions/AISuggestionGenerator.swift`

- **AI Structures**:
  - `VillainArc/Data/Classes/Suggestions/AISuggestionModels.swift`
  - `VillainArc/Data/Classes/Suggestions/AISuggestionTools.swift`

- **Updaters**:
  - `VillainArc/Data/Classes/ExerciseHistoryUpdater.swift`

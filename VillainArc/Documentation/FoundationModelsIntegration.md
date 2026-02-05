# AI Suggestion Generation Architecture

## Overview

VillainArc uses Apple's FoundationModels framework (iOS 26+) for on-device AI suggestion generation. This document describes the architecture, data flow, and rationale for the dual-source suggestion system.

**Status**: Implemented with tool calling enabled

---

## Architecture

### Design Philosophy

1. **Rules as baseline**: Deterministic, explainable, always work (even offline/pre-iOS-26)
2. **AI as enhancement**: Handle nuanced cases, provide alternative perspectives
3. **Dual-source tagging**: All suggestions tagged `.rules` or `.ai` for comparison
4. **Graceful degradation**: AI failures don't break suggestion generation

### High-Level Flow

```
WorkoutSummaryView
    ↓
SuggestionGenerator.generateSuggestions()
    ↓
    ├─→ RuleEngine.evaluate()              [source: .rules]
    └─→ AISuggestionGenerator.suggest()     [source: .ai]
    ↓
SuggestionDeduplicator.process()
    ↓
PrescriptionChange[] (saved to SwiftData)
```

**Key point**: Both sources run independently. If AI fails, rules still produce suggestions.

---

## Implementation Components

### 1. AI Models (`AISuggestionModels.swift`)

**Purpose**: Define all @Generable structures for type-safe AI input/output

**Key structures**:
- `AIExerciseSuggestionInput` - Per-exercise context sent to AI
  - Includes: catalogID, exercise name, primary muscle, prescription snapshot, performance snapshot
  - Primary muscle enables volume/recovery reasoning
  - Performance includes an ISO 8601 date string for recency analysis

- `AIExercisePrescriptionSnapshot` - What user is supposed to do
  - Set-by-set targets (weight, reps, rest)
  - Rep range configuration (mode, bounds, target)
  - Rest time policy

- `AIExercisePerformanceSnapshot` - What user actually did
  - Includes workout date (ISO 8601 string) for temporal reasoning
  - Set-by-set actuals (weight, reps, rest)
  - Only completed sets included

- `AIExerciseHistoryContext` - Cached aggregate stats
  - PRs, trends, recent averages, typical patterns
  - Returned by `getExerciseHistoryContext` tool

- `AISuggestionOutput` / `AISuggestion` - AI's response format
  - 0-5 suggestions per exercise
  - Each has: changeType, newValue, targetSetIndex (-1 for exercise-level), reasoning

**Why separate structs**: 
- Domain models use `var` (mutable for SwiftData)
- @Generable requires `let` (immutable)
- Snapshot conversion happens once per exercise

**Why AI-readable enums**:
- Uses semantic strings ("Warm Up Set", "Target", "Range") instead of ints
- Easier for model to understand context
- Examples: `AIExerciseSetType`, `AIRepRangeMode`, `AIRestTimeMode`

### 2. AI Tools (`AISuggestionTools.swift`)

**Purpose**: Provide on-demand context lookup for AI reasoning

**Tool 1: `ExerciseHistoryContextTool`**
- Returns: `AIExerciseHistoryContext` with cached aggregate stats
- When AI should use: Need PRs, progression trends, typical patterns
- Why: Token-efficient (pre-summarized), fast lookup
- Data source: `ExerciseHistory` model (one per catalogID)

**Tool 2: `RecentExercisePerformancesTool`**
- Returns: Last N `AIExercisePerformanceSnapshot` (max 5, sorted recent-first)
- When AI should use: Need set-by-set detail, checking for plateaus/variability
- Why: Detailed history when summary stats insufficient
- Data source: `ExercisePerformance` models filtered by catalogID

**Tool descriptions**: Both include comprehensive guidance on when/how to use them to guide AI reasoning

### 3. AI Generator (`AISuggestionGenerator.swift`)

**Purpose**: Orchestrate AI model calls and convert output to domain models

**Main function**: `generateSuggestions(for session: WorkoutSession) -> [PrescriptionChange]`

**Flow**:
1. For each exercise in session:
   - Build `AIExerciseSuggestionInput` from prescription + performance
   - Create `LanguageModelSession` with tools and instructions
   - Send prompt with input, receive `AISuggestionOutput`
   - Map AI suggestions → `PrescriptionChange` domain models
   - Tag all changes with `.ai` source
2. Return all changes for deduplication

**Key mapping logic**:
- `AIChangeType` → `ChangeType` (domain enum)
- Exercise-level vs set-level determination (targetSetIndex == -1 or >= 0)
- Value normalization (plate rounding for weight, int conversion for reps/rest)
- Validation (prevent duplicates, verify set indices exist)

**Error handling**: Try-catch around AI calls, failures logged but don't break flow

### 4. Integration Point (`SuggestionGenerator.swift`)

**Purpose**: Coordinate dual-source suggestion generation

**Note**: This file also contains rule-based generation logic, but AI integration is separate

**AI integration** (lines ~18-58 in `generateSuggestions()`):
- Checks iOS 26+ availability
- Builds input from exercise performance + prescription
- Calls `AISuggestionGenerator.generateSuggestions()`
- Appends AI suggestions to combined pool for deduplication

**Deduplication**: `SuggestionDeduplicator.process()` handles conflicts/cooldowns across both sources

---

## Data Flow Detail

### Suggestion Generation Trigger

**Where**: `WorkoutSummaryView` (after user finishes workout)
**When**: User taps "Finish" and confirms summary
**What happens**:
1. `SuggestionGenerator.generateSuggestions(for: session)` called
2. Both rules and AI run per exercise
3. Results saved to SwiftData as `PrescriptionChange`
4. User reviews in `SuggestionReviewView`

### Per-Exercise AI Call

**Input preparation**:
- Extract primary muscle from prescription (first in musclesTargeted array)
- Create prescription snapshot (sets, rep range, rest policy)
- Create performance snapshot (completed sets only, includes workout date)
- Package into `AIExerciseSuggestionInput`

**AI reasoning**:
- Receives input + tool access
- May call `getExerciseHistoryContext` for trend/PR context
- May call `getRecentExercisePerformances` for detailed progression
- Generates 0-5 suggestions with reasoning

**Output processing**:
- Map `AISuggestion` → `PrescriptionChange`
- Normalize values (weights rounded to plates, reps/rest as integers)
- Link to appropriate target (SetPrescription or ExercisePrescription)
- Store previous value for comparison
- Validate (no duplicate changes, indices valid)

### Context Cleared Between Exercises

**Why**: Token budget management
- On-device models have ~4-8k token windows
- Each exercise is independent call (no cross-exercise memory)
- Allows deeper per-exercise reasoning without running out of tokens

---

## Token Budget Strategy

### Current Budget (per exercise)

- **Initial prompt**: ~400-600 tokens
  - Instructions (~200 tokens)
  - Exercise input (~200-400 tokens)
  - Tool descriptions (~100 tokens)

- **Tool calls** (optional, on-demand): ~200-800 tokens each
  - History context: ~300-500 tokens
  - Recent performances: ~400-800 tokens (depends on N)

- **Output**: ~200-500 tokens
  - 0-5 suggestions with reasoning

- **Typical total**: 800-2000 tokens (well within 4-8k window)

### Token Efficiency Techniques

1. **Use cached aggregates first**: `ExerciseHistoryContext` provides PRs/trends without fetching raw performances
2. **Adaptive tool use**: AI only calls tools when needed (not upfront)
3. **Clear context per exercise**: No accumulation across exercises
4. **Limit suggestions**: Max 5 per exercise prevents unbounded output

---

## Why This Architecture

### Dual Sources

**Problem**: Rule-based systems handle common cases well but struggle with edge cases
**Solution**: AI provides nuanced reasoning while rules ensure baseline coverage
**Benefit**: Can compare quality over time via source tags, gradually trust AI more

### Tool Calling vs Upfront Context

**Problem**: Sending all possible context upfront wastes tokens
**Solution**: AI requests context on-demand via tools
**Benefit**: 
- Simple cases use ~800 tokens (no tool calls)
- Complex cases use ~2000 tokens (with tool calls)
- Adaptive complexity based on need

### Immutable Snapshots

**Problem**: Domain models are mutable (SwiftData), @Generable requires immutable
**Solution**: Create separate snapshot structs, convert once per exercise
**Benefit**: Clean separation, no pollution of domain models

### Source Tagging

**Problem**: Can't evaluate AI quality if can't identify which suggestions came from AI
**Solution**: Tag all `PrescriptionChange` with source (.rules or .ai)
**Benefit**: Can filter in UI, track accept/reject rates per source, improve system

---

## Future Enhancements

### Potential Additional Tools

1. **Cross-Exercise Comparison**
   - Compare progression across similar exercises (e.g., all chest work)
   - Identify muscle-specific vs exercise-specific plateaus
   - Example: "Bench stalled but overhead press progressing → check bench form"

2. **Workout-Level Volume Analysis**
   - Analyze total volume/fatigue across all exercises in session
   - Detect volume spikes or excessive fatigue
   - Example: "Volume up 40% this week → consider reducing"

3. **Periodization Context**
   - Understand training phase/cycle position
   - Suggest deloads or intensity changes based on long-term plan
   - Example: "8 weeks of linear progression → due for deload"

### What Current Implementation Handles

- ✅ Progressive overload decisions (performance vs targets)
- ✅ Historical context (trends: improving/stable/declining)
- ✅ Recency awareness (recent plateau vs long-term progression)
- ✅ Set-specific suggestions (e.g., "increase weight on working sets only")
- ✅ Adaptive reasoning depth (tools used only when needed)

### What Future Tools Enable

- ❌ Cross-exercise comparisons
- ❌ Workout-level fatigue analysis
- ❌ Periodization-aware suggestions

---

## Testing & Validation

### Unit Testing
- Test snapshot conversion (`init(from:)` helpers)
- Test value normalization (plate rounding, int conversion)
- Test change mapping (AIChangeType → ChangeType)
- Mock AI responses for deterministic tests

### Integration Testing
- Test dual-source flow (rules + AI both run)
- Test AI failure doesn't break generation
- Test deduplication with mixed sources
- Test source tagging persists correctly

### Device Testing
**Required**: FoundationModels only works on actual devices (iOS 26+)
- Test with real workout data
- Compare AI vs rules quality over 2-3 weeks
- Track accept/reject rates per source
- Monitor token usage and latency

### Success Metrics
- AI suggestion acceptance rate vs rules
- AI latency per exercise (target: <1 second)
- Token usage per call (target: <2000 tokens)
- User feedback on AI reasoning quality

---

## Implementation Status

### Completed ✅
- AI-readable enums with semantic strings
- Input/output structures with @Generable
- Two tools: history context + recent performances
- Generator with tool calling support
- Value normalization and validation
- Source tagging (.ai)
- Comprehensive tool descriptions

### Ready for Testing
- Integration with SuggestionGenerator dual-source flow
- Device testing with real workout data
- Quality comparison (AI vs rules over time)

### Future Work
- Optional UI filter to show AI vs rules separately
- Cross-exercise comparison tool
- Workout-level analysis tools
- Periodization context tools

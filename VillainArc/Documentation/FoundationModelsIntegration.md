# AI Configuration Inference (FoundationModels)

**Status**: Implemented using on-device `SystemLanguageModel`.

## 1. AI Models (`AISuggestionModels.swift`)

Defines `@Generable` structures for type-safe interactions with the model.

### Input
-   `AIInferenceInput`: The top-level container sent to the model.
-   `AIExercisePerformanceSnapshot`: A `Sendable` struct containing exercise data (date, sets, weight, reps, rest) derived from `ExercisePerformance`.
-   `AISetPerformanceSnapshot`: Detailed data for individual sets.

### Output
-   `AIInferenceOutput`: Wrapper for optional classifications.
-   `AIRepRangeClassification`:
    -   `mode`: `Target` or `Range`. **Note**: `untilFailure` is strictly excluded.
    -   `values`: `lowerRange`/`upperRange` or `targetReps`.
-   `AITrainingStyleClassification`: Enum matching `TrainingStyle` cases (e.g., `straightSets`, `ascendingPyramid`).

## 2. AI Tool (`AISuggestionTools.swift`)

**`RecentExercisePerformancesTool`**
-   **Function**: `getRecentExercisePerformances(catalogID: String, limit: Int)`
-   **Purpose**: Allows the model to request historical context if the current session provided in the prompt is ambiguous.
-   **Returns**: List of `AIExercisePerformanceSnapshot` for the last N sessions.

## 3. AI Inferrer (`AIConfigurationInferrer.swift`)

Orchestrates the session and model interaction.

-   **Function**: `infer(exerciseName:catalogID:primaryMuscle:performance:) -> AIInferenceOutput?`
-   **Concurrency**: Creates a **new** `LanguageModelSession` for every call, ensuring strict thread safety for parallel execution.
-   **Flow**:
    1.  Checks `SystemLanguageModel.default` availability.
    2.  Constructs `AIInferenceInput`.
    3.  Initializes `LanguageModelSession` with tools and instructions.
    4.  Sends prompt: "Classify the training style and rep range..."
    5.  Validates output (filters invalid ranges or impossible values).

## 4. Integration (`SuggestionGenerator.swift`)

AI inference is executed in the **Scatter Phase** of the suggestion pipeline.

### Parallel Execution
The generator uses a `TaskGroup` to run multiple inference tasks simultaneously:

```swift
// Gather Phase (Main Actor)
// Prepare Sendable snapshots
var aiRequests: [UUID: AIRequest] = [:]

// Scatter Phase (Background)
let aiResults = await withTaskGroup(of: (UUID, AIInferenceOutput?).self) { group in
    for (id, request) in aiRequests {
        group.addTask {
            // New session per task = Safe Parallelism
            let result = await AIConfigurationInferrer.infer(...)
            return (id, result)
        }
    }
}
```

### Usage Logic
AI is triggered for an exercise only if:
1.  **New Exercise**: `history.count < 10` (fetched with `limit: 10`).
2.  **Unknown Style**: Training style could not be detected heuristically.

The results are then passed to the `RuleEngine` to assist in generating suggestions.

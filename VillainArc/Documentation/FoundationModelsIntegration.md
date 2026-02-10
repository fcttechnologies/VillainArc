# Foundation Models Integration

**Status**: Implemented using on-device `SystemLanguageModel`.

VillainArc uses Foundation Models in two independent flows:

1. Configuration inference during suggestion generation.
2. Outcome inference during post-workout change evaluation.

## 1) Configuration Inference (Suggestion Generation)

### Models

File: `Data/Models/AIModels/AISuggestionModels.swift`

Primary types:

- `AIInferenceInput`
- `AIExercisePerformanceSnapshot`
- `AISetPerformanceSnapshot`
- `AIInferenceOutput`
- `TrainingStyle`

### Tooling

File: `Data/Classes/Suggestions/AITrainingStyleTools.swift`

- `RecentExercisePerformancesTool` allows the model to request additional recent history.

### Inferrer

File: `Data/Classes/Suggestions/AITrainingStyleClassifier.swift`

- Builds prompt + instructions.
- Starts a fresh `LanguageModelSession` per request.
- Validates returned classification.

### Runtime Integration

File: `Data/Classes/Suggestions/SuggestionGenerator.swift`

- AI requests are prepared on main actor.
- Inference runs in parallel via `TaskGroup`.
- AI output is used to supplement deterministic rules for unknown training style.

## 2) Outcome Inference (Change Outcome Resolution)

### Models

File: `Data/Models/AIModels/AIOutcomeModels.swift`

Primary types:

- `AIOutcome`
- `ChangeType`
- `AIOutcomeChange`
- `AIExercisePrescriptionSnapshot`
- `AISetPrescriptionSnapshot`
- `AIRestTimePolicy`
- `AIOutcomeGroupInput`
- `AIOutcomeInferenceOutput`

### Inferrer

File: `Data/Classes/Suggestions/AIOutcomeInferrer.swift`

- API: `infer(input: AIOutcomeGroupInput) async -> AIOutcomeInferenceOutput?`
- Uses `SystemLanguageModel.default` and per-call `LanguageModelSession`.
- Prompt asks model to classify one grouped change outcome as:
  - `Good`
  - `Too Aggressive`
  - `Too Easy`
  - `Ignored`

### Runtime Integration

File: `Data/Classes/Suggestions/OutcomeResolver.swift`

Flow:

1. Build grouped inputs (`OutcomeGroup`) by set/policy within exercise.
2. Run deterministic rule scoring per change.
3. Build one `AIOutcomeGroupInput` per group, including:
   - grouped changes (`previousValue` / `newValue`)
   - pre-change prescription snapshot
   - trigger performance snapshot
   - current performance snapshot
   - aggregated rule hint (`ruleOutcome`, `ruleConfidence`, `ruleReason`)
4. Execute group AI inference in parallel (`TaskGroup`).
5. Merge AI + rules per change:
   - AI override only when disagreement and `confidence >= 0.7`.

## 3) Safety and Execution Characteristics

- All inference is on-device (`FoundationModels` / `SystemLanguageModel`).
- If model is unavailable or inference fails, system falls back to deterministic logic.
- Each inference call uses a dedicated session to avoid cross-task session sharing during parallel work.
- Outputs are validated before use (confidence clamped, required fields checked).

## 4) File Map

- Config models: `Data/Models/AIModels/AISuggestionModels.swift`
- Config tools: `Data/Classes/Suggestions/AITrainingStyleTools.swift`
- Config inferrer: `Data/Classes/Suggestions/AITrainingStyleClassifier.swift`
- Config pipeline usage: `Data/Classes/Suggestions/SuggestionGenerator.swift`

- Outcome models: `Data/Models/AIModels/AIOutcomeModels.swift`
- Outcome inferrer: `Data/Classes/Suggestions/AIOutcomeInferrer.swift`
- Outcome pipeline usage: `Data/Classes/Suggestions/OutcomeResolver.swift`

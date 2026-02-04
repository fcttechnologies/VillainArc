# Foundation Models Integration Analysis

## Executive Summary

Apple's FoundationModels framework (introduced WWDC 2025, available iOS 26+, macOS 26+) provides a ~3B parameter on-device language model with two key features perfect for VillainArc's suggestion system:

1. **Guided Generation** - Type-safe structured output using `@Generable` macro
2. **Tool Calling** - Model can autonomously call Swift code to gather context

Our context gathering architecture aligns extremely well with Apple's Tool protocol design.

**V1 plan (VillainArc)**:
- One AI call **per exercise** after workout completion
- Input: prescription + performance snapshots for that exercise **plus** exercise history summary
- Output: multiple suggestions allowed (weight/reps + rep-range only)
- Tool calling deferred to post-V1

---

## 1. Guided Generation with @Generable

### How It Works

The `@Generable` macro enables compile-time schema generation for constrained decoding, guaranteeing output conforms to expected Swift types.

```swift
import FoundationModels

@Generable
struct WeatherReport: Equatable {
    let temperature: Double
    let condition: String
    let humidity: Double
}

// Generate structured output
let session = LanguageModelSession(instructions: "...")
let response = try await session.respond(
    to: "What's the weather?",
    generating: WeatherReport.self
)

let weather: WeatherReport = response.value
```

### Key Features

- **Compile-time schemas**: Framework generates JSON Schema at build time
- **Constrained decoding**: Model CANNOT produce invalid output
- **Type safety**: Get Swift structs/enums directly, not strings
- **Streaming support**: `streamResponse(generating:)` yields `PartiallyGenerated<T>` with optional fields that gradually populate

### @Guide Macro for Constraints

```swift
@Generable
struct Itinerary: Equatable {
    @Guide(description: "An exciting name for the trip.")
    let title: String

    @Guide(.anyOf(["Paris", "Tokyo", "London"]))
    let destinationName: String

    @Guide(.count(3))
    let activities: [Activity]

    @Guide(.range(1...10))
    let dayCount: Int
}
```

Available guides:
- `.anyOf([values])` - Enum-like constraint
- `.count(n)` - Exact array length
- `.range(range)` - Numeric bounds
- `description:` - Natural language hint

### Requirements for @Generable Types

✅ **Must conform to**: No specific protocol required, but typically `Equatable`
✅ **All properties**: Let constants (immutable)
✅ **Supported types**:
- Primitives: `String`, `Int`, `Double`, `Bool`
- Collections: `Array<T>` where T is Generable
- Nested: Other `@Generable` types
- Enums: `@Generable enum` works

❌ **NOT supported**:
- Computed properties
- Methods
- Generic types (except Array)
- Optional properties (use different approach for streaming)

### PartiallyGenerated for Streaming

```swift
for try await partial in session.streamResponse(generating: Itinerary.self, prompt: { "Plan a trip" }) {
    let itinerary: PartiallyGenerated<Itinerary> = partial.value

    // All properties are Optional during streaming
    if let title = itinerary.title {
        print("Title available: \(title)")
    }

    // Gradually populates until complete
}
```

---

## 2. Tool Calling

### Tool Protocol

Tools allow the model to call your code to gather information or perform actions. The framework automatically handles:
- Parallel tool execution (when possible)
- Serial tool chains (output of one → input of another)
- Complex call graphs

```swift
struct FindContacts: Tool {
    let name = "findContacts"
    let description = "Find a specific number of contacts"

    @Generable
    struct Arguments {
        @Guide(description: "The number of contacts to get", .range(1...10))
        let count: Int
    }

    func call(arguments: Arguments) async throws -> [String] {
        // Fetch contacts using arguments
        var contacts: [CNContact] = []
        // ... fetch logic ...
        return contacts.map { "\($0.givenName) \($0.familyName)" }
    }
}
```

### Tool Protocol Requirements

```swift
protocol Tool<Arguments, Output>: Sendable {
    var name: String { get }
    var description: String { get }

    associatedtype Arguments: ConvertibleFromGeneratedContent
    associatedtype Output: PromptRepresentable

    func call(arguments: Arguments) async throws -> Output
}
```

**Key Points**:
- `Arguments`: Must be `@Generable` struct (auto-conforms to `ConvertibleFromGeneratedContent`)
- `Output`: Typically `String` or another `@Generable` type
- `Sendable`: Tools run concurrently
- `async throws`: Tools can be asynchronous

### How Tools Are Invoked

1. **Tool definitions go in prompt**: Name, description, and argument schemas are automatically included in the prompt
2. **Model decides when to call**: Based on the prompt and tools available
3. **Framework generates arguments**: Uses constrained decoding to create valid `Arguments`
4. **Your code executes**: `call(arguments:)` is invoked
5. **Output returns to model**: Framework feeds result back for further reasoning

```swift
let session = LanguageModelSession(instructions: "You are a helpful assistant")

let response = try await session.respond(
    to: "Find 5 contacts whose names start with J",
    tools: [FindContacts()]
)

// Model automatically called the tool if needed
print(response.value) // String output incorporating tool results
```

### Tool Calling Best Practices

From Apple's documentation:

1. **Keep descriptions SHORT** (token efficient)
   - Tool description: 1 short sentence
   - `@Guide` descriptions: Just a few words

2. **Limit to 3-5 tools** per request (context window)

3. **Skip tool calling when unnecessary**
   - If model ALWAYS needs info, run tool directly and include in prompt
   - Use tools only when model must DECIDE whether to call

4. **Context window management**
   - Tool definitions consume tokens
   - Tool outputs consume tokens
   - Error: `LanguageModelSession.GenerationError.exceededContextWindowSize(_:)`
   - Solution: Break tool calls across multiple sessions

5. **Error handling**
   - Thrown errors wrapped in `LanguageModelSession.ToolCallError`
   - Rethrown at `respond()` call site

---

## 3. Applying to VillainArc Context System

### V1 Approach (Per-Exercise Input)

For V1 we **do not use tool calling**. We construct an `ExerciseSuggestionInput` per exercise that includes:
- Prescription snapshot for that exercise
- Performance snapshot for that exercise
- Exercise history summary (cached `ExerciseHistory`)

We then call the model **once per exercise** and clear context between calls.

### Tool Calling (Post-V1)

Our context gathering architecture maps well to Tool calling when we expand beyond V1:

```swift
// Each context provider becomes a Tool!

struct GetExerciseHistoryContext: Tool {
    let name = "getExerciseHistory"
    let description = "Get progression history for an exercise"

    @Generable
    struct Arguments {
        @Guide(description: "Exercise catalog ID")
        let catalogID: String

        @Guide(description: "Number of recent sessions", .range(1...10))
        let sessionCount: Int
    }

    func call(arguments: Arguments) async throws -> ExerciseHistoryContext {
        // Use our existing ExerciseHistoryProvider!
        return await ExerciseHistoryProvider.fetchContext(
            catalogID: arguments.catalogID,
            sessionCount: arguments.sessionCount,
            context: modelContext
        )
    }
}
```

### Making Context Structures @Generable

V1 only needs **minimal @Generable support** (no tool calling yet):
- `ExerciseHistoryContext` (summary, already backed by `ExerciseHistory`)
- `ExerciseSuggestionInput` (prescription + performance snapshots + history)

Other contexts (PrescriptionContext, PerformanceContext, SuggestionHistory, UserReadiness) can remain `Codable` until post-V1 tool calling.

#### ✅ Exercise History (V1)
```swift
@Generable
struct ExerciseHistoryContext: Equatable, Sendable {
    let catalogID: String
    let totalSessions: Int
    let last30DaySessions: Int
    let progressionTrend: ProgressionTrend
    // Summary fields only (no large arrays)
}

@Generable
enum ProgressionTrend {
    case improving
    case stable
    case declining
    case insufficient
}
```

**Changes needed**:
1. Add `@Generable` macro
2. Ensure nested types are also `@Generable`
3. Keep summary fields only (token efficient)

### Hybrid Approach: Rules + AI

We can use BOTH approaches:

```swift
// Phase 1: Rule-based (current plan)
let ruleSuggestions = RuleEngine.generateSuggestions(context: bundle)

// V1: AI per exercise (no tools yet)
if ruleSuggestions.isEmpty || userPreference.useAI {
    let session = LanguageModelSession(instructions: """
        You are a strength training expert. Analyze workout performance and suggest
        improvements based on progressive overload principles. Keep suggestions concise.
        """)

    let aiSuggestion = try await session.respond(
        to: "Analyze this exercise and suggest changes",
        generating: AISuggestionResponse.self
    )
}

@Generable
struct AISuggestionResponse: Equatable {
    @Guide(description: "Brief explanation of the suggestion")
    let rationale: String

    let suggestionType: SuggestionType
    let priority: Priority

    // Specific change details (matches our PrescriptionChange structure)
    let targetWeight: Double?
    let targetSetCount: Int?
    // ...
}
```

---

## 4. Token Budget & Context Window

### Context Window Limits

The on-device model has a **limited context window** (exact size not publicly documented, but typical for ~3B models is 4k-8k tokens).

**What consumes tokens**:
1. Instructions
2. Prompt
3. Tool definitions (name, description, argument schemas)
4. Tool outputs
5. Previous conversation turns (if multi-turn)

### Token Efficiency Strategies

1. **Lazy tool calling**
   ```swift
   // BAD: Provide all context upfront (wastes tokens)
   let context = gatherCompleteContext()
   let prompt = "Here's all the data: \(context)..."

   // GOOD: Let model request what it needs
   let tools = [
       GetExerciseHistoryTool(),  // Only called if needed
       GetPrescriptionContextTool(),
       GetPerformanceContextTool()
   ]
   ```

2. **Separate tool definitions by use case**
   ```swift
   // Don't give model 7+ tools at once
   // Instead, provide 3-5 relevant tools per suggestion type

   switch suggestionCategory {
   case .weightProgression:
       tools = [GetExerciseHistoryTool(), GetPerformanceContextTool()]
   case .volumeAdjustment:
       tools = [GetPrescriptionContextTool(), GetChangeHistoryTool()]
   }
   ```

3. **Summarize history**
   ```swift
   // Instead of sending 10 sessions of raw data
   struct ExerciseHistoryContext {
       let last3SessionsAvgWeight: Double  // ✅ Summary
       let progressionTrend: ProgressionTrend  // ✅ Summary
       // NOT: let rawSessions: [ExerciseSessionSnapshot]  // ❌ Too verbose
   }
   ```

4. **Break into multiple sessions if needed**
   ```swift
   // Session 1: Analyze data
   let analysis = try await session1.respond(
       to: "What's the trend?",
       generating: AnalysisResult.self
   )

   // Session 2: Generate suggestion (new context window)
   let session2 = LanguageModelSession(instructions: "...")
   let suggestion = try await session2.respond(
       to: "Based on \(analysis), suggest a change",
       generating: SuggestionResponse.self
   )
   ```

---

## 5. Implementation Recommendations

### Recommendation 1: V1 Rules + AI (Per Exercise)

**Why**:
- Small, per-exercise inputs keep the context window tiny
- Deterministic rule baseline + AI creativity
- Weight/reps only keeps changes safe and explainable

### Recommendation 2: Run Rules + AI in Parallel (No Arbitration Yet)

```swift
func generateSuggestions(
    input: ExerciseSuggestionInput
) async throws -> [PrescriptionChange] {
    let ruleSuggestions = RuleEngine.generate(from: input)
    let aiSuggestions = try await aiGenerator.suggest(from: input)
    return dedupe(ruleSuggestions + aiSuggestions)
}
```

### Recommendation 3: Tool Design (Post-V1)

Each context provider becomes a tool:

```swift
// 7 tools total (our 7 context providers)

struct GetExerciseHistoryTool: Tool {
    let name = "getExerciseHistory"
    let description = "Get exercise progression trend and recent performance"
    // Arguments: catalogID, sessionCount
    // Output: ExerciseHistoryContext
}

struct GetPrescriptionContextTool: Tool {
    let name = "getPrescription"
    let description = "Get current workout plan prescription for exercise"
    // Arguments: prescriptionID
    // Output: PrescriptionContext
}

struct GetPerformanceContextTool: Tool {
    let name = "getPerformance"
    let description = "Get latest session performance vs prescription"
    // Arguments: performanceID
    // Output: PerformanceContext
}

struct GetChangeHistoryTool: Tool {
    let name = "getChangeHistory"
    let description = "Get past suggestions and their outcomes"
    // Arguments: catalogID, lookbackDays
    // Output: ChangeHistoryContext
}

struct GetUserReadinessTool: Tool {
    let name = "getUserReadiness"
    let description = "Get user mood and recovery status"
    // Arguments: sessionID
    // Output: UserReadinessContext
}

struct GetSessionContextTool: Tool {
    let name = "getSessionContext"
    let description = "Get workout session environment details"
    // Arguments: sessionID
    // Output: SessionContext
}

// We probably DON'T need a GetCompleteContextTool
// Let the model request what it needs (token efficient)
```

### Recommendation 4: Structured Output

The model should produce our `PrescriptionChange` structure directly:

```swift
@Generable
struct AISuggestion: Equatable {
    let changeType: ChangeType
    let priority: Priority

    // Human-readable rationale
    @Guide(description: "Brief 1-2 sentence explanation")
    let rationale: String

    // Specific changes (match our existing PrescriptionChange)
    let targetWeight: Double?
    let weightDelta: Double?
    let targetSetCount: Int?
    let setCountDelta: Int?
    let targetRestSeconds: Int?
    let restSecondsDelta: Int?
    let targetRepRangeLower: Int?
    let targetRepRangeUpper: Int?
}

@Generable
enum ChangeType {
    case increaseWeight
    case decreaseWeight
    case addSet
    case removeSet
    case increaseRest
    case decreaseRest
    case widenRepRange
    case narrowRepRange
    case changeSetType
}

@Generable
enum Priority {
    case safety      // Must do
    case overload    // Should do (progression)
    case optimization // Nice to have
}
```

### Recommendation 5: Instructions Template

```swift
let instructions = """
You are an expert strength training coach analyzing workout performance data.
Your role is to suggest ONE specific improvement based on progressive overload principles.

RULES:
- Safety first: Never suggest increases that risk injury
- Progressive overload: Prioritize gradual progression
- Be conservative: Small increments are better than large jumps
- Consider context: Account for user readiness and recent trends

OUTPUT FORMAT:
Provide a single, specific suggestion with clear rationale.

EXAMPLES:
Good: "Increase weight by 5 lbs because you completed 12 reps (top of range) for 3 sessions"
Bad: "Maybe try more weight or add sets"
"""
```

---

## 6. Context Structure Updates Needed (V1)

### Exercise History (Already Implemented)
Backed by cached `ExerciseHistory`. For V1, keep **summary fields only** and add `@Generable` for model input.

```swift
@Generable
struct ExerciseHistoryContext: Equatable, Sendable {
    let catalogID: String
    let totalSessions: Int
    let last30DaySessions: Int
    let progressionTrend: ProgressionTrend
    let lastWorkoutDate: Date?
    let bestEstimated1RM: Double
    let bestWeight: Double
    let bestVolume: Double
    let last3AvgWeight: Double
    let last3AvgVolume: Double
    let typicalSetCount: Int
}
```

### ExerciseSuggestionInput (New)
Per-exercise input for AI calls (prescription + performance snapshots + history).

```swift
@Generable
struct ExerciseSuggestionInput: Equatable, Sendable {
    let catalogID: String
    let exerciseName: String
    let trainingStyle: String
    let prescription: PrescriptionSnapshot
    let performance: PerformanceSnapshot
    let exerciseHistory: ExerciseHistoryContext?
}
```

### Post-V1
`PrescriptionContext`, `PerformanceContext`, `SuggestionHistoryContext`, and `UserReadinessContext` can remain `Codable` until tool calling is added.

---

## 7. Testing Strategy

### Unit Tests for Tools

```swift
@Test
func testExerciseHistoryTool() async throws {
    let tool = GetExerciseHistoryTool()
    let args = tool.Arguments(catalogID: "bench-press", sessionCount: 3)

    let context = try await tool.call(arguments: args)

    #expect(context.catalogID == "bench-press")
    #expect(context.sessionCount == 3)
}
```

### Integration Tests with Mock Model

```swift
@Test
func testSuggestionGeneration() async throws {
    // We can't easily test actual FoundationModels in unit tests
    // But we can test our tool implementations

    let bundle = await ContextBundleProvider.gatherCompleteContext(...)

    // Test that context is valid and complete
    #expect(bundle.exerciseHistory != nil)
    #expect(bundle.prescription != nil)
}
```

### Manual Testing

Since FoundationModels requires actual device/simulator:

1. Create a debug view that shows:
   - Tool invocations
   - Token counts (if available)
   - Model responses
   - Generated suggestions

2. Test with real workout data

3. Compare AI suggestions vs rule suggestions

---

## 8. Migration Path

### V1: Rules + AI (Weight/Reps Only)
- One AI call per exercise (context cleared between calls)
- Input: prescription + performance snapshots + exercise history summary
- No tool calling in V1
- No outcome evaluation required for initial ship

### V2: Outcomes + Tool Calling
1. **Outcome evaluation**
   - Record `Outcome` after subsequent workouts
   - Surface outcomes in review UI
2. **Tool calling**
   - Add tools for history, readiness, suggestion history
   - Provide 3–5 tools per request for token efficiency
3. **Token optimization**
   - Use summary fields only
   - Split calls if necessary

### V3: Advanced Rules + AI Arbitration
- Use outcomes to bias both rules and AI
- Add readiness-based adjustments
- Optional user preference toggle for AI enhancements

---

## 9. Important Considerations

### Privacy
✅ **On-device**: All FoundationModels inference runs locally
✅ **No network**: Works completely offline
✅ **No data sent to Apple**: Workout data never leaves device

### Performance
- **Cold start**: First model load takes 1-2 seconds
- **Warm inference**: ~100-500ms for simple requests
- **Streaming**: Can show partial results immediately

### Platform Requirements
- VillainArc minimum OS for V1: iOS 26+ (FoundationModels available)
- If older OS support is added later, keep a rules-only fallback

```swift
// Only needed if we ever support < iOS 26
if #available(iOS 26, macOS 26, *) {
    return try await aiGenerator.suggest(...)
} else {
    return RuleEngine.generate(...)
}
```

### Model Limitations
- **Context window**: Limited (likely 4k-8k tokens)
- **Knowledge cutoff**: Model trained on data up to ~2024
- **Capabilities**: General language understanding, not workout-specific training
- **Reliability**: Needs good instructions and constraints to stay on-task

---

## 10. Conclusion

### Key Takeaways

1. **FoundationModels is perfect for VillainArc**
   - Guided generation gives type-safe suggestions
   - Tool calling matches our context architecture
   - On-device privacy aligns with fitness app values

2. **Start with rules, enhance with AI**
   - Rules provide deterministic baseline
   - AI handles edge cases and conflicts
   - Hybrid approach gets best of both

3. **Context structures need minor updates**
   - Add `@Generable` macro
   - Simplify nested types for token efficiency
   - Keep summary stats, remove verbose arrays

4. **Implementation is straightforward**
   - Each context provider → Tool
   - PrescriptionChange → @Generable output type
   - Existing architecture requires minimal changes

### Next Steps

1. ✅ Define V1 scope (weight/reps + rep-range only, iOS 26+)
2. ⏳ Add `@Generable` to `ExerciseHistoryContext` + `ExerciseSuggestionInput`
3. ⏳ Implement `AISuggestionGenerator` (one call per exercise)
4. ⏳ Implement V1 rules (progressive overload + rep-range inference)
5. ⏳ Wire into workout completion + suggestion review UI
6. ⏳ Test with real workout data

---

## References

### Apple Developer Documentation
- [Foundation Models Framework](https://developer.apple.com/documentation/FoundationModels)
- [Expanding generation with tool calling](https://developer.apple.com/documentation/foundationmodels/expanding-generation-with-tool-calling)
- [Generating Swift data structures with guided generation](https://developer.apple.com/documentation/foundationmodels/generating-swift-data-structures-with-guided-generation)
- [Adding intelligent app features with generative models](https://developer.apple.com/documentation/foundationmodels/adding-intelligent-app-features-with-generative-models)

### WWDC Sessions (2025)
- [Meet the Foundation Models framework](https://developer.apple.com/videos/play/wwdc2025/286/)
- [Deep dive into the Foundation Models framework](https://developer.apple.com/videos/play/wwdc2025/301/)
- [Code-along: Bring on-device AI to your app](https://developer.apple.com/videos/play/wwdc2025/259/)

### Technical Notes
- [TN3193: Managing the on-device foundation model's context window](https://developer.apple.com/documentation/Technotes/tn3193-managing-the-on-device-foundation-model-s-context-window)

### Community Resources
- [The Ultimate Guide To The Foundation Models Framework - AzamSharp](https://azamsharp.com/2025/06/18/the-ultimate-guide-to-the-foundation-models-framework.html)
- [Exploring the Foundation Models framework - Create with Swift](https://www.createwithswift.com/exploring-the-foundation-models-framework/)
- [Guided Generation with FoundationModels - Medium](https://medium.com/@luizfernandosalvaterra/guided-generation-with-foundationmodels-how-to-get-swift-structs-from-llms-ad663e60d716)

---

**Document Version**: 1.0
**Last Updated**: 2026-02-04
**Author**: AI Analysis based on Apple FoundationModels documentation

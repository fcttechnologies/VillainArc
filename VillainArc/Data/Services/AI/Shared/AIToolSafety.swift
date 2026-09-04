import FCTIntelligence
import FoundationModels

/// Villain Arc's half of the fleet tool-safety boundary: which tools this app is allowed to hand a
/// `LanguageModelSession`. The vetting itself — the read-only assertion, the allowlist check, the
/// single-prompt history transform — is `FCTIntelligence.AIToolSafety`.
///
/// The product rule it enforces is **"AI reads, user confirms writes"**: every model-callable tool
/// here only reads app data, and every write flows through user-confirmed UI (the suggestion
/// editors, the plan materializer's confirm step, the AI plan/import review sheet).
enum VAAITools {
    /// Names of every tool the app may attach to a model session. Adding a tool means adding it
    /// here; `AIToolSafetyTests` pins the set.
    static let allowedToolNames: Set<String> = [
        RecentExercisePerformancesTool().name,
    ]

    /// The app's own tools, vetted against the allowlist above.
    static func vetted(_ tools: [any SafeTool]) -> [any Tool] {
        AIToolSafety.vetted(tools, allowlist: allowedToolNames)
    }

    /// Apple-supplied tools, whose names this app does not control — the read-only assertion is the
    /// invariant that matters there.
    static func vettedSystem(_ tools: [any SafeTool]) -> [any Tool] {
        AIToolSafety.vettedReadOnly(tools)
    }
}

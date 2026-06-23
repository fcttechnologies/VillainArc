import FoundationModels

/// Agentic-safety policy for every on-device `LanguageModelSession` tool Villain Arc exposes.
///
/// The product rule is **"AI reads, user confirms writes"**: a model-callable `Tool` may only
/// read app data and hand it back to the model. It must never mutate the SwiftData store, call a
/// state-writing App Intent, hit HealthKit writes, or trigger any side effect. All persistence
/// flows through user-confirmed UI (the suggestion editors, the plan materializer's confirm step,
/// the AI plan/import review sheet) — never through a tool call.
///
/// `Tool` carries no type-level read/write distinction, so this file makes the contract explicit
/// and testable: every tool declares a `capability`, every tool the app registers lives on
/// `registeredToolNames`, and `AIToolSafetyAudit` (exercised by `AIToolSafetyTests`) fails the
/// build's test gate if a write-capable or unregistered tool is ever wired into a session.
enum AIToolCapability: String, Sendable, CaseIterable {
    /// Fetches and returns app data to the model. The only capability a Villain Arc tool may have.
    case readOnly
}

/// Marker protocol every model-callable Villain Arc `Tool` adopts so its capability is declared at
/// the type level and auditable without invoking Foundation Models.
protocol SafeTool: Tool {
    /// What this tool is permitted to do. Must be `.readOnly` for every Villain Arc tool.
    static var capability: AIToolCapability { get }
}

/// The single source of truth for which tools may reach a `LanguageModelSession`, and the history
/// policy those sessions run under. Adding a tool means registering it here and in the audit; the
/// safety test enforces both.
enum AIToolSafetyPolicy {
    /// Names of every tool the app is allowed to attach to a model session. A session must never be
    /// constructed with a tool whose `name` is absent from this set.
    static let allowedToolNames: Set<String> = [
        RecentExercisePerformancesTool().name,
    ]

    /// Returns the tools, asserting each is on the allowlist and read-only before they are handed to
    /// a session. Use this instead of building a raw `[any Tool]` array at a call site.
    static func vettedTools(_ tools: [any SafeTool]) -> [any Tool] {
        for tool in tools {
            precondition(
                allowedToolNames.contains(tool.name),
                "AI tool \"\(tool.name)\" is not on the safety allowlist."
            )
            precondition(
                type(of: tool).capability == .readOnly,
                "AI tool \"\(tool.name)\" must be read-only."
            )
        }
        return tools
    }

    /// History transform for tool-using sessions: keep only the most recent user prompt (plus the
    /// session instructions), so an earlier turn's text can't survive to influence a later tool call
    /// or response. Villain Arc's AI sessions are single-shot, but adopting the transform keeps the
    /// boundary correct if a session is ever reused, and documents the intent.
    static func latestPromptHistoryTransform(_ entries: [Transcript.Entry]) -> [Transcript.Entry] {
        var instructionsEntry: Transcript.Entry?
        var lastPromptEntry: Transcript.Entry?
        for entry in entries {
            switch entry {
            case .instructions:
                instructionsEntry = entry
            case .prompt:
                lastPromptEntry = entry
            default:
                continue
            }
        }
        return [instructionsEntry, lastPromptEntry].compactMap { $0 }
    }
}

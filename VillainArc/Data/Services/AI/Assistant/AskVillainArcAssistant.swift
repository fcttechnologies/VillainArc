import CoreSpotlight
import FoundationModels
// `SpotlightSearchTool` comes from the `_CoreSpotlight_FoundationModels` cross-import overlay, which
// the compiler auto-imports when both `CoreSpotlight` and `FoundationModels` are imported above.

/// On-device "Ask Villain Arc" assistant: answers natural-language questions about the user's own
/// indexed training data (workouts, plans, splits, exercises) by giving an iOS 27 `LanguageModelSession`
/// the system `SpotlightSearchTool` scoped to the app's CoreSpotlight index.
///
/// **Read-only, private-data boundary.** The only tool the session can call is the Spotlight search,
/// scoped to `.coreSpotlight` (this app's own index) — it reads the user's data and never writes. No
/// state-mutating tool is ever attached (enforced by `AIToolSafetyPolicy.vettedSpotlightTools`). The
/// model runs entirely on-device; nothing leaves the phone.
///
/// **Gated with a graceful fallback.** Requires iOS 27 (the Spotlight tool) and an available system
/// model; otherwise `availability` reports why so the caller can fall back to the normal History and
/// Trends screens. On-device answer-quality verification is a later with-Fernando device pass — this
/// type is the wiring + gating + safety boundary only.
enum AskVillainArcAssistant {
    nonisolated enum Availability: Equatable, Sendable {
        case available
        case requiresNewerOS
        case modelUnavailable

        var isAvailable: Bool { self == .available }
    }

    nonisolated enum AskError: Error, Equatable, Sendable {
        case unavailable(Availability)
        case failed
    }

    /// Whether the assistant can run right now, and why not if it can't.
    static var availability: Availability {
        guard #available(iOS 27.0, *) else { return .requiresNewerOS }
        if case .available = SystemLanguageModel.default.availability { return .available }
        return .modelUnavailable
    }

    static var isAvailable: Bool { availability.isAvailable }

    /// The session instructions: a strict read-only, private-data-only system prompt.
    static var instructions: String {
        """
        You answer questions about the user's own Villain Arc training data: their logged workouts,
        workout plans, splits, and exercises. Use the Spotlight search tool to find relevant items in
        the user's private on-device index, then answer concisely from what you find.

        Rules:
        - Only use the user's indexed Villain Arc data. Never invent workouts, numbers, dates, or plans.
        - You can only read. You never create, edit, delete, or start anything; if asked to, explain
          that you can only answer questions and they can make changes in the app.
        - If the search finds nothing relevant, say so plainly and suggest the History or Trends screen.
        - Keep answers short and specific. Prefer concrete numbers and names from the data.
        """
    }

    @available(iOS 27.0, *)
    static func ask(_ question: String) async -> Result<String, AskError> {
        guard isAvailable else { return .failure(.unavailable(availability)) }

        let tools = AIToolSafetyPolicy.vettedSpotlightTools([makeSpotlightTool()])
        let session = LanguageModelSession(tools: tools, instructions: instructions)
        let prompt = Prompt {
            "Answer this question about my Villain Arc training data:"
            ""
            question
        }

        do {
            let response = try await MetricsService.trackOperation(
                .askAssistant,
                stateLabel: "respond",
                signpostName: "Ask Villain Arc"
            ) {
                try await session.respond(to: prompt)
            }
            return .success(response.content)
        } catch {
            return .failure(.failed)
        }
    }

    /// The Spotlight search tool scoped to this app's own CoreSpotlight index (the private-data boundary).
    @available(iOS 27.0, *)
    static func makeSpotlightTool() -> SpotlightSearchTool {
        SpotlightSearchTool(configuration: .init(sources: [.coreSpotlight]))
    }
}

@available(iOS 27.0, *)
extension SpotlightSearchTool: SafeTool {
    /// The Spotlight tool only reads the user's index; it has no write capability.
    static var capability: AIToolCapability { .readOnly }
}

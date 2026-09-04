import FCTIntelligence
import FoundationModels
import Testing

@testable import VillainArc

/// Agentic-safety gate for Villain Arc's on-device AI tool surface.
///
/// Enforces the "AI reads, user confirms writes" policy at the test level: every tool this app can
/// attach to a `LanguageModelSession` is read-only and on the app's allowlist. The vetting seam and
/// its history transform are `FCTIntelligence.AIToolSafety`'s and are proved there; what is proved
/// here is the app's own composition — which tools it registers, and that they pass. These checks
/// run without invoking Foundation Models, so they hold regardless of model availability.
struct AIToolSafetyTests {
    @Test func recentPerformancesTool_isReadOnly() {
        let capability: AIToolCapability = RecentExercisePerformancesTool.capability
        #expect(capability == .readOnly)
    }

    @Test func recentPerformancesTool_isOnTheAllowlist() {
        #expect(VAAITools.allowedToolNames.contains(RecentExercisePerformancesTool().name))
    }

    @Test func everyAllowedToolNameIsNonEmpty() {
        #expect(VAAITools.allowedToolNames.allSatisfy { !$0.isEmpty })
        // The allowlist is the entire model-callable tool surface. Today that is exactly the
        // read-only recent-performances fetch; growth must come through registration here.
        #expect(VAAITools.allowedToolNames == [RecentExercisePerformancesTool().name])
    }

    @Test func vettedTools_passesTheRegisteredReadOnlyTool() {
        let vetted = VAAITools.vetted([RecentExercisePerformancesTool()])
        #expect(vetted.count == 1)
        #expect(vetted.first?.name == RecentExercisePerformancesTool().name)
    }
}

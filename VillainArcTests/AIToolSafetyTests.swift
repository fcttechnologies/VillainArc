import FoundationModels
import Testing

@testable import VillainArc

/// Agentic-safety gate for the on-device AI tool surface.
///
/// Enforces the "AI reads, user confirms writes" policy at the test level: every tool the app can
/// attach to a `LanguageModelSession` must be read-only and on the allowlist, and the tool-using
/// session's history transform must keep only the instructions plus the latest user prompt so an
/// earlier turn can't influence a later tool call. These checks run without invoking Foundation
/// Models, so they hold on every CI run regardless of model availability.
struct AIToolSafetyTests {
    @Test func recentPerformancesTool_isReadOnly() {
        #expect(RecentExercisePerformancesTool.capability == .readOnly)
    }

    @Test func recentPerformancesTool_isOnTheAllowlist() {
        #expect(AIToolSafetyPolicy.allowedToolNames.contains(RecentExercisePerformancesTool().name))
    }

    @Test func everyAllowedToolNameIsNonEmpty() {
        #expect(AIToolSafetyPolicy.allowedToolNames.allSatisfy { !$0.isEmpty })
        // The allowlist is the entire model-callable tool surface. Today that is exactly the
        // read-only recent-performances fetch; growth must come through registration here.
        #expect(AIToolSafetyPolicy.allowedToolNames == [RecentExercisePerformancesTool().name])
    }

    @Test func capabilityEnum_onlyExposesReadOnly() {
        // A write capability does not exist by construction; if one is ever added the audit below
        // and `vettedTools`' read-only precondition must both be revisited.
        #expect(AIToolCapability.allCases == [.readOnly])
    }

    @Test func vettedTools_passesTheRegisteredReadOnlyTool() {
        let vetted = AIToolSafetyPolicy.vettedTools([RecentExercisePerformancesTool()])
        #expect(vetted.count == 1)
        #expect(vetted.first?.name == RecentExercisePerformancesTool().name)
    }

    // MARK: - History transform

    @Test func historyTransform_keepsInstructionsAndLatestPromptOnly() {
        let entries: [Transcript.Entry] = [
            .instructions(Transcript.Instructions(segments: [.text(.init(content: "system rules"))], toolDefinitions: [])),
            .prompt(Transcript.Prompt(segments: [.text(.init(content: "first user turn"))])),
            .response(Transcript.Response(assetIDs: [], segments: [.text(.init(content: "earlier answer"))])),
            .prompt(Transcript.Prompt(segments: [.text(.init(content: "latest user turn"))])),
        ]

        let filtered = AIToolSafetyPolicy.latestPromptHistoryTransform(entries)

        #expect(filtered.count == 2)
        guard case .instructions = filtered.first else {
            Issue.record("Expected instructions to be retained first.")
            return
        }
        guard case let .prompt(prompt) = filtered.last else {
            Issue.record("Expected the latest prompt to be retained last.")
            return
        }
        let promptText = prompt.segments.compactMap { segment -> String? in
            if case let .text(text) = segment { return text.content }
            return nil
        }.joined()
        #expect(promptText == "latest user turn")
    }

    @Test func historyTransform_dropsToolCallAndOutputEntries() {
        let entries: [Transcript.Entry] = [
            .instructions(Transcript.Instructions(segments: [.text(.init(content: "rules"))], toolDefinitions: [])),
            .toolCalls(Transcript.ToolCalls([])),
            .toolOutput(Transcript.ToolOutput(id: "t1", toolName: "getRecentExercisePerformances", segments: [.text(.init(content: "tool data"))])),
            .prompt(Transcript.Prompt(segments: [.text(.init(content: "only prompt"))])),
        ]

        let filtered = AIToolSafetyPolicy.latestPromptHistoryTransform(entries)

        #expect(filtered.count == 2)
        #expect(filtered.contains { if case .toolCalls = $0 { return true }; return false } == false)
        #expect(filtered.contains { if case .toolOutput = $0 { return true }; return false } == false)
    }

    @Test func historyTransform_withNoPrompt_returnsInstructionsOnly() {
        let entries: [Transcript.Entry] = [
            .instructions(Transcript.Instructions(segments: [.text(.init(content: "rules"))], toolDefinitions: [])),
        ]
        let filtered = AIToolSafetyPolicy.latestPromptHistoryTransform(entries)
        #expect(filtered.count == 1)
        guard case .instructions = filtered.first else {
            Issue.record("Expected only the instructions entry.")
            return
        }
    }

    @Test func historyTransform_emptyTranscript_returnsEmpty() {
        #expect(AIToolSafetyPolicy.latestPromptHistoryTransform([]).isEmpty)
    }
}

import CoreSpotlight
import FCTIntelligence
import FoundationModels
import Testing

@testable import VillainArc

/// Wiring + gating + safety-boundary coverage for the Ask Villain Arc assistant. On-device answer
/// quality is a later with-Fernando device pass; these checks are model-free.
struct AskVillainArcAssistantTests {
    @Test func availability_matchesIsAvailableFlag() {
        // The convenience flag must agree with the detailed availability case.
        #expect(AskVillainArcAssistant.isAvailable == AskVillainArcAssistant.availability.isAvailable)
    }

    @Test func availability_onlyAvailableCaseReportsAvailable() {
        #expect(AskVillainArcAssistant.Availability.available.isAvailable)
        #expect(AskVillainArcAssistant.Availability.modelUnavailable.isAvailable == false)
    }

    @Test func instructions_declareReadOnlyPrivateDataBoundary() {
        let instructions = AskVillainArcAssistant.instructions.lowercased()
        // The system prompt must state the read-only boundary and the private-data scope.
        #expect(instructions.contains("only read") || instructions.contains("can only read"))
        #expect(instructions.contains("never invent") || instructions.contains("only use the user"))
        #expect(instructions.contains("history") || instructions.contains("trends"))
    }

    @Test
    func spotlightTool_isReadOnly() {
        let capability: AIToolCapability = SpotlightSearchTool.capability
        #expect(capability == .readOnly)
    }

    @Test
    func makeSpotlightTool_producesAVettableReadOnlyTool() {
        let tool = AskVillainArcAssistant.makeSpotlightTool()
        // The vetting precondition-fails on a non-read-only tool; reaching a non-empty result
        // proves the assistant's tool passes the safety gate.
        let vetted = VAAITools.vettedSystem([tool])
        #expect(vetted.count == 1)
    }
}

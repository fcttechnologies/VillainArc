import Foundation
import Testing

@testable import VillainArc

struct AIWorkoutPlanGeneratorTests {
    // MARK: - sanitize(userPrompt:)

    @Test
    // Whitespace at the head and tail of the prompt should be trimmed before the model sees it.
    func sanitize_trimsLeadingAndTrailingWhitespace() {
        let result = AIWorkoutPlanGenerator.sanitize(userPrompt: "  4-day upper/lower \n ")
        #expect(result == "4-day upper/lower")
    }

    @Test
    // Inputs at or below the cap should pass through unchanged after trim.
    func sanitize_passesShortInputsThrough() {
        let result = AIWorkoutPlanGenerator.sanitize(userPrompt: "Push pull legs for hypertrophy")
        #expect(result == "Push pull legs for hypertrophy")
    }

    @Test
    // Inputs over the 500-char cap should be truncated at the last whitespace before the cut.
    func sanitize_truncatesAtWordBoundary() {
        // Build a string just over the cap. Final word straddles the cap so the truncator should
        // cut at the previous space.
        let head = String(repeating: "word ", count: 100) // 500 chars including trailing space
        let input = head + "tail-word-that-overflows"
        let result = AIWorkoutPlanGenerator.sanitize(userPrompt: input)
        #expect(result.count <= AIWorkoutPlanGenerator.maxUserPromptLength)
        #expect(result.hasSuffix("word") || result.hasSuffix("word "))
        #expect(result.contains("tail-word-that-overflows") == false)
    }

    @Test
    // Control characters (other than newline and tab) should be stripped before the model sees them.
    func sanitize_stripsControlCharacters() {
        let result = AIWorkoutPlanGenerator.sanitize(userPrompt: "build\u{0008}strength\u{0007}plan")
        #expect(result == "buildstrengthplan")
    }

    @Test
    // Newline and tab are preserved because they're meaningful whitespace, not noise.
    func sanitize_preservesNewlineAndTab() {
        let result = AIWorkoutPlanGenerator.sanitize(userPrompt: "build\nstrength\tplan")
        #expect(result == "build\nstrength\tplan")
    }

    // MARK: - resolveCatalogID(name:equipment:)

    @Test
    // Strategy 1: exact normalized name + equipment match should win.
    func resolveCatalogID_exactNameAndEquipment() {
        let id = AIWorkoutPlanGenerator.resolveCatalogID(name: "Bench Press", equipment: .barbell)
        #expect(id == "barbell_bench_press")
    }

    @Test
    // Strategy 4: equipment-prefixed name (the model often returns "Barbell Bench Press") should
    // still resolve to the catalog item whose name is just "Bench Press".
    func resolveCatalogID_resolvesEquipmentPrefixedName() {
        let id = AIWorkoutPlanGenerator.resolveCatalogID(name: "Barbell Bench Press", equipment: .barbell)
        #expect(id == "barbell_bench_press")
    }

    @Test
    // Unknown exercise names should return nil so the unresolved-name list can collect them.
    func resolveCatalogID_returnsNilForGarbage() {
        let id = AIWorkoutPlanGenerator.resolveCatalogID(name: "xyzzy-not-a-real-exercise", equipment: .barbell)
        #expect(id == nil)
    }

    // MARK: - Availability gate

    @Test
    // The availability gate should never crash in a test context. It returns a Bool depending on
    // the simulator/Apple Intelligence state. Just asserting it returns without throwing.
    func availability_doesNotCrash() {
        _ = AIWorkoutPlanGenerator.isAvailable
        _ = AIExerciseReplacementSuggester.isAvailable
    }

    @Test
    // When the model is unavailable, generate() should return .failure(.modelUnavailable) without
    // attempting a session. The test only runs the guard branch by inspecting isAvailable up front.
    func generate_returnsModelUnavailableWhenServiceOff() async {
        guard !AIWorkoutPlanGenerator.isAvailable else { return } // Skip on devices where the model IS available.
        let context = AIPlanProfileContext(fitnessLevelDisplay: "Intermediate", trainingGoalDisplay: "Hypertrophy", weightUnit: "lbs")
        let result = await AIWorkoutPlanGenerator.generate(userPrompt: "4-day upper/lower", profileContext: context)
        switch result {
        case .success: Issue.record("Expected modelUnavailable when service is off")
        case .failure(let error): #expect(error == .modelUnavailable)
        }
    }
}

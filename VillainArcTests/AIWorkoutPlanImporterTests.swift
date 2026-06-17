import Foundation
import Testing

@testable import VillainArc

struct AIWorkoutPlanImporterTests {
    @Test
    func sanitize_preservesRoutineLongerThanGenerationPrompt() {
        let input = String(repeating: "Bench Press 3 x 8\n", count: 40)
        let result = AIWorkoutPlanImporter.sanitize(routineText: input)

        #expect(result.count > AIWorkoutPlanGenerator.maxUserPromptLength)
        #expect(result == input.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    @Test
    func sanitize_capsLongRoutineAtWordBoundary() {
        let input = String(repeating: "exercise ", count: 800)
        let result = AIWorkoutPlanImporter.sanitize(routineText: input)

        #expect(result.count <= AIWorkoutPlanImporter.maxRoutineLength)
        #expect(result.hasSuffix("exercise"))
    }

    @Test
    func sanitize_stripsControlCharactersButPreservesLayout() {
        let input = "Push\u{0007}\nBench Press\t4 x 6"
        let result = AIWorkoutPlanImporter.sanitize(routineText: input)

        #expect(result == "Push\nBench Press\t4 x 6")
    }

    @Test @MainActor
    func importRoutine_returnsUnavailableWithoutModel() async {
        guard !AIWorkoutPlanImporter.isAvailable else { return }

        let result = await AIWorkoutPlanImporter.importRoutine("Bench Press 3 x 8")
        switch result {
        case .success:
            Issue.record("Expected modelUnavailable when the service is off")
        case .failure(let error):
            #expect(error == .modelUnavailable)
        }
    }
}

import Testing

@testable import VillainArc

@Suite(.serialized) struct FoundationModelIntegrationTests {
    @Test @MainActor func trainingStyleValidation_acceptsBoundedConfidence() {
        let output = AIInferenceOutput(trainingStyleClassification: .ascending, confidence: 0.7)

        let validated = AITrainingStyleClassifier.validate(output)

        #expect(validated?.trainingStyleClassification == .ascending)
        #expect(validated?.confidence == 0.7)
    }

    @Test @MainActor func trainingStyleValidation_rejectsOutOfRangeConfidence() {
        let output = AIInferenceOutput(trainingStyleClassification: .ascending, confidence: 1.2)

        let validated = AITrainingStyleClassifier.validate(output)

        #expect(validated == nil)
    }

    @Test @MainActor func trainingStyleAcceptance_requiresConfidenceAbovePointFive() {
        let weak = AIInferenceOutput(trainingStyleClassification: .ascending, confidence: 0.5)
        let strong = AIInferenceOutput(trainingStyleClassification: .ascending, confidence: 0.51)

        #expect(SuggestionGenerator.shouldUseAITrainingStyle(weak) == false)
        #expect(SuggestionGenerator.shouldUseAITrainingStyle(strong) == true)
    }

    @Test @MainActor func outcomeValidation_rejectsOutOfRangeConfidence() {
        let output = AIOutcomeInferenceOutput(outcome: .good, confidence: 1.1, reason: "Clear evidence.")

        let validated = AIOutcomeInferrer.validate(output)

        #expect(validated == nil)
    }

    @Test @MainActor func outcomeValidation_rejectsMultilineOrLongReason() {
        let multiline = AIOutcomeInferenceOutput(outcome: .good, confidence: 0.8, reason: "Line one.\nLine two.")
        let longReason = AIOutcomeInferenceOutput(outcome: .good, confidence: 0.8, reason: String(repeating: "a", count: 161))

        #expect(AIOutcomeInferrer.validate(multiline) == nil)
        #expect(AIOutcomeInferrer.validate(longReason) == nil)
    }

    @Test @MainActor func outcomeValidation_trimsAndAcceptsShortReason() {
        let output = AIOutcomeInferenceOutput(outcome: .good, confidence: 0.8, reason: "  Strong adherence to the new target.  ")

        let validated = AIOutcomeInferrer.validate(output)

        #expect(validated?.confidence == 0.8)
        #expect(validated?.reason == "Strong adherence to the new target.")
    }
}

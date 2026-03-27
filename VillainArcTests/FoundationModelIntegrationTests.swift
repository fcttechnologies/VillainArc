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

    @Test @MainActor func outcomeValidation_normalizesMultilineReason() {
        let multiline = AIOutcomeInferenceOutput(outcome: .good, confidence: 0.8, reason: "Line one.\nLine two.")

        let validated = AIOutcomeInferrer.validate(multiline)

        #expect(validated?.reason == "Line one. Line two.")
    }

    @Test @MainActor func outcomeValidation_truncatesLongReason() {
        let longReason = AIOutcomeInferenceOutput(outcome: .good, confidence: 0.8, reason: String(repeating: "a", count: 161))

        let validated = AIOutcomeInferrer.validate(longReason)

        #expect(validated?.reason.count == 160)
        #expect(validated?.reason == String(repeating: "a", count: 160))
    }

    @Test @MainActor func outcomeValidation_trimsAndAcceptsShortReason() {
        let output = AIOutcomeInferenceOutput(outcome: .good, confidence: 0.8, reason: "  Strong adherence to the new target.  ")

        let validated = AIOutcomeInferrer.validate(output)

        #expect(validated?.confidence == 0.8)
        #expect(validated?.reason == "Strong adherence to the new target.")
    }

    @Test @MainActor func aiPerformanceSnapshot_includesSetRPE() {
        let exercise = Exercise(from: ExerciseCatalog.byID["barbell_bench_press"]!)
        let session = WorkoutSession(status: .done)
        let performance = ExercisePerformance(exercise: exercise, workoutSession: session)
        let set = SetPerformance(exercise: performance, setType: .working, weight: 100, reps: 8, restSeconds: 90, index: 0, complete: true)
        set.rpe = 9
        performance.sets = [set]

        let snapshot = AIExercisePerformanceSnapshot(performance: performance)

        #expect(snapshot.sets.first?.rpe == 9)
    }

    @Test @MainActor func aiPrescriptionSnapshot_includesTargetRPE() {
        let exercise = Exercise(from: ExerciseCatalog.byID["barbell_bench_press"]!)
        let plan = WorkoutPlan(title: "Push")
        let prescription = ExercisePrescription(exercise: exercise, workoutPlan: plan)
        let set = SetPrescription(exercisePrescription: prescription, setType: .working, targetWeight: 100, targetReps: 8, targetRest: 90, targetRPE: 8, index: 0)
        prescription.sets = [set]

        let snapshot = AIExercisePrescriptionSnapshot(from: prescription)

        #expect(snapshot.sets.first?.targetRPE == 8)
    }
}

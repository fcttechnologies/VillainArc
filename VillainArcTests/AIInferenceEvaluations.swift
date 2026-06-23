import Evaluations
import Foundation
import FoundationModels
import Testing

@testable import VillainArc

// Evaluation-harness gates for the two inference features that previously had only scattered
// validation unit tests: training-style classification and outcome inference. These mirror the
// plan/replacement gates in AIQualityEvaluations.swift — they score the deterministic validation,
// threshold, and merge seams over golden + adversarial fixtures without invoking Foundation Models,
// so they hold on every run regardless of on-device model availability. Live model answer quality
// is verified separately with Fernando on device.

// MARK: - Training-style classification

nonisolated private struct AITrainingStyleEvaluationInput: Codable, Sendable, CustomStringConvertible {
    let scenario: String
    let classification: TrainingStyle?
    let confidence: Double

    var description: String { scenario }
}

nonisolated private struct AITrainingStyleEvaluationSample: SampleProtocol {
    let input: AITrainingStyleEvaluationInput
    let expected: AITrainingStyleEvaluationOutput?
}

nonisolated private struct AITrainingStyleEvaluationOutput: Codable, Sendable, Equatable {
    let validates: Bool
    let acceptedForUse: Bool
    let resolvedStyle: String?
}

nonisolated private struct AITrainingStyleQualityEvaluation: Evaluation {
    let exactOutput = Metric("Training-style exact output")
    let safetyInvariants = Metric("Training-style safety invariants")

    static let samples: [AITrainingStyleEvaluationSample] = [
        sample(scenario: "clear style, high confidence is accepted", style: .ascending, confidence: 0.9,
               expected: .init(validates: true, acceptedForUse: true, resolvedStyle: TrainingStyle.ascending.rawValue)),
        sample(scenario: "boundary confidence 1.0 validates and is accepted", style: .topSetBackoffs, confidence: 1.0,
               expected: .init(validates: true, acceptedForUse: true, resolvedStyle: TrainingStyle.topSetBackoffs.rawValue)),
        sample(scenario: "exactly at the 0.5 threshold validates but is not used", style: .straightSets, confidence: 0.5,
               expected: .init(validates: true, acceptedForUse: false, resolvedStyle: TrainingStyle.straightSets.rawValue)),
        sample(scenario: "just above threshold is used", style: .straightSets, confidence: 0.51,
               expected: .init(validates: true, acceptedForUse: true, resolvedStyle: TrainingStyle.straightSets.rawValue)),
        sample(scenario: "boundary confidence 0.0 validates but is not used", style: .reversePyramid, confidence: 0.0,
               expected: .init(validates: true, acceptedForUse: false, resolvedStyle: TrainingStyle.reversePyramid.rawValue)),
        sample(scenario: "confidence below 0 is rejected", style: .ascending, confidence: -0.01,
               expected: .init(validates: false, acceptedForUse: false, resolvedStyle: nil)),
        sample(scenario: "confidence above 1 is rejected", style: .ascending, confidence: 1.01,
               expected: .init(validates: false, acceptedForUse: false, resolvedStyle: nil)),
        sample(scenario: "nil classification is rejected even at high confidence", style: nil, confidence: 0.95,
               expected: .init(validates: false, acceptedForUse: false, resolvedStyle: nil)),
    ]

    var dataset: ArrayLoader<AITrainingStyleEvaluationSample> {
        ArrayLoader(samples: Self.samples)
    }

    nonisolated func subject(from sample: AITrainingStyleEvaluationSample) async throws -> ModelSubject<AITrainingStyleEvaluationOutput> {
        let output = await MainActor.run {
            let raw = AIInferenceOutput(trainingStyleClassification: sample.input.classification, confidence: sample.input.confidence)
            let validated = AITrainingStyleClassifier.validate(raw)
            let accepted = SuggestionGenerator.shouldUseAITrainingStyle(validated)
            return AITrainingStyleEvaluationOutput(
                validates: validated != nil,
                acceptedForUse: accepted,
                resolvedStyle: validated?.trainingStyleClassification?.rawValue
            )
        }
        return ModelSubject(value: output)
    }

    var evaluators: Evaluators {
        Evaluator<AITrainingStyleEvaluationSample> { sample, subject in
            guard let expected = sample.expected else { return exactOutput.ignore() }
            return subject.value == expected
                ? exactOutput.passing()
                : exactOutput.failing(rationale: "Expected \(expected), received \(subject.value)")
        }
        Evaluator<AITrainingStyleEvaluationSample> { _, subject in
            let value = subject.value
            // An accepted classification must always validate and carry a resolved style; a rejected
            // one must never be used. This guards the "no unvalidated style reaches the user" rule.
            let safe = (!value.acceptedForUse || (value.validates && value.resolvedStyle != nil))
                && (value.validates || value.resolvedStyle == nil)
            return safe
                ? safetyInvariants.passing()
                : safetyInvariants.failing(rationale: "An unvalidated or styleless classification was marked usable.")
        }
    }

    func aggregateMetrics(using aggregator: inout MetricsAggregator) {
        aggregator.computeMean(of: exactOutput)
        aggregator.computeMean(of: safetyInvariants)
    }

    private static func sample(scenario: String, style: TrainingStyle?, confidence: Double, expected: AITrainingStyleEvaluationOutput) -> AITrainingStyleEvaluationSample {
        AITrainingStyleEvaluationSample(
            input: AITrainingStyleEvaluationInput(scenario: scenario, classification: style, confidence: confidence),
            expected: expected
        )
    }
}

// MARK: - Outcome inference

nonisolated private struct AIOutcomeEvaluationInput: Codable, Sendable, CustomStringConvertible {
    let scenario: String
    let outcome: Outcome
    let confidence: Double
    let reason: String

    var description: String { scenario }
}

nonisolated private struct AIOutcomeEvaluationSample: SampleProtocol {
    let input: AIOutcomeEvaluationInput
    let expected: AIOutcomeEvaluationOutput?
}

nonisolated private struct AIOutcomeEvaluationOutput: Codable, Sendable, Equatable {
    let validates: Bool
    let normalizedReason: String?
    let reasonWithinBounds: Bool
}

nonisolated private struct AIOutcomeQualityEvaluation: Evaluation {
    let exactOutput = Metric("Outcome exact output")
    let reasonHygiene = Metric("Outcome reason hygiene")

    static let samples: [AIOutcomeEvaluationSample] = [
        sample(scenario: "clean short reason validates as-is", outcome: .good, confidence: 0.8, reason: "Strong adherence to the new target.",
               expected: .init(validates: true, normalizedReason: "Strong adherence to the new target.", reasonWithinBounds: true)),
        sample(scenario: "multiline reason collapses to one line", outcome: .good, confidence: 0.8, reason: "Line one.\nLine two.",
               expected: .init(validates: true, normalizedReason: "Line one. Line two.", reasonWithinBounds: true)),
        sample(scenario: "surrounding whitespace is trimmed", outcome: .tooEasy, confidence: 0.7, reason: "   Cleanly exceeded targets.   ",
               expected: .init(validates: true, normalizedReason: "Cleanly exceeded targets.", reasonWithinBounds: true)),
        sample(scenario: "overlong reason truncates to 160", outcome: .tooAggressive, confidence: 0.9, reason: String(repeating: "a", count: 200),
               expected: .init(validates: true, normalizedReason: String(repeating: "a", count: 160), reasonWithinBounds: true)),
        sample(scenario: "confidence below 0 is rejected", outcome: .good, confidence: -0.01, reason: "Clear evidence.",
               expected: .init(validates: false, normalizedReason: nil, reasonWithinBounds: true)),
        sample(scenario: "confidence above 1 is rejected", outcome: .good, confidence: 1.01, reason: "Clear evidence.",
               expected: .init(validates: false, normalizedReason: nil, reasonWithinBounds: true)),
        sample(scenario: "whitespace-only reason is rejected", outcome: .good, confidence: 0.8, reason: "   \n\t  ",
               expected: .init(validates: false, normalizedReason: nil, reasonWithinBounds: true)),
    ]

    var dataset: ArrayLoader<AIOutcomeEvaluationSample> {
        ArrayLoader(samples: Self.samples)
    }

    nonisolated func subject(from sample: AIOutcomeEvaluationSample) async throws -> ModelSubject<AIOutcomeEvaluationOutput> {
        let output = await MainActor.run {
            guard let aiOutcome = AIOutcome(from: sample.input.outcome) else {
                return AIOutcomeEvaluationOutput(validates: false, normalizedReason: nil, reasonWithinBounds: true)
            }
            let raw = AIOutcomeInferenceOutput(outcome: aiOutcome, confidence: sample.input.confidence, reason: sample.input.reason)
            let validated = AIOutcomeInferrer.validate(raw)
            return AIOutcomeEvaluationOutput(
                validates: validated != nil,
                normalizedReason: validated?.reason,
                reasonWithinBounds: (validated?.reason.count ?? 0) <= 160
            )
        }
        return ModelSubject(value: output)
    }

    var evaluators: Evaluators {
        Evaluator<AIOutcomeEvaluationSample> { sample, subject in
            guard let expected = sample.expected else { return exactOutput.ignore() }
            return subject.value == expected
                ? exactOutput.passing()
                : exactOutput.failing(rationale: "Expected \(expected), received \(subject.value)")
        }
        Evaluator<AIOutcomeEvaluationSample> { _, subject in
            let value = subject.value
            // A validated reason must always be non-empty and within the 160-char display bound.
            let hygienic = value.reasonWithinBounds
                && (!value.validates || (value.normalizedReason?.isEmpty == false))
            return hygienic
                ? reasonHygiene.passing()
                : reasonHygiene.failing(rationale: "A validated outcome carried an empty or overlong reason.")
        }
    }

    func aggregateMetrics(using aggregator: inout MetricsAggregator) {
        aggregator.computeMean(of: exactOutput)
        aggregator.computeMean(of: reasonHygiene)
    }

    private static func sample(scenario: String, outcome: Outcome, confidence: Double, reason: String, expected: AIOutcomeEvaluationOutput) -> AIOutcomeEvaluationSample {
        AIOutcomeEvaluationSample(
            input: AIOutcomeEvaluationInput(scenario: scenario, outcome: outcome, confidence: confidence, reason: reason),
            expected: expected
        )
    }
}

// MARK: - Outcome override decision (rule vs AI merge)

/// Pure decision-logic fixtures for OutcomeResolver's rule-vs-AI arbitration, complementing the
/// MultiSessionEvaluationTests merge cases with an explicit golden table.
@Suite("AI inference evaluation gates")
struct AIInferenceEvaluationTests {
    private static let trainingStyleEvaluation = AITrainingStyleQualityEvaluation()
    private static let outcomeEvaluation = AIOutcomeQualityEvaluation()

    @Test(.evaluates(Self.trainingStyleEvaluation, info: ["dataset": "villain-arc-training-style-golden-v1"]))
    func trainingStyleClassificationQuality() async throws {
        let result = EvaluationContext.current.result
        #expect(result.aggregateValue(.mean(of: Self.trainingStyleEvaluation.exactOutput)) == 1)
        #expect(result.aggregateValue(.mean(of: Self.trainingStyleEvaluation.safetyInvariants)) == 1)

        let encoded = try result.jsonData()
        let decoded = try EvaluationResult(jsonData: encoded)
        #expect(decoded.evaluationID == result.evaluationID)
    }

    @Test(.evaluates(Self.outcomeEvaluation, info: ["dataset": "villain-arc-outcome-golden-v1"]))
    func outcomeInferenceQuality() async throws {
        let result = EvaluationContext.current.result
        #expect(result.aggregateValue(.mean(of: Self.outcomeEvaluation.exactOutput)) == 1)
        #expect(result.aggregateValue(.mean(of: Self.outcomeEvaluation.reasonHygiene)) == 1)
    }

    @Test("Outcome override prefers a decisively stronger AI signal only", arguments: [
        // rule outcome/conf, ai outcome/conf, expected override
        (Outcome.good, 0.8, Outcome.tooEasy, 0.9, true),
        (Outcome.good, 0.8, Outcome.tooEasy, 0.82, false),
        (Outcome.ignored, 0.7, Outcome.tooEasy, 0.92, true),
        (Outcome.good, 0.9, Outcome.tooEasy, 0.95, false),
    ])
    @MainActor
    func outcomeOverrideArbitration(ruleOutcome: Outcome, ruleConfidence: Double, aiOutcome: Outcome, aiConfidence: Double, expected: Bool) throws {
        let rule = OutcomeSignal(outcome: ruleOutcome, confidence: ruleConfidence, reason: "rule")
        let ai = AIOutcomeInferenceOutput(outcome: try #require(AIOutcome(from: aiOutcome)), confidence: aiConfidence, reason: "ai")
        #expect(OutcomeResolver.shouldPreferAIOverride(rule: rule, ai: ai) == expected)
    }
}

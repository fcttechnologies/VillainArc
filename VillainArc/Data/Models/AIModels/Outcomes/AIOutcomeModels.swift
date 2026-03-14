import Foundation
import FoundationModels

@Generable
enum AIChangeScope: String {
    case exercise = "Exercise"
    case set = "Set"
}

@Generable
enum AIOutcome: String {
    case good = "Good"
    case tooAggressive = "Too Aggressive"
    case tooEasy = "Too Easy"
    case ignored = "Ignored"

    var outcome: Outcome {
        switch self {
        case .good: return .good
        case .tooAggressive: return .tooAggressive
        case .tooEasy: return .tooEasy
        case .ignored: return .ignored
        }
    }

    init?(from outcome: Outcome) {
        switch outcome {
        case .good: self = .good
        case .tooAggressive: self = .tooAggressive
        case .tooEasy: self = .tooEasy
        case .ignored: self = .ignored
        case .pending: return nil
        }
    }
}

@Generable
struct AIOutcomeChange {
    @Guide(description: "Change type.")
    let changeType: ChangeType
    @Guide(description: "Exercise or set.")
    let scope: AIChangeScope
    @Guide(description: "Target set index.")
    let targetSetIndex: Int?
    @Guide(description: "Old scalar or label.")
    let previousValue: String?
    @Guide(description: "Suggested scalar or label.")
    let newValue: String?
}

@Generable
struct AIOutcomeGroupInput {
    @Guide(description: "Suggested changes.")
    let changes: [AIOutcomeChange]
    @Guide(description: "Original prescription.")
    let prescription: AIExercisePrescriptionSnapshot
    @Guide(description: "Trigger workout.")
    let triggerPerformance: AIExercisePerformanceSnapshot
    @Guide(description: "Evaluation workout.")
    let actualPerformance: AIExercisePerformanceSnapshot
    @Guide(description: "Training style.")
    let trainingStyle: TrainingStyle?
    @Guide(description: "Rule hint.")
    let ruleOutcome: AIOutcome?
    @Guide(description: "Rule confidence.")
    let ruleConfidence: Double?
    @Guide(description: "Rule reason.")
    let ruleReason: String?
}

@Generable
struct AIOutcomeInferenceOutput {
    @Guide(description: "Outcome.")
    let outcome: AIOutcome
    @Guide(description: "Confidence 0 to 1.")
    let confidence: Double
    @Guide(description: "Short reason.")
    let reason: String
}

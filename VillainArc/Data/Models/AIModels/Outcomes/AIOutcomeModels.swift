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
    case insufficient = "Insufficient"
    case ignored = "Ignored"

    var outcome: Outcome {
        switch self {
        case .good: return .good
        case .tooAggressive: return .tooAggressive
        case .tooEasy: return .tooEasy
        case .insufficient: return .insufficient
        case .ignored: return .ignored
        }
    }

    init?(from outcome: Outcome) {
        switch outcome {
        case .good: self = .good
        case .tooAggressive: self = .tooAggressive
        case .tooEasy: self = .tooEasy
        case .insufficient: self = .insufficient
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
    @Guide(description: "Trigger target slot.")
    let triggerTargetSetIndex: Int?
    @Guide(description: "Old value.")
    let previousValue: String?
    @Guide(description: "New value.")
    let newValue: String?
}

@Generable
struct AIOutcomeGroupInput {
    @Guide(description: "Category.")
    let category: SuggestionCategory
    @Guide(description: "Category-specific lens.")
    let categoryGuidance: String?
    @Guide(description: "Changes.")
    let changes: [AIOutcomeChange]
    @Guide(description: "Original targets.")
    let prescription: AIExercisePrescriptionSnapshot
    @Guide(description: "Trigger workout.")
    let triggerPerformance: AIExercisePerformanceSnapshot
    @Guide(description: "Current workout.")
    let actualPerformance: AIExercisePerformanceSnapshot
    @Guide(description: "Resolved training style.")
    let trainingStyle: TrainingStyle?
    @Guide(description: "Post-workout effort 1 to 10.")
    let postWorkoutEffort: Int?
    @Guide(description: "Recorded pre-workout feeling.")
    let preWorkoutFeeling: AIMoodLevel?
    @Guide(description: "True only if pre-workout was recorded.")
    let tookPreWorkout: Bool?
    @Guide(description: "Rule hint.")
    let ruleOutcome: AIOutcome?
    @Guide(description: "Rule confidence 0 to 1.")
    let ruleConfidence: Double?
    @Guide(description: "Rule reason.")
    let ruleReason: String?
}

@Generable
struct AIOutcomeInferenceOutput {
    @Guide(description: "Outcome.")
    let outcome: AIOutcome
    @Guide(description: "Confidence 0 to 1.", .range(0.0 ... 1.0))
    let confidence: Double
    @Guide(description: "One short evidence sentence.")
    let reason: String
}

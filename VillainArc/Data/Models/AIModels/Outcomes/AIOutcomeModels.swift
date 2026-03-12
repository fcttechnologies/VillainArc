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
    @Guide(description: "Type of change that was suggested.")
    let changeType: ChangeType
    @Guide(description: "Whether this change applies to the whole exercise prescription or one specific target set.")
    let scope: AIChangeScope
    @Guide(description: "0-based target set slot for set-level changes. Nil for exercise-level changes.")
    let targetSetIndex: Int?
    @Guide(description: "Previous value before the change (e.g., \"135.0\" for weight, \"10\" for reps, \"90\" for rest seconds, \"Warm Up Set\" for set type, \"Range\" for rep range mode).")
    let previousValue: String?
    @Guide(description: "New value after the change (e.g., \"140.0\" for weight, \"12\" for reps, \"120\" for rest seconds, \"Regular Set\" for set type, \"Target\" for rep range mode).")
    let newValue: String?
}

@Generable
struct AIOutcomeGroupInput {
    @Guide(description: "The group of changes that were suggested together.")
    let changes: [AIOutcomeChange]
    @Guide(description: "The exercise prescription before the changes were applied.")
    let prescription: AIExercisePrescriptionSnapshot
    @Guide(description: "What the user performed in the session that triggered these suggestions (last time).")
    let triggerPerformance: AIExercisePerformanceSnapshot
    @Guide(description: "What the user actually performed in the evaluation session (this time).")
    let actualPerformance: AIExercisePerformanceSnapshot
    @Guide(description: "How the user structures their sets: Straight Sets, Ascending Pyramid, Descending Pyramid, Ascending, Top Set Then Backoffs, or Unknown. Use this to focus evaluation on the right sets.")
    let trainingStyle: TrainingStyle?
    @Guide(description: "Rule engine outcome for this group, if available. Nil means rules were inconclusive.")
    let ruleOutcome: AIOutcome?
    @Guide(description: "Rule engine confidence (0.0–1.0). Nil if rules were inconclusive.")
    let ruleConfidence: Double?
    @Guide(description: "Rule engine reasoning. Nil if rules were inconclusive.")
    let ruleReason: String?
}

@Generable
struct AIOutcomeInferenceOutput {
    @Guide(description: "The evaluated outcome: good, tooAggressive, tooEasy, or ignored.")
    let outcome: AIOutcome
    @Guide(description: "Confidence in the outcome from 0.0 to 1.0.")
    let confidence: Double
    @Guide(description: "Brief explanation for why this outcome was chosen.")
    let reason: String
}

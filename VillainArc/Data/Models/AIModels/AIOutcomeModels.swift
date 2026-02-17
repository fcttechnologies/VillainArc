import Foundation
import FoundationModels

@Generable
enum AIOutcome: String, Equatable, Sendable {
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
        case .pending, .userModified: return nil
        }
    }
}

@Generable
struct AIOutcomeChange: Equatable, Sendable {
    @Guide(description: "Type of change that was suggested.")
    let changeType: ChangeType
    @Guide(description: "Previous value before the change (e.g., \"135.0\" for weight, \"10\" for reps, \"90\" for rest seconds, \"Warm Up Set\" for set type, \"Range\" for rep range mode).")
    let previousValue: String?
    @Guide(description: "New value after the change (e.g., \"140.0\" for weight, \"12\" for reps, \"120\" for rest seconds, \"Regular Set\" for set type, \"Target\" for rep range mode).")
    let newValue: String?
    @Guide(description: "0-based index of the target set, if this is a set-level change. Nil for exercise-level changes.")
    let targetSetIndex: Int?
}

@Generable
struct AIExercisePrescriptionSnapshot: Equatable, Sendable {
    @Guide(description: "Name of the exercise.")
    let exerciseName: String
    @Guide(description: "Rep range mode: Target, Range, or nil if not set.")
    let repRangeMode: AIRepRangeMode?
    @Guide(description: "Lower bound of rep range (when mode is Range). Nil if not applicable.")
    let repRangeLower: Int?
    @Guide(description: "Upper bound of rep range (when mode is Range). Nil if not applicable.")
    let repRangeUpper: Int?
    @Guide(description: "Target reps (when mode is Target). Nil if not applicable.")
    let repRangeTarget: Int?
    @Guide(description: "Prescribed sets for this exercise.")
    let sets: [AISetPrescriptionSnapshot]
}

@Generable
struct AISetPrescriptionSnapshot: Equatable, Sendable {
    @Guide(description: "0-based set index within the exercise.")
    let index: Int
    @Guide(description: "Type of set: warmup, regular, superSet, dropSet, or failure.")
    let setType: AIExerciseSetType
    @Guide(description: "Target weight for this set.")
    let targetWeight: Double
    @Guide(description: "Target reps for this set.")
    let targetReps: Int
    @Guide(description: "Target rest seconds for this set.")
    let targetRest: Int
}

extension AIExercisePrescriptionSnapshot {
    init(from prescription: ExercisePrescription) {
        self.exerciseName = prescription.name
        let policy = prescription.repRange ?? RepRangePolicy()
        switch policy.activeMode {
        case .range:
            self.repRangeMode = .range
            self.repRangeLower = policy.lowerRange
            self.repRangeUpper = policy.upperRange
            self.repRangeTarget = nil
        case .target:
            self.repRangeMode = .target
            self.repRangeLower = nil
            self.repRangeUpper = nil
            self.repRangeTarget = policy.targetReps
        case .notSet:
            self.repRangeMode = nil
            self.repRangeLower = nil
            self.repRangeUpper = nil
            self.repRangeTarget = nil
        }
        self.sets = prescription.sortedSets.map { AISetPrescriptionSnapshot(from: $0) }
    }
}

extension AISetPrescriptionSnapshot {
    init(from set: SetPrescription) {
        self.index = set.index
        self.setType = AIExerciseSetType(from: set.type)
        self.targetWeight = set.targetWeight
        self.targetReps = set.targetReps
        self.targetRest = set.targetRest
    }
}

@Generable
struct AIOutcomeGroupInput: Equatable, Sendable {
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
struct AIOutcomeInferenceOutput: Equatable, Sendable {
    @Guide(description: "The evaluated outcome: good, tooAggressive, tooEasy, or ignored.")
    let outcome: AIOutcome
    @Guide(description: "Confidence in the outcome from 0.0 to 1.0.")
    let confidence: Double
    @Guide(description: "Brief explanation for why this outcome was chosen.")
    let reason: String
}

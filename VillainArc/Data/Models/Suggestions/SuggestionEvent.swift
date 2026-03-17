import Foundation
import SwiftData

@Model
final class SuggestionEvent {
    #Index<SuggestionEvent>([\.createdAt])

    var id: UUID = UUID()
    var source: SuggestionSource = SuggestionSource.rules
    var category: SuggestionCategory = SuggestionCategory.performance
    var catalogID: String = ""

    @Relationship(deleteRule: .nullify)
    var sessionFrom: WorkoutSession?

    @Relationship(deleteRule: .nullify, inverse: \ExercisePrescription.suggestionEvents)
    var targetExercisePrescription: ExercisePrescription?

    @Relationship(deleteRule: .nullify, inverse: \SetPrescription.suggestionEvents)
    var targetSetPrescription: SetPrescription?

    var triggerTargetSetID: UUID?

    var decision: Decision = Decision.pending
    var outcome: Outcome = Outcome.pending

    @Relationship(deleteRule: .nullify)
    var triggerPerformance: ExercisePerformance?

    var ruleID: SuggestionRule?
    var decisionReason: DecisionReason?
    var userFeedback: UserFeedback?

    var trainingStyle: TrainingStyle = TrainingStyle.unknown

    var requiredEvaluationCount: Int = 1

    @Relationship(deleteRule: .cascade, inverse: \SuggestionEvaluation.event)
    var evaluations: [SuggestionEvaluation]? = [SuggestionEvaluation]()

    var suggestionConfidence: Double = SuggestionConfidenceTier.moderate.defaultScore

    var createdAt: Date = Date()
    var evaluatedAt: Date?

    var changeReasoning: String?
    var outcomeReason: String?

    @Relationship(deleteRule: .cascade, inverse: \PrescriptionChange.event)
    var changes: [PrescriptionChange]? = [PrescriptionChange]()

    var currentTargetSetIndex: Int? {
        targetSetPrescription?.index
    }

    var triggerTargetSnapshot: ExerciseTargetSnapshot? {
        triggerPerformance?.originalTargetSnapshot
    }

    var triggerTargetSetIndex: Int? {
        guard let triggerTargetSetID, let snapshot = triggerTargetSnapshot else { return nil }
        return snapshot.sets.first(where: { $0.targetSetID == triggerTargetSetID })?.index
    }

    var isSetScoped: Bool {
        targetSetPrescription != nil || triggerTargetSetID != nil
    }

    var latestEvaluation: SuggestionEvaluation? {
        (evaluations ?? []).sorted { $0.evaluatedAt < $1.evaluatedAt }.last
    }

    var suggestionConfidenceTier: SuggestionConfidenceTier { SuggestionConfidenceTier(score: suggestionConfidence) }

    var sortedChanges: [PrescriptionChange] {
        (changes ?? []).sorted { lhs, rhs in
            let lhsOrder = changeOrder(for: lhs.changeType)
            let rhsOrder = changeOrder(for: rhs.changeType)
            if lhsOrder != rhsOrder {
                return lhsOrder < rhsOrder
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    init() {}

    convenience init(source: SuggestionSource = .rules, category: SuggestionCategory = .performance, catalogID: String, sessionFrom: WorkoutSession?, targetExercisePrescription: ExercisePrescription? = nil, targetSetPrescription: SetPrescription? = nil, triggerTargetSetID: UUID? = nil, decision: Decision = .pending, outcome: Outcome = .pending, triggerPerformance: ExercisePerformance? = nil, ruleID: SuggestionRule? = nil, trainingStyle: TrainingStyle, requiredEvaluationCount: Int = 1, createdAt: Date = .now, evaluatedAt: Date? = nil, changeReasoning: String? = nil, outcomeReason: String? = nil, changes: [PrescriptionChange] = [], suggestionConfidence: Double = SuggestionConfidenceTier.moderate.defaultScore) {
        self.init()
        self.source = source
        self.category = category
        self.catalogID = catalogID
        self.sessionFrom = sessionFrom
        self.targetExercisePrescription = targetExercisePrescription
        self.targetSetPrescription = targetSetPrescription
        self.triggerTargetSetID = triggerTargetSetID ?? targetSetPrescription?.id
        self.decision = decision
        self.outcome = outcome
        self.triggerPerformance = triggerPerformance
        self.ruleID = ruleID
        self.trainingStyle = trainingStyle
        self.requiredEvaluationCount = requiredEvaluationCount
        self.createdAt = createdAt
        self.evaluatedAt = evaluatedAt
        self.changeReasoning = changeReasoning
        self.outcomeReason = outcomeReason
        self.suggestionConfidence = max(0, min(1, suggestionConfidence))
        self.changes = changes
        for change in changes {
            change.event = self
        }
    }
}

nonisolated private func changeOrder(for changeType: ChangeType) -> Int {
    switch changeType {
    case .increaseWeight, .decreaseWeight:
        return 1
    case .increaseReps, .decreaseReps:
        return 2
    case .increaseRest, .decreaseRest:
        return 3
    case .changeSetType:
        return 4
    case .changeRepRangeMode,
         .increaseRepRangeLower, .decreaseRepRangeLower,
         .increaseRepRangeUpper, .decreaseRepRangeUpper,
         .increaseRepRangeTarget, .decreaseRepRangeTarget:
        return 10
    }
}

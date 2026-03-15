import Foundation
import SwiftData

@Model
final class SuggestionEvent {
    #Index<SuggestionEvent>([\.catalogID], [\.createdAt])

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

    var triggerPerformanceSnapshot: ExercisePerformanceSnapshot = ExercisePerformanceSnapshot.empty
    var triggerTargetSnapshot: ExerciseTargetSnapshot = ExerciseTargetSnapshot.empty

    var trainingStyle: TrainingStyle = TrainingStyle.unknown

    var requiredEvaluationCount: Int = 1
    var evaluationHistory: [EvaluationHistoryEntry] = []

    var createdAt: Date = Date()
    var evaluatedAt: Date?

    var changeReasoning: String?
    var outcomeReason: String?

    @Relationship(deleteRule: .cascade, inverse: \PrescriptionChange.event)
    var changes: [PrescriptionChange]? = [PrescriptionChange]()

    var currentTargetSetIndex: Int? {
        targetSetPrescription?.index
    }

    var triggerTargetSetIndex: Int? {
        guard let triggerTargetSetID else { return nil }
        return triggerTargetSnapshot.sets.first(where: { $0.targetSetID == triggerTargetSetID })?.index
    }

    var isSetScoped: Bool {
        targetSetPrescription != nil || triggerTargetSetID != nil
    }

    var latestEvaluationSnapshot: ExercisePerformanceSnapshot? {
        evaluationHistory.last?.snapshot
    }

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

    convenience init(source: SuggestionSource = .rules, category: SuggestionCategory = .performance, catalogID: String, sessionFrom: WorkoutSession?, targetExercisePrescription: ExercisePrescription? = nil, targetSetPrescription: SetPrescription? = nil, triggerTargetSetID: UUID? = nil, decision: Decision = .pending, outcome: Outcome = .pending, triggerPerformanceSnapshot: ExercisePerformanceSnapshot, triggerTargetSnapshot: ExerciseTargetSnapshot, trainingStyle: TrainingStyle, requiredEvaluationCount: Int = 1, createdAt: Date = .now, evaluatedAt: Date? = nil, changeReasoning: String? = nil, outcomeReason: String? = nil, changes: [PrescriptionChange] = []) {
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
        self.triggerPerformanceSnapshot = triggerPerformanceSnapshot
        self.triggerTargetSnapshot = triggerTargetSnapshot
        self.trainingStyle = trainingStyle
        self.requiredEvaluationCount = requiredEvaluationCount
        self.createdAt = createdAt
        self.evaluatedAt = evaluatedAt
        self.changeReasoning = changeReasoning
        self.outcomeReason = outcomeReason
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

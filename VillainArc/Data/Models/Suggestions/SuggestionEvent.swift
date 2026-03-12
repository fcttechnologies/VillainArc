import Foundation
import SwiftData

@Model
final class SuggestionEvent {
    #Index<SuggestionEvent>([\.catalogID], [\.createdAt])

    var id: UUID = UUID()
    var source: SuggestionSource = SuggestionSource.rules
    var catalogID: String = ""

    @Relationship(deleteRule: .nullify)
    var sessionFrom: WorkoutSession?

    var decision: Decision = Decision.pending
    var outcome: Outcome = Outcome.pending

    var triggerPerformanceSnapshot: ExercisePerformanceSnapshot = ExercisePerformanceSnapshot.empty
    var triggerTargetSnapshot: ExerciseTargetSnapshot = ExerciseTargetSnapshot.empty
    var evaluatedPerformanceSnapshot: ExercisePerformanceSnapshot?

    var trainingStyle: TrainingStyle = TrainingStyle.unknown

    var createdAt: Date = Date()
    var evaluatedAt: Date?

    var changeReasoning: String?
    var outcomeReason: String?

    @Relationship(deleteRule: .cascade, inverse: \PrescriptionChange.event)
    var changes: [PrescriptionChange]? = [PrescriptionChange]()

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

    convenience init(
        source: SuggestionSource = .rules,
        catalogID: String,
        sessionFrom: WorkoutSession?,
        decision: Decision = .pending,
        outcome: Outcome = .pending,
        triggerPerformanceSnapshot: ExercisePerformanceSnapshot,
        triggerTargetSnapshot: ExerciseTargetSnapshot,
        evaluatedPerformanceSnapshot: ExercisePerformanceSnapshot? = nil,
        trainingStyle: TrainingStyle,
        createdAt: Date = .now,
        evaluatedAt: Date? = nil,
        changeReasoning: String? = nil,
        outcomeReason: String? = nil,
        changes: [PrescriptionChange] = []
    ) {
        self.init()
        self.source = source
        self.catalogID = catalogID
        self.sessionFrom = sessionFrom
        self.decision = decision
        self.outcome = outcome
        self.triggerPerformanceSnapshot = triggerPerformanceSnapshot
        self.triggerTargetSnapshot = triggerTargetSnapshot
        self.evaluatedPerformanceSnapshot = evaluatedPerformanceSnapshot
        self.trainingStyle = trainingStyle
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

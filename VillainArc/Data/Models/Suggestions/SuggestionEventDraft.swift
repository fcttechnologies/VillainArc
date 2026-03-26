import Foundation

enum SuggestionEvidenceStrength: Int {
    case heuristic = 0
    case pattern = 1
    case directTargetEvidence = 2
}

struct PrescriptionChangeDraft {
    let changeType: ChangeType
    let previousValue: Double
    let newValue: Double
}

struct SuggestionEventDraft {
    let source: SuggestionSource
    let category: SuggestionCategory
    let targetExercisePrescription: ExercisePrescription
    let targetSetPrescription: SetPrescription?
    let triggerTargetSetID: UUID?
    let rule: SuggestionRule?
    let evidenceStrength: SuggestionEvidenceStrength
    let changeReasoning: String?
    let changes: [PrescriptionChangeDraft]

    init(source: SuggestionSource = .rules, category: SuggestionCategory = .performance, targetExercisePrescription: ExercisePrescription, targetSetPrescription: SetPrescription? = nil, triggerTargetSetID: UUID? = nil, rule: SuggestionRule? = nil, evidenceStrength: SuggestionEvidenceStrength = .pattern, changeReasoning: String? = nil, changes: [PrescriptionChangeDraft]) {
        self.source = source
        self.category = category
        self.targetExercisePrescription = targetExercisePrescription
        self.targetSetPrescription = targetSetPrescription
        self.triggerTargetSetID = triggerTargetSetID ?? targetSetPrescription?.id
        self.rule = rule
        self.evidenceStrength = evidenceStrength
        self.changeReasoning = changeReasoning
        self.changes = changes
    }

    var idScope: EventKey { EventKey(exerciseID: targetExercisePrescription.id, setID: targetSetPrescription?.id) }

    var catalogID: String { targetExercisePrescription.catalogID }

    func contains(_ changeType: ChangeType) -> Bool {
        changes.contains { $0.changeType == changeType }
    }
}

struct EventKey: Hashable {
    let exerciseID: UUID
    let setID: UUID?
}

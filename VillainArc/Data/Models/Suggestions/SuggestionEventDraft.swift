import Foundation

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
    let changeReasoning: String?
    let changes: [PrescriptionChangeDraft]

    init(source: SuggestionSource = .rules, category: SuggestionCategory = .performance, targetExercisePrescription: ExercisePrescription, targetSetPrescription: SetPrescription? = nil, triggerTargetSetID: UUID? = nil, changeReasoning: String? = nil, changes: [PrescriptionChangeDraft]) {
        self.source = source
        self.category = category
        self.targetExercisePrescription = targetExercisePrescription
        self.targetSetPrescription = targetSetPrescription
        self.triggerTargetSetID = triggerTargetSetID ?? targetSetPrescription?.id
        self.changeReasoning = changeReasoning
        self.changes = changes
    }

    var idScope: EventKey {
        EventKey(exerciseID: targetExercisePrescription.id, setID: targetSetPrescription?.id)
    }

    var catalogID: String { targetExercisePrescription.catalogID }

    func contains(_ changeType: ChangeType) -> Bool {
        changes.contains { $0.changeType == changeType }
    }
}

struct EventKey: Hashable {
    let exerciseID: UUID
    let setID: UUID?
}

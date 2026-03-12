import Foundation

struct PrescriptionChangeDraft {
    let changeType: ChangeType
    let previousValue: Double
    let newValue: Double
}

struct SuggestionEventDraft {
    let source: SuggestionSource
    let targetExercisePrescription: ExercisePrescription
    let targetSetPrescription: SetPrescription?
    let targetSetIndex: Int?
    let changeReasoning: String?
    let changes: [PrescriptionChangeDraft]

    init(source: SuggestionSource = .rules, targetExercisePrescription: ExercisePrescription, targetSetPrescription: SetPrescription? = nil, targetSetIndex: Int? = nil, changeReasoning: String? = nil, changes: [PrescriptionChangeDraft]) {
        self.source = source
        self.targetExercisePrescription = targetExercisePrescription
        self.targetSetPrescription = targetSetPrescription
        self.targetSetIndex = targetSetIndex ?? targetSetPrescription?.index
        self.changeReasoning = changeReasoning
        self.changes = changes
    }

    var idScope: EventKey {
        EventKey(exerciseID: targetExercisePrescription.id, setIndex: targetSetIndex ?? targetSetPrescription?.index)
    }

    var catalogID: String { targetExercisePrescription.catalogID }

    func contains(_ changeType: ChangeType) -> Bool {
        changes.contains { $0.changeType == changeType }
    }
}

struct EventKey: Hashable {
    let exerciseID: UUID
    let setIndex: Int?
}

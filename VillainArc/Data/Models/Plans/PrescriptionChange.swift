import Foundation
import SwiftData

@Model
final class PrescriptionChange {
    var id: UUID = UUID()
    @Relationship(deleteRule: .nullify)
    var event: SuggestionEvent?
    
    @Relationship(deleteRule: .nullify)
    var targetExercisePrescription: ExercisePrescription?
    @Relationship(deleteRule: .nullify)
    var targetSetPrescription: SetPrescription?
    var targetSetIndex: Int?
    
    var changeType: ChangeType = ChangeType.increaseWeight
    var previousValue: Double = 0
    var newValue: Double = 0
    
    init() {}

    // Test/sample initializer to reduce setup boilerplate.
    convenience init(event: SuggestionEvent? = nil, targetExercisePrescription: ExercisePrescription? = nil, targetSetPrescription: SetPrescription? = nil, targetSetIndex: Int? = nil, changeType: ChangeType = .increaseWeight, previousValue: Double = 0, newValue: Double = 0) {
        self.init()
        self.event = event
        self.targetExercisePrescription = targetExercisePrescription
        self.targetSetPrescription = targetSetPrescription
        self.targetSetIndex = targetSetIndex ?? targetSetPrescription?.index
        self.changeType = changeType
        self.previousValue = previousValue
        self.newValue = newValue
    }
}

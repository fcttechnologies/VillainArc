import Foundation
import SwiftData

@Model
final class PrescriptionChange {
    var id: UUID = UUID()
    @Relationship(deleteRule: .nullify)
    var event: SuggestionEvent?

    var changeType: ChangeType = ChangeType.increaseWeight
    var previousValue: Double = 0
    var newValue: Double = 0

    init() {}

    // Test/sample initializer to reduce setup boilerplate.
    convenience init(event: SuggestionEvent? = nil, changeType: ChangeType = .increaseWeight, previousValue: Double = 0, newValue: Double = 0) {
        self.init()
        self.event = event
        self.changeType = changeType
        self.previousValue = previousValue
        self.newValue = newValue
    }
}

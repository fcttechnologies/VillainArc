import AppIntents
import Foundation

enum CardioKindAppEnum: String, AppEnum {
    case outdoorRun
    case outdoorWalk
    case treadmillRun
    case treadmillWalk

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Cardio Type")

    static let caseDisplayRepresentations: [CardioKindAppEnum: DisplayRepresentation] = [
        .outdoorRun: "Outdoor Run",
        .outdoorWalk: "Outdoor Walk",
        .treadmillRun: "Treadmill Run",
        .treadmillWalk: "Treadmill Walk"
    ]

    var sessionType: CardioSessionType {
        switch self {
        case .outdoorRun: return CardioSessionType(activity: .run, environment: .outdoor)
        case .outdoorWalk: return CardioSessionType(activity: .walk, environment: .outdoor)
        case .treadmillRun: return CardioSessionType(activity: .run, environment: .indoor)
        case .treadmillWalk: return CardioSessionType(activity: .walk, environment: .indoor)
        }
    }

    init(_ type: CardioSessionType) {
        switch (type.activity, type.environment) {
        case (.walk, .outdoor): self = .outdoorWalk
        case (.run, .indoor): self = .treadmillRun
        case (.walk, .indoor): self = .treadmillWalk
        default: self = .outdoorRun
        }
    }
}

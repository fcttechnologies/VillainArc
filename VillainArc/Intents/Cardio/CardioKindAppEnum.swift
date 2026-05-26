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

    var sessionKind: CardioSessionKind {
        switch self {
        case .outdoorRun: return .outdoorRun
        case .outdoorWalk: return .outdoorWalk
        case .treadmillRun: return .treadmillRun
        case .treadmillWalk: return .treadmillWalk
        }
    }

    init(_ kind: CardioSessionKind) {
        switch kind {
        case .outdoorRun: self = .outdoorRun
        case .outdoorWalk: self = .outdoorWalk
        case .treadmillRun: self = .treadmillRun
        case .treadmillWalk: self = .treadmillWalk
        }
    }
}

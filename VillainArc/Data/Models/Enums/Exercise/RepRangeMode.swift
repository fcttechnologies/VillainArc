import Foundation

enum RepRangeMode: String, CaseIterable, Codable {
    case notSet
    case target
    case range
    case untilFailure
    
    var displayName: String {
        switch self {
        case .notSet:
            return "Not Set"
        case .target:
            return "Target"
        case .range:
            return "Range"
        case .untilFailure:
            return "Until Failure"
        }
    }
}

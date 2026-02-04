import Foundation

enum RepRangeMode: Int, CaseIterable, Codable {
    case notSet = 0
    case target = 1
    case range = 2
    case untilFailure = 3
    
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

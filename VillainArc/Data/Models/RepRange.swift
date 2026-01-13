import Foundation

enum RepRange: Codable {
    case range(lower: Int, upper: Int)
    case exact(Int)
    case untilFailure
    case notSet
    
    var displayText: String {
        switch self {
        case .range(let lower, let upper):
            return "\(lower)-\(upper)"
        case .exact(let reps):
            return "\(reps)"
        case .untilFailure:
            return "Until Failure"
        case .notSet:
            return "Not Set"
        }
    }
}

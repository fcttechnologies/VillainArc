import Foundation

enum RepRange: Codable {
    case range(lower: Int, upper: Int)
    case target(Int)
    case untilFailure
    case notSet
    
    var labelText: String {
        switch self {
        case .range, .notSet:
            return "Rep Range"
        case .target:
            return "Rep Target"
        case .untilFailure:
            return "Rep Goal"
        }
    }

    var displayText: String {
        switch self {
        case .range(let lower, let upper):
            return "\(lower)-\(upper)"
        case .target(let reps):
            return "\(reps)"
        case .untilFailure:
            return "Until Failure"
        case .notSet:
            return "Not Set"
        }
    }
}

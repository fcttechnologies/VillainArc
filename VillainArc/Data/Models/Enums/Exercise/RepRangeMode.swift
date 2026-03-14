import Foundation

enum RepRangeMode: Int, CaseIterable, Codable {
    case notSet = 0
    case target = 1
    case range = 2
    
    var displayName: String {
        switch self {
        case .notSet:
            return String(localized: "Not Set")
        case .target:
            return String(localized: "Target")
        case .range:
            return String(localized: "Range")
        }
    }
}

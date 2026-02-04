import Foundation

enum RestTimeMode: Int, CaseIterable, Codable {
    case allSame = 0
    case individual = 1
    
    var displayName: String {
        switch self {
        case .allSame:
            return "All Same"
        case .individual:
            return "Individual"
        }
    }
}

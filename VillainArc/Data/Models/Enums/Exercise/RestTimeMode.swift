import Foundation

enum RestTimeMode: String, CaseIterable, Codable {
    case allSame
    case byType
    case individual
    
    var displayName: String {
        switch self {
        case .allSame:
            return "All Same"
        case .byType:
            return "By Type"
        case .individual:
            return "Individual"
        }
    }
}

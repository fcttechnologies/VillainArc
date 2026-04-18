import Foundation
import FoundationModels

@Generable
enum SplitMode: String, CaseIterable, Codable {
    case weekly = "Weekly"
    case rotation = "Rotation"

    var displayName: String {
        switch self {
        case .weekly: return String(localized: "Weekly")
        case .rotation: return String(localized: "Rotation")
        }
    }

    var defaultTitle: String {
        switch self {
        case .weekly: return String(localized: "Weekly Split")
        case .rotation: return String(localized: "Rotation Split")
        }
    }

    var summaryLabel: String {
        switch self {
        case .weekly: return String(localized: "Weekly split")
        case .rotation: return String(localized: "Rotation split")
        }
    }
}

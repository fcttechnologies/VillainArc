import Foundation

enum MoodLevel: String, Codable, CaseIterable {
    case notSet
    case sick
    case tired
    case okay
    case good
    case great

    var emoji: String {
        switch self {
        case .great:
            return "😁"
        case .good:
            return "😊"
        case .okay:
            return "😐"
        case .tired:
            return "😴"
        case .sick:
            return "🤒"
        case .notSet:
            return ""
        }
    }

    var label: String {
        rawValue.capitalized
    }
}

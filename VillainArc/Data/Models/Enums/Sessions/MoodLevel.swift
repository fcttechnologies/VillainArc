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
        case .great: return "😁"
        case .good: return "😊"
        case .okay: return "😐"
        case .tired: return "😴"
        case .sick: return "🤒"
        case .notSet: return ""
        }
    }

    var displayName: String {
        switch self {
        case .notSet: return String(localized: "Not Set")
        case .sick: return String(localized: "Sick")
        case .tired: return String(localized: "Tired")
        case .okay: return String(localized: "Okay")
        case .good: return String(localized: "Good")
        case .great: return String(localized: "Great")
        }
    }
}

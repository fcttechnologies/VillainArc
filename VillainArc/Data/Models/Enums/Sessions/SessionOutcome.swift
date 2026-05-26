import Foundation

enum SessionOutcome: String, Codable, CaseIterable {
    case notSet
    case great
    case good
    case ok
    case tough

    var emoji: String {
        switch self {
        case .great: return "💪"
        case .good: return "👍"
        case .ok: return "😐"
        case .tough: return "🥵"
        case .notSet: return ""
        }
    }

    var displayName: String {
        switch self {
        case .notSet: return String(localized: "Not Set")
        case .great: return String(localized: "Great")
        case .good: return String(localized: "Good")
        case .ok: return String(localized: "OK")
        case .tough: return String(localized: "Tough")
        }
    }

    var isPositive: Bool {
        self == .great || self == .good
    }

    static var promptOptions: [SessionOutcome] {
        [.great, .good, .ok, .tough]
    }
}

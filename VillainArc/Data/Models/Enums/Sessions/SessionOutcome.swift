import Foundation

/// User-facing post-session feedback options.
///
/// Lives only on the summary view as the prompt picker. The selected value
/// translates into `UserFeedback` and is written to each accepted
/// `SuggestionEvent` that drove this session's planned work; nothing is
/// persisted on `WorkoutSession` itself.
enum SessionOutcome: String, CaseIterable {
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

    /// How this session-level rating should be recorded on each accepted
    /// suggestion event that drove this session's planned work.
    var userFeedback: UserFeedback? {
        switch self {
        case .great, .good: return .feltGood
        case .ok: return .noChange
        case .tough: return .tooHard
        case .notSet: return nil
        }
    }

    static var promptOptions: [SessionOutcome] {
        [.great, .good, .ok, .tough]
    }
}

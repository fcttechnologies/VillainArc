import Foundation

enum SuggestionConfidenceTier: Int, Codable {
    case exploratory = 0
    case moderate = 1
    case strong = 2

    nonisolated init(score: Double) {
        let clampedScore = max(0, min(1, score))
        switch clampedScore {
        case 0.8...:
            self = .strong
        case 0.6...:
            self = .moderate
        default:
            self = .exploratory
        }
    }

    nonisolated var label: String {
        switch self {
        case .exploratory:
            return "Exploratory"
        case .moderate:
            return "Moderate"
        case .strong:
            return "Strong"
        }
    }

    nonisolated var defaultScore: Double {
        switch self {
        case .exploratory:
            return 0.5
        case .moderate:
            return 0.7
        case .strong:
            return 0.9
        }
    }
}

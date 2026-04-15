import Foundation

enum FitnessLevel: String, Codable, CaseIterable, Hashable {
    case beginner
    case novice
    case intermediate
    case advanced

    var title: String {
        switch self {
        case .beginner:
            return "Beginner"
        case .novice:
            return "Novice"
        case .intermediate:
            return "Intermediate"
        case .advanced:
            return "Advanced"
        }
    }

    var detail: String {
        switch self {
        case .beginner:
            return "New to lifting or still building your base, usually less than 1 year of consistent training."
        case .novice:
            return "Has a consistent gym routine and foundational technique, usually around 1 to 3 years of training."
        case .intermediate:
            return "Experienced with structured programming and progressive overload, usually around 3 to 5 years."
        case .advanced:
            return "Highly experienced lifter with long-term training history, usually 5 or more years."
        }
    }

    static let influenceDescription = String(
        localized: "Pick the level that best matches your lifting experience. Villain Arc uses this to shape plan defaults and how aggressively suggestions progress."
    )

    var nextLevel: FitnessLevel? {
        switch self {
        case .beginner:
            return .novice
        case .novice:
            return .intermediate
        case .intermediate:
            return .advanced
        case .advanced:
            return nil
        }
    }

    private var yearsUntilReview: Int? {
        switch self {
        case .beginner:
            return 1
        case .novice:
            return 2
        case .intermediate:
            return 2
        case .advanced:
            return nil
        }
    }

    func suggestedNextLevelIfReviewDue(lastSetAt: Date, now: Date = .now, calendar: Calendar = .autoupdatingCurrent) -> FitnessLevel? {
        guard let yearsUntilReview, let nextLevel else { return nil }
        guard let dueDate = calendar.date(byAdding: .year, value: yearsUntilReview, to: lastSetAt) else { return nil }
        return now >= dueDate ? nextLevel : nil
    }
}

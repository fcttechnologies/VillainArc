import Foundation

enum TrainingGoalKind: String, Codable, CaseIterable, Hashable {
    case strength
    case hypertrophy
    case endurance
    case generalTraining

    var title: String {
        switch self {
        case .strength:
            return "Strength"
        case .hypertrophy:
            return "Hypertrophy"
        case .endurance:
            return "Endurance"
        case .generalTraining:
            return "General Training"
        }
    }

    var detail: String {
        switch self {
        case .strength:
            return "Bias plans and suggestions toward heavier loading and lower rep work."
        case .hypertrophy:
            return "Favor muscle building volume with moderate rep ranges and balanced progression."
        case .endurance:
            return "Lean toward higher reps, fatigue resistance, and sustained work capacity."
        case .generalTraining:
            return "Keep recommendations balanced for mixed, everyday strength training."
        }
    }

    static let influenceDescription = String(localized: "Villain Arc can use this to shape plan defaults, suggestions, and future coaching around how you like to train.")
}

import Foundation

enum TrainingImpact: String, Codable, CaseIterable, Sendable {
    case contextOnly
    case trainModified
    case pauseTraining

    var title: String {
        switch self {
        case .contextOnly:
            return "Context Only"
        case .trainModified:
            return "Adjust Training"
        case .pauseTraining:
            return "Pause Training"
        }
    }

    var shortTitle: String {
        switch self {
        case .contextOnly:
            return "Context"
        case .trainModified:
            return "Adjusted"
        case .pauseTraining:
            return "Paused"
        }
    }
}

import SwiftUI

enum AppTab: String, CaseIterable, Hashable {
    case home = "Home"
    case health = "Health"

    var title: String {
        switch self {
        case .home: return "Workout"
        case .health: return "Health"
        }
    }

    var symbolImage: String {
        switch self {
        case .home: return "figure.run"
        case .health: return "heart.text.square"
        }
    }
}

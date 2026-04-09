import Foundation

enum AppTab: String, MorphingTabProtocol {
    case home = "Home"
    case health = "Health"

    var title: String {
        switch self {
        case .home: return "Home"
        case .health: return "Health"
        }
    }

    var symbolImage: String {
        switch self {
        case .home: return "house.fill"
        case .health: return "heart.text.square"
        }
    }
}

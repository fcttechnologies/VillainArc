import Foundation

enum Tabs: Hashable {
    case home
    case health

    var title: String {
        switch self {
        case .home: return "Home"
        case .health: return "Health"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .health: return "heart.text.square"
        }
    }
}

import SwiftUI

enum AppTab: String, CaseIterable, Hashable {
    case home = "Home"
    case health = "Health"
    case profile = "Profile"
    case settings = "Settings"

    var title: String {
        switch self {
        case .home: return "Workout"
        case .health: return "Health"
        case .profile: return "Profile"
        case .settings: return "Settings"
        }
    }

    var symbolImage: String {
        switch self {
        case .home: return "figure.run"
        case .health: return "heart.text.square"
        case .profile: return "person.crop.circle"
        case .settings: return "gearshape"
        }
    }
}

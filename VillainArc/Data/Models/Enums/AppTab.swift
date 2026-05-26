import SwiftUI

enum AppTab: String, CaseIterable, Hashable {
    case home = "Home"
    case cardio = "Cardio"
    case health = "Health"
    case profile = "Profile"

    var title: String {
        switch self {
        case .home: return "Workout"
        case .cardio: return "Cardio"
        case .health: return "Health"
        case .profile: return "Profile"
        }
    }

    var symbolImage: String {
        switch self {
        case .home: return "figure.strengthtraining.traditional"
        case .cardio: return "figure.run"
        case .health: return "heart.text.square"
        case .profile: return "person.crop.circle"
        }
    }
}

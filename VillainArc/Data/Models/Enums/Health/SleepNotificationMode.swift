import Foundation

enum SleepNotificationMode: Int, Codable, CaseIterable {
    case off
    case goalOnly
    case coaching

    var title: String {
        switch self {
        case .off:
            return "Off"
        case .goalOnly:
            return "Goal Only"
        case .coaching:
            return "Coaching"
        }
    }
}

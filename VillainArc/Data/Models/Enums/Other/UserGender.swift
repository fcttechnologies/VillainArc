import Foundation

enum UserGender: String, Codable, CaseIterable, Hashable {
    case male
    case female
    case other
    case notSet

    static var selectableCases: [UserGender] { [.male, .female, .other] }

    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .other: return "Other"
        case .notSet: return "Not Set"
        }
    }
}

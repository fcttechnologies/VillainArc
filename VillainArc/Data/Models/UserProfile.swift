import Foundation
import SwiftData

enum UserProfileOnboardingStep: Int, CaseIterable, Hashable {
    case name
    case birthday
    case height

    static let allSteps = UserProfileOnboardingStep.allCases

    static func navigationPath(to step: UserProfileOnboardingStep) -> [UserProfileOnboardingStep] {
        Array(allSteps.prefix(step.rawValue + 1).dropFirst())
    }
}

@Model
class UserProfile {
    var id: UUID = UUID()
    var name: String = ""
    var birthday: Date?
    var dateJoined: Date = Date()
    var heightFeet: Int?
    var heightInches: Double?

    init() {}

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isComplete: Bool {
        firstMissingStep == nil
    }

    var firstMissingStep: UserProfileOnboardingStep? {
        if trimmedName.isEmpty {
            return .name
        }
        if birthday == nil {
            return .birthday
        }
        if heightFeet == nil || heightInches == nil {
            return .height
        }
        return nil
    }
}

extension UserProfile {
    static var all: FetchDescriptor<UserProfile> {
        FetchDescriptor(sortBy: [SortDescriptor(\UserProfile.dateJoined)])
    }
}

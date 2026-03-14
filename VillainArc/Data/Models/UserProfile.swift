import Foundation
import SwiftData

enum UserProfileOnboardingStep: Int, CaseIterable, Hashable {
    case name
    case birthday
    case height

    static func navigationPath(to step: UserProfileOnboardingStep) -> [UserProfileOnboardingStep] {
        Array(allCases.prefix(step.rawValue + 1).dropFirst())
    }
}

@Model
final class UserProfile {
    var name: String = ""
    var birthday: Date?
    var dateJoined: Date = Date()
    var heightCm: Double?

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
        if heightCm == nil {
            return .height
        }
        return nil
    }
}

extension UserProfile {
    static var single: FetchDescriptor<UserProfile> {
        var descriptor = FetchDescriptor<UserProfile>()
        descriptor.fetchLimit = 1
        return descriptor
    }
}

import Foundation
import SwiftData

@Model final class UserProfile {
    var name: String = ""
    var birthday: Date?
    var gender: UserGender = UserGender.notSet
    var dateJoined: Date = Date()
    var heightCm: Double?
    @Attribute(.externalStorage) var profileImageData: Data?

    init() {}

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var isComplete: Bool { firstMissingStep == nil }

    var firstMissingStep: UserProfileOnboardingStep? {
        if trimmedName.isEmpty { return .name }
        if birthday == nil { return .birthday }
        if gender == .notSet { return .gender }
        if heightCm == nil { return .height }
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

import Foundation
import SwiftData

/// What Villain Arc knows about the person that is **its own**: the body facts and the training
/// self-assessment its programming reads.
///
/// The name, the birthday, the country and the avatar are not here and never will be — they are
/// the FCT account's, one home for the whole fleet, read through `AccountProfileField` and
/// ``AccountBirthday``.
@Model final class UserProfile {
    @Attribute(.preserveValueOnDeletion) var id: UUID = VASyncIdentity.userProfileID
    var gender: UserGender = UserGender.notSet
    var dateJoined: Date = Date()
    var heightCm: Double?
    /// The fitness level's raw value. **Stored as text rather than as a `FitnessLevel?` attribute**:
    /// SwiftData drops an optional enum attribute when the sync applier saves it inside a pull
    /// cycle — `apply(_:)` assigns the right case and the applier's own `save()` writes NULL, while
    /// the `Date?` on the next line survives the same save. A `String?` is not affected.
    /// `OnboardingWithLiveEngineTests` reproduces it end to end and is what this is verified by.
    var fitnessLevelRawValue: String?
    var fitnessLevelSetAt: Date?

    /// The typed face of `fitnessLevelRawValue`. Every surface reads and writes this; the raw
    /// column exists only because the attribute kind above it does not survive the applier.
    var fitnessLevel: FitnessLevel? {
        get { fitnessLevelRawValue.flatMap(FitnessLevel.init(rawValue:)) }
        set { fitnessLevelRawValue = newValue?.rawValue }
    }
    init() {}

    var isComplete: Bool { firstMissingStep == nil }

    var firstMissingStep: UserProfileOnboardingStep? {
        if gender == .notSet { return .gender }
        if heightCm == nil { return .height }
        if fitnessLevel == nil || fitnessLevelSetAt == nil { return .fitnessLevel }
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

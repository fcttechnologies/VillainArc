import Foundation
import SwiftData

@Model final class UserProfile {
    @Attribute(.preserveValueOnDeletion) var id: UUID = VASyncIdentity.userProfileID
    var name: String = ""
    var birthday: Date?
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
    @Attribute(.externalStorage) var profileImageData: Data?
    /// The photo's blob-layer reference (`AssetSource.storedText`): authored bytes travel through
    /// `FCTBlobSync`, never inline on the record row. `profileImageData` stays the local render
    /// cache every surface reads. Stored as text so this file compiles into targets that don't
    /// link the blob layer; the typed projection lives with the sync conformances.
    var photoAssetText: String?
    /// True while the current `profileImageData` bytes have not been staged into the blob layer.
    /// Set by `setPhoto(_:)`, cleared by the staging sweep.
    var photoNeedsStaging: Bool = false

    init() {}

    /// The one write path for photo bytes: assigns the cache and marks the blob layer's work.
    /// A nil clears the photo; the staging sweep turns that into an asset detach + object delete.
    func setPhoto(_ data: Data?) {
        profileImageData = data
        photoNeedsStaging = true
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var isComplete: Bool { firstMissingStep == nil }

    var firstMissingStep: UserProfileOnboardingStep? {
        if trimmedName.isEmpty { return .name }
        if birthday == nil { return .birthday }
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

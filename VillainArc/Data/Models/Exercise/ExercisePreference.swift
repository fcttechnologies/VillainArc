import Foundation
import SwiftData

/// What the user has done to a catalog exercise, and the only part of that exercise that syncs.
///
/// The catalog itself ships in the binary (`ExerciseCatalog`) and is seeded into `Exercise` on
/// every install, so it is identical for every account and has no business on the wire. The user's
/// own state about it does, and it is **sparse**: a row exists only for an exercise they actually
/// touched, so an untouched catalog costs nothing.
///
/// `Exercise` stays the single thing the app reads — every list, sort, index and predicate is on
/// it. This is its wire projection, kept in step at one seam in each direction:
/// `Exercise.recordPreference()` going out, ``apply(to:)`` coming in.
///
/// The id derives from the catalog id, so two devices on one account that each favorite the same
/// exercise converge as one row rather than two. Safe for the same reason the catalog's own ids
/// were: a preference is never deleted, so a deterministic id never meets its own tombstone.
@Model final class ExercisePreference {
    #Index<ExercisePreference>([\.catalogID])
    @Attribute(.preserveValueOnDeletion) var id: UUID = UUID()
    var catalogID: String = ""
    var favorite: Bool = false
    var lastAddedAt: Date? = nil
    var suggestionsEnabled: Bool = true
    var preferredWeightChange: Double?

    /// Sync materialization: a pulled row starts empty and `apply(_:)` fills it.
    init(syncID: UUID) { id = syncID }

    init(catalogID: String) {
        id = VASyncIdentity.exercisePreferenceID(catalogID: catalogID)
        self.catalogID = catalogID
    }

    /// Take the exercise's current preference state. The outbound half of the seam.
    func adopt(from exercise: Exercise) {
        favorite = exercise.favorite
        lastAddedAt = exercise.lastAddedAt
        suggestionsEnabled = exercise.suggestionsEnabled
        preferredWeightChange = exercise.preferredWeightChange
    }

    /// Write this preference onto the catalog row it names. The inbound half of the seam.
    func apply(to exercise: Exercise) {
        exercise.favorite = favorite
        exercise.lastAddedAt = lastAddedAt
        exercise.suggestionsEnabled = suggestionsEnabled
        exercise.preferredWeightChange = preferredWeightChange
    }

    /// The exercise this preference names, when the bundled catalog has it. A preference can
    /// legitimately arrive for a catalog id this build does not ship — a device on a newer
    /// catalog authored it — and the row is kept until the seed introduces the exercise.
    func resolvedExercise() -> Exercise? {
        guard let modelContext else { return nil }
        return try? modelContext.fetch(Exercise.withCatalogID(catalogID)).first
    }

    static func withCatalogID(_ catalogID: String) -> FetchDescriptor<ExercisePreference> {
        var descriptor = FetchDescriptor(predicate: #Predicate<ExercisePreference> { $0.catalogID == catalogID })
        descriptor.fetchLimit = 1
        return descriptor
    }
}

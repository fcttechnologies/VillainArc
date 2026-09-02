import CryptoKit
import Foundation

/// The identity rules that make Villain Arc's rows converge across devices instead of duplicating.
///
/// Three kinds of row exist before any sync runs, and each needs its cross-device name minted the
/// same way on every device:
/// - **Singletons** (`AppSettings`, `UserProfile`, `EngineDonation`) carry a fixed uuid the client
///   hard-codes, so two devices that each create one converge as one row under LWW instead of two
///   rows wearing the same job (the platform's singleton convention).
/// - **Catalog-derived rows** (`ExercisePreference`) name a bundled catalog entry that every
///   install already has, so their uuid derives deterministically from the stable catalog id:
///   two devices that each favorite "Bench Press" mint the same uuid and LWW settles the copies
///   as one record instead of two rows wearing the same job.
/// - **Everything else** is minted `UUID()` at creation, exactly once, on the device that authored
///   it.
///
/// The deterministic derivation is versioned by its namespace string: changing either changes every
/// catalog row's identity, which is a full-store reset, so neither changes casually.
nonisolated enum VASyncIdentity {
    static let appSettingsID = UUID(uuidString: "7A2E6F04-0001-4000-8000-56412D534554")!
    static let userProfileID = UUID(uuidString: "7A2E6F04-0002-4000-8000-56412D505246")!
    /// Pinned by `va.engine_donation`'s own check constraint, so a row minted under any other id
    /// is refused on its first push rather than found as a duplicate later.
    static let engineDonationID = UUID(uuidString: "7A2E6F04-0003-4000-8000-56412D444F4E")!

    private static let exerciseNamespace = "com.fcttechnologies.VillainArc.exercise:"
    private static let exercisePreferenceNamespace = "com.fcttechnologies.VillainArc.exercise-preference:"

    /// A stable, RFC-4122-shaped uuid for a catalog exercise. The catalog itself no longer syncs —
    /// it ships in the binary — so this names the **local** row, and the store is rebuilt from the
    /// bundle rather than pulled.
    static func exerciseID(catalogID: String) -> UUID {
        derivedID(namespace: exerciseNamespace, catalogID: catalogID)
    }

    /// A stable, RFC-4122-shaped uuid for an exercise's per-account preference row. Its own
    /// namespace, so a preference and the exercise it names never collide.
    static func exercisePreferenceID(catalogID: String) -> UUID {
        derivedID(namespace: exercisePreferenceNamespace, catalogID: catalogID)
    }

    #if DEBUG
    private static let screenshotStudioNamespace = "com.fcttechnologies.VillainArc.screenshot-studio:"

    /// A stable uuid for one of the Screenshot Studio's demo rows. The studio seeds into the
    /// signed-in account's own store, so its rows need names it can find again: a re-seed
    /// converges on the row it already wrote instead of duplicating it, and each scene fetches
    /// its own curated row rather than whatever else the account holds.
    static func screenshotStudioID(_ name: String) -> UUID {
        derivedID(namespace: screenshotStudioNamespace, catalogID: name)
    }
    #endif

    /// SHA-256 over a namespaced name, truncated to 16 bytes with the version (5) and variant
    /// bits set.
    private static func derivedID(namespace: String, catalogID: String) -> UUID {
        let digest = SHA256.hash(data: Data((namespace + catalogID).utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}

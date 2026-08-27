import CryptoKit
import Foundation

/// The identity rules that make Villain Arc's rows converge across devices instead of duplicating.
///
/// Three kinds of row exist before any sync runs, and each needs its cross-device name minted the
/// same way on every device:
/// - **Singletons** (`AppSettings`, `UserProfile`) carry a fixed uuid the client hard-codes, so two
///   devices that each create one converge as one row under LWW instead of two rows wearing the
///   same job (the platform's singleton convention).
/// - **Catalog rows** (`Exercise`) are seeded from the bundled catalog on every install, so their
///   uuid derives deterministically from the stable catalog id: every install mints the same uuid
///   for "Bench Press" and LWW settles the copies as one record.
/// - **Everything else** is minted `UUID()` at creation, exactly once, on the device that authored
///   it.
///
/// The deterministic derivation is versioned by its namespace string: changing either changes every
/// catalog row's identity, which is a full-store reset, so neither changes casually.
nonisolated enum VASyncIdentity {
    static let appSettingsID = UUID(uuidString: "7A2E6F04-0001-4000-8000-56412D534554")!
    static let userProfileID = UUID(uuidString: "7A2E6F04-0002-4000-8000-56412D505246")!

    private static let exerciseNamespace = "com.fcttechnologies.VillainArc.exercise:"

    /// A stable, RFC-4122-shaped uuid for a catalog exercise: SHA-256 over a namespaced name,
    /// truncated to 16 bytes with the version (5) and variant bits set.
    static func exerciseID(catalogID: String) -> UUID {
        let digest = SHA256.hash(data: Data((exerciseNamespace + catalogID).utf8))
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

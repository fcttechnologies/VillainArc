import FCTSync
import Foundation
import SwiftData

enum SharedModelContainer {

    nonisolated static let appGroupID = "group.com.fcttechnologies.VillainArc1"

    /// The App Group–backed, local-only store wiring, expressed through the shared FCTSync seam.
    /// There is no CloudKit mirror: cross-device continuity is the FCT platform sync engine's job,
    /// and a second sync engine on the same store was ruled out portfolio-wide. The group ID,
    /// store filename, and schema stay app-owned; `AppGroupStoreConfiguration` supplies the
    /// store/container/defaults mechanism.
    nonisolated static let configuration = AppGroupStoreConfiguration(
        appGroupID: appGroupID,
        storeName: "VillainArc.store",
        cloudContainerID: nil,
        versionedSchema: VillainArcSchemaV1.self
    )

    nonisolated static let schema = configuration.schema

    /// `UserDefaults` is not `Sendable`, so the shared instance is `nonisolated(unsafe)` and every
    /// read and write of it is spelled `unsafe` at its expression. What makes that safe is
    /// `UserDefaults`' own documented thread safety: the class synchronizes its own access, so
    /// concurrent readers and writers of this instance are serialized by the framework rather than
    /// by us.
    nonisolated(unsafe) static let sharedDefaults: UserDefaults = {
        do {
            return try configuration.sharedDefaults()
        } catch {
            // Preserve the app's fail-fast diagnostic at the composition layer; the thrown error
            // names the App Groups capability/entitlement to check.
            fatalError("\(error)")
        }
    }()

    nonisolated static let container: ModelContainer = {
        do {
            return try configuration.makeContainer()
        } catch {
            fatalError("Failed to create shared ModelContainer: \(error)")
        }
    }()
}

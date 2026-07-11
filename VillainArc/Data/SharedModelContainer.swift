import FCTSync
import Foundation
import SwiftData

enum SharedModelContainer {

    nonisolated static let appGroupID = "group.com.fcttechnologies.VillainArcCont"

    /// The App Group–backed, CloudKit-mirrored store wiring, expressed through the shared FCTSync
    /// seam. The group ID, store filename, CloudKit private container, and versioned schema stay
    /// app-owned; `AppGroupStoreConfiguration` supplies the store/container/defaults mechanism.
    nonisolated static let configuration = AppGroupStoreConfiguration(
        appGroupID: appGroupID,
        storeName: "VillainArc.store",
        cloudContainerID: "iCloud.com.fcttechnologies.VillainArcCont",
        versionedSchema: VillainArcSchemaV5.self
    )

    nonisolated static let schema = configuration.schema

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
            return try configuration.makeContainer(migrationPlan: VillainArcSchemaMigrationPlan.self)
        } catch {
            fatalError("Failed to create shared ModelContainer: \(error)")
        }
    }()
}

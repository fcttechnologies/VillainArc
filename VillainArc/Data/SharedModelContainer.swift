import SwiftData
import Foundation

enum SharedModelContainer {

    nonisolated static let appGroupID = "group.com.fcttechnologies.VillainArcCont"
    nonisolated(unsafe) static let sharedDefaults: UserDefaults = {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            fatalError("App Group defaults not found for \(appGroupID). Check App Groups capability + entitlements.")
        }
        return defaults
    }()

    nonisolated static let schema = Schema(versionedSchema: VillainArcSchemaV3.self)

    nonisolated static let container: ModelContainer = {
        do {
            guard let url = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
                .appendingPathComponent("VillainArc.store")
            else {
                fatalError("App Group container URL not found for \(appGroupID). Check App Groups capability + entitlements.")
            }

            let configuration = ModelConfiguration(nil, schema: schema, url: url, allowsSave: true, cloudKitDatabase: .private("iCloud.com.fcttechnologies.VillainArcCont"))
            return try ModelContainer(for: schema, migrationPlan: VillainArcSchemaMigrationPlan.self, configurations: [configuration])
        } catch {
            fatalError("Failed to create shared ModelContainer: \(error)")
        }
    }()
}

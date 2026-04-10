import Foundation
import SwiftData

enum WatchSharedModelContainer {
    static let schema = SharedModelContainer.schema

    static let container: ModelContainer = {
        do {
            let applicationSupportURL = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let storeURL = applicationSupportURL.appendingPathComponent("VillainArcWatch.store")

            let configuration = ModelConfiguration(nil, schema: schema, url: storeURL, allowsSave: true, cloudKitDatabase: .private("iCloud.com.fcttechnologies.VillainArcCont"))

            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create watch ModelContainer: \(error)")
        }
    }()
}

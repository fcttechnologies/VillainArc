import Foundation
import SwiftData
import Testing

@testable import VillainArc

struct SchemaMigrationTests {
    @Test @MainActor
    func migratingV2StoreToV3PreservesUserProfileImageAndAppliesV3Defaults() throws {
        let storeURL = FileManager.default.temporaryDirectory.appendingPathComponent("VillainArcMigration-\(UUID().uuidString).store")
        defer {
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: storeURL.path + "-shm"))
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: storeURL.path + "-wal"))
        }

        let v2Schema = Schema(versionedSchema: VillainArcSchemaV2.self)
        let originalImageData = Data([0x01, 0x02, 0x03, 0x04])

        do {
            let configuration = ModelConfiguration(nil, schema: v2Schema, url: storeURL, allowsSave: true)
            let container = try ModelContainer(for: v2Schema, configurations: [configuration])
            let context = ModelContext(container)

            let settings = VillainArcSchemaV2.AppSettings()
            let syncState = VillainArcSchemaV2.HealthSyncState()
            let profile = VillainArcSchemaV2.UserProfile()
            profile.profileImageData = originalImageData

            context.insert(settings)
            context.insert(syncState)
            context.insert(profile)
            try context.save()
        }

        let migratedConfiguration = ModelConfiguration(nil, schema: SharedModelContainer.schema, url: storeURL, allowsSave: true)
        let migratedContainer = try ModelContainer(
            for: SharedModelContainer.schema,
            migrationPlan: VillainArcSchemaMigrationPlan.self,
            configurations: [migratedConfiguration]
        )
        let migratedContext = ModelContext(migratedContainer)

        let migratedSettings = try #require(try migratedContext.fetch(AppSettings.single).first)
        let migratedSyncState = try #require(try migratedContext.fetch(HealthSyncState.single).first)
        let migratedProfile = try #require(try migratedContext.fetch(UserProfile.single).first)

        #expect(migratedSettings.autoFillPlanTargets)
        #expect(migratedSyncState.weeklyCoachingLastDeliveredWeekStart == nil)
        #expect(migratedProfile.profileImageData == originalImageData)
    }
}

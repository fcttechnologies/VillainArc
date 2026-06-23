import Foundation
import SwiftData
import HealthKit

enum VillainArcSchemaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [
            VillainArcSchemaV1.self,
            VillainArcSchemaV2.self,
            VillainArcSchemaV3.self,
            VillainArcSchemaV4.self,
            VillainArcSchemaV5.self
        ]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2, migrateV2toV3, migrateV3toV4, migrateV4toV5]
    }

    static let migrateV1toV2 = MigrationStage.custom(fromVersion: VillainArcSchemaV1.self, toVersion: VillainArcSchemaV2.self, willMigrate: nil) { context in
        let settings = try context.fetch(FetchDescriptor<VillainArcSchemaV2.AppSettings>())
        for setting in settings {
            setting.appearanceMode = .system
            setting.sleepNotificationMode = .goalOnly
        }
        try context.save()
    }

    static let migrateV2toV3 = MigrationStage.custom(fromVersion: VillainArcSchemaV2.self, toVersion: VillainArcSchemaV3.self, willMigrate: nil) { context in
        let settings = try context.fetch(FetchDescriptor<VillainArcSchemaV3.AppSettings>())
        for setting in settings {
            setting.autoFillPlanTargets = true
        }

        let syncStates = try context.fetch(FetchDescriptor<VillainArcSchemaV3.HealthSyncState>())
        for syncState in syncStates {
            syncState.weeklyCoachingLastDeliveredWeekStart = nil
        }

        try context.save()
    }

    static let migrateV3toV4 = MigrationStage.custom(fromVersion: VillainArcSchemaV3.self, toVersion: VillainArcSchemaV4.self, willMigrate: nil) { context in
        let settings = try context.fetch(FetchDescriptor<VillainArcSchemaV4.AppSettings>())
        for setting in settings {
            setting.assumeTargetRPEOnComplete = true
            setting.prefersTargetReferenceWhenPlanned = true
        }

        try context.save()
    }

    static let migrateV4toV5 = MigrationStage.custom(fromVersion: VillainArcSchemaV4.self, toVersion: VillainArcSchemaV5.self, willMigrate: nil) { context in
        let settings = try context.fetch(FetchDescriptor<AppSettings>())
        for setting in settings {
            setting.temperatureUnit = .systemDefault
            setting.previousSetReferenceSource = .anyWorkout
            setting.hydrationUnit = .systemDefault
            setting.hydrationNotificationMode = .goalOnly
            setting.speedUnit = .systemDefault
            setting.autoCompleteSetAfterRPE = true
        }

        let syncStates = try context.fetch(FetchDescriptor<HealthSyncState>())
        for syncState in syncStates {
            syncState.heartRateSyncedRangeStart = nil
            syncState.heartRateSyncedRangeEnd = nil
            syncState.restingHeartRateSyncedRangeStart = nil
            syncState.restingHeartRateSyncedRangeEnd = nil
            syncState.walkingHeartRateSyncedRangeStart = nil
            syncState.walkingHeartRateSyncedRangeEnd = nil
            syncState.heartRateVariabilitySyncedRangeStart = nil
            syncState.heartRateVariabilitySyncedRangeEnd = nil
            syncState.respiratoryRateSyncedRangeStart = nil
            syncState.respiratoryRateSyncedRangeEnd = nil
            syncState.wristTemperatureSyncedRangeStart = nil
            syncState.wristTemperatureSyncedRangeEnd = nil
            syncState.dietaryWaterSyncedRangeStart = nil
            syncState.dietaryWaterSyncedRangeEnd = nil
        }

        try context.save()
    }

}

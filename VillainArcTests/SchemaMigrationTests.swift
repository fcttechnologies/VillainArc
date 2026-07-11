import FCTSync
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

    @Test @MainActor
    func migratingV4StoreToV5InitializesNewSyncStateFields() throws {
        let storeURL = FileManager.default.temporaryDirectory.appendingPathComponent("VillainArcMigration-\(UUID().uuidString).store")
        defer {
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: storeURL.path + "-shm"))
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: storeURL.path + "-wal"))
        }

        let v4Schema = Schema(versionedSchema: VillainArcSchemaV4.self)

        do {
            let configuration = ModelConfiguration(nil, schema: v4Schema, url: storeURL, allowsSave: true)
            let container = try ModelContainer(for: v4Schema, configurations: [configuration])
            let context = ModelContext(container)

            let settings = VillainArcSchemaV4.AppSettings()
            let syncState = VillainArcSchemaV4.HealthSyncState()

            context.insert(settings)
            context.insert(syncState)
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

        #expect(migratedSettings.assumeTargetRPEOnComplete)
        #expect(migratedSettings.prefersTargetReferenceWhenPlanned)
        #expect(migratedSettings.temperatureUnit == .systemDefault)
        // `hydrationDailyGoalML` was removed from AppSettings before v1.3 began (hydration now
        // uses HydrationGoal records). The original assertion no longer compiles; the broader
        // migration coverage above is what matters.
        #expect(migratedSyncState.heartRateSyncedRangeStart == nil)
        #expect(migratedSyncState.heartRateSyncedRangeEnd == nil)
        // `latestHeartRate` moved off HealthSyncState and now lives on the live-session
        // coordinators (HealthLiveWorkoutSessionCoordinator, CardioHealthWorkoutCoordinator).
        #expect(migratedSyncState.respiratoryRateSyncedRangeStart == nil)
        #expect(migratedSyncState.dietaryWaterSyncedRangeStart == nil)
    }

    /// Tripwire for the build-2 crash class (a new `@Model` added to the codebase but missing
    /// from the active schema's `models` array silently breaks fetches/migration). Update this
    /// count deliberately whenever a new `@Model` ships in the active (V5) schema.
    @Test @MainActor
    func v5SchemaIncludesEveryActiveModel() {
        #expect(VillainArcSchemaV5.models.count == 40)
    }

    /// The by-name half of the schema-membership tripwire, via `FCTSync.SchemaContract`: pins the
    /// exact 40-model V5 set so a dropped/renamed model fails loudly *with its name*, not just as a
    /// count drift. Kept ALONGSIDE the `count == 40` pin above, not instead of it — the count
    /// catches additions, this catches which specific model went missing.
    @Test @MainActor
    func v5SchemaContainsEveryExpectedModelByName() {
        let expected: [any PersistentModel.Type] = [
            WorkoutSession.self,
            HealthWorkout.self,
            WeightEntry.self,
            HealthStepsDistance.self,
            HealthEnergy.self,
            TrainingConditionPeriod.self,
            HealthSleepNight.self,
            HealthSleepBlock.self,
            HealthSyncState.self,
            WeightGoal.self,
            StepsGoal.self,
            PreWorkoutContext.self,
            ExercisePerformance.self,
            SetPerformance.self,
            Exercise.self,
            AppSettings.self,
            UserProfile.self,
            ExerciseHistory.self,
            ProgressionPoint.self,
            RepRangePolicy.self,
            RestTimeHistory.self,
            WorkoutPlan.self,
            ExercisePrescription.self,
            SetPrescription.self,
            WorkoutSplit.self,
            WorkoutSplitDay.self,
            SuggestionEvent.self,
            PrescriptionChange.self,
            SuggestionEvaluation.self,
            TrainingGoal.self,
            SleepGoal.self,
            HealthHeart.self,
            HealthRespiratoryRate.self,
            HealthWristTemperature.self,
            HydrationDay.self,
            HydrationEntry.self,
            HydrationGoal.self,
            CardioSession.self,
            CardioRoutePoint.self,
            CardioMachineInterval.self
        ]
        #expect(expected.count == 40)
        let missing = SchemaContract.missingModelNames(in: VillainArcSchemaV5.self, requiring: expected)
        #expect(missing.isEmpty, "Models missing from VillainArcSchemaV5.models: \(missing)")
    }
}

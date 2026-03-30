import Foundation
import HealthKit
import SwiftData

actor HealthSyncCoordinator {
    static let shared = HealthSyncCoordinator()

    private var isSyncingWorkouts = false
    private var isSyncingWeightEntries = false
    private var needsAnotherWorkoutSync = false
    private var needsAnotherWeightEntriesSync = false

    private init() {}

    func syncAll() async {
        await syncWorkouts()
        await syncWeightEntries()
        await HealthDailyMetricsSync.shared.syncAll()
    }

    func syncWorkouts() async {
        guard HealthAuthorizationManager.hasRequestedWorkoutAuthorization else { return }
        if isSyncingWorkouts {
            needsAnotherWorkoutSync = true
            return
        }

        while true {
            isSyncingWorkouts = true
            needsAnotherWorkoutSync = false

            let context = makeBackgroundContext()
            guard SetupGuard.isReady(context: context) else {
                isSyncingWorkouts = false
                return
            }

            let retainRemovedHealthData = currentKeepRemovedHealthDataSetting(context: context)
            let descriptor = HKAnchoredObjectQueryDescriptor(predicates: [.workout()], anchor: HealthSyncPreferences.workoutAnchor)

            do {
                let result = try await descriptor.result(for: HealthAuthorizationManager.healthStore)
                let shouldAdvanceAnchor = await shouldAdvanceWorkoutAnchor(for: result)

                let linkedSessionIDs = Dictionary(uniqueKeysWithValues: result.addedSamples.compactMap { workout in
                    HealthMetadataKeys.workoutSessionID(from: workout).map { (workout.uuid, $0) }
                })
                await HealthWorkoutMirrorImporter.shared.importWorkouts(result.addedSamples, linkedSessionIDsByWorkout: linkedSessionIDs)

                for deletedObject in result.deletedObjects { try handleDeletedHealthWorkout(id: deletedObject.uuid, retainRemovedHealthData: retainRemovedHealthData, context: context) }

                try context.save()
                if shouldAdvanceAnchor {
                    HealthSyncPreferences.workoutAnchor = result.newAnchor
                }
                logWorkoutSyncIfNeeded(result: result)
            } catch {
                print("Failed to sync Health workouts: \(error)")
            }

            isSyncingWorkouts = false
            guard needsAnotherWorkoutSync else { return }
        }
    }

    func syncWeightEntries() async {
        guard HealthAuthorizationManager.hasRequestedBodyMassAuthorization else { return }
        if isSyncingWeightEntries {
            needsAnotherWeightEntriesSync = true
            return
        }

        while true {
            isSyncingWeightEntries = true
            needsAnotherWeightEntriesSync = false

            let context = makeBackgroundContext()
            guard SetupGuard.isReady(context: context) else {
                isSyncingWeightEntries = false
                return
            }

            let retainRemovedHealthData = currentKeepRemovedHealthDataSetting(context: context)
            let descriptor = HKAnchoredObjectQueryDescriptor(predicates: [.quantitySample(type: HealthKitCatalog.bodyMassType)], anchor: HealthSyncPreferences.weightEntryAnchor)

            do {
                let result = try await descriptor.result(for: HealthAuthorizationManager.healthStore)
                let shouldAdvanceAnchor = await shouldAdvanceWeightAnchor(for: result)

                for sample in result.addedSamples { try upsertWeightEntry(for: sample, context: context) }

                for deletedObject in result.deletedObjects { try handleDeletedWeightEntry(id: deletedObject.uuid, retainRemovedHealthData: retainRemovedHealthData, context: context) }

                try context.save()
                if shouldAdvanceAnchor {
                    HealthSyncPreferences.weightEntryAnchor = result.newAnchor
                }
                logWeightSyncIfNeeded(result: result)
            } catch {
                print("Failed to sync Health weight entries: \(error)")
            }

            isSyncingWeightEntries = false
            guard needsAnotherWeightEntriesSync else { return }
        }
    }

    func applyRemovedHealthDataRetentionSetting() async {
        guard !isSyncingWorkouts, !isSyncingWeightEntries else { return }

        let context = makeBackgroundContext()
        guard currentKeepRemovedHealthDataSetting(context: context) == false else { return }

        do {
            let unavailableWorkouts = try context.fetch(HealthWorkout.unavailableHealthWorkouts)
            let unavailableWeightEntries = try context.fetch(WeightEntry.unavailableEntries)

            for workout in unavailableWorkouts { context.delete(workout) }

            for entry in unavailableWeightEntries { context.delete(entry) }

            guard unavailableWorkouts.isEmpty == false || unavailableWeightEntries.isEmpty == false else { return }

            try context.save()
        } catch { print("Failed to apply removed Apple Health data retention setting: \(error)") }
    }

    private func logWorkoutSyncIfNeeded(result: HKAnchoredObjectQueryDescriptor<HKWorkout>.Result) {
        guard !result.addedSamples.isEmpty || !result.deletedObjects.isEmpty else { return }
        print("Processed Apple Health workout changes: \(result.addedSamples.count) added or updated, \(result.deletedObjects.count) deleted.")
    }

    private func logWeightSyncIfNeeded(result: HKAnchoredObjectQueryDescriptor<HKQuantitySample>.Result) {
        guard !result.addedSamples.isEmpty || !result.deletedObjects.isEmpty else { return }
        print("Processed Apple Health weight changes: \(result.addedSamples.count) added or updated, \(result.deletedObjects.count) deleted.")
    }

    private func shouldAdvanceWorkoutAnchor(for result: HKAnchoredObjectQueryDescriptor<HKWorkout>.Result) async -> Bool {
        if !result.deletedObjects.isEmpty { return true }
        if result.addedSamples.contains(where: { HealthMetadataKeys.workoutSessionID(from: $0) == nil }) { return true }
        return await HealthReadProbe.hasReadableWorkoutSampleBeyondKnownLocalCount()
    }

    private func shouldAdvanceWeightAnchor(for result: HKAnchoredObjectQueryDescriptor<HKQuantitySample>.Result) async -> Bool {
        if !result.deletedObjects.isEmpty { return true }
        if result.addedSamples.contains(where: { HealthMetadataKeys.weightEntryID(from: $0) == nil }) { return true }
        return await HealthReadProbe.hasReadableBodyMassSampleBeyondKnownLocalCount()
    }

    private func upsertWeightEntry(for sample: HKQuantitySample, context: ModelContext) throws { _ = try HealthWeightEntryLinker.upsertWeightEntry(for: sample, context: context) }

    private func handleDeletedHealthWorkout(id: UUID, retainRemovedHealthData: Bool, context: ModelContext) throws {
        guard let existing = try context.fetch(HealthWorkout.byHealthWorkoutUUID(id)).first else { return }

        if retainRemovedHealthData {
            existing.isAvailableInHealthKit = false
        } else {
            context.delete(existing)
        }
    }

    private func handleDeletedWeightEntry(id: UUID, retainRemovedHealthData: Bool, context: ModelContext) throws {
        guard let existing = try context.fetch(WeightEntry.byHealthSampleUUID(id)).first else { return }

        if retainRemovedHealthData {
            existing.isAvailableInHealthKit = false
        } else {
            context.delete(existing)
        }
    }

    private func currentKeepRemovedHealthDataSetting(context: ModelContext) -> Bool {
        (try? context.fetch(AppSettings.single).first?.keepRemovedHealthData) ?? true
    }

    private func makeBackgroundContext() -> ModelContext {
        let context = ModelContext(SharedModelContainer.container)
        context.autosaveEnabled = false
        return context
    }
}

extension HealthWorkout {
    fileprivate static var unavailableHealthWorkouts: FetchDescriptor<HealthWorkout> {
        let predicate = #Predicate<HealthWorkout> { !$0.isAvailableInHealthKit }
        return FetchDescriptor(predicate: predicate)
    }
}

nonisolated enum HealthWeightEntryLinker {
    static func samplePredicate(for entryID: UUID) -> NSPredicate {
        HKQuery.predicateForObjects(withMetadataKey: HealthMetadataKeys.weightEntryID, operatorType: .equalTo, value: entryID.uuidString)
    }

    @discardableResult static func upsertWeightEntry(for sample: HKQuantitySample, context: ModelContext) throws -> WeightEntry {
        let existing = try fetchExistingEntry(for: sample, context: context)
        let weight = sample.quantity.doubleValue(for: HealthKitCatalog.kilogramUnit)
        let isAppOwnedEntry = HealthMetadataKeys.weightEntryID(from: sample) != nil

        if let existing {
            existing.date = sample.endDate
            existing.weight = weight
            existing.hasBeenExportedToHealth = isAppOwnedEntry
            existing.healthSampleUUID = sample.uuid
            existing.isAvailableInHealthKit = true
            return existing
        }

        let entry = WeightEntry(date: sample.endDate, weight: weight, hasBeenExportedToHealth: isAppOwnedEntry, healthSampleUUID: sample.uuid, isAvailableInHealthKit: true)
        context.insert(entry)
        return entry
    }

    private static func fetchExistingEntry(for sample: HKQuantitySample, context: ModelContext) throws -> WeightEntry? {
        if let existing = try context.fetch(WeightEntry.byHealthSampleUUID(sample.uuid)).first { return existing }

        guard let entryID = HealthMetadataKeys.weightEntryID(from: sample) else { return nil }
        return try context.fetch(WeightEntry.byID(entryID)).first
    }
}

import Foundation
import HealthKit
import SwiftData

actor HealthSyncCoordinator {
    static let shared = HealthSyncCoordinator()

    private var isSyncingWorkouts = false
    private var isSyncingWeightEntries = false
    private var needsAnotherWorkoutSync = false
    private var needsAnotherWeightEntriesSync = false
    private var pendingWorkoutSyncAllowsReadProbe = false
    private var pendingWeightEntriesSyncAllowsReadProbe = false

    private init() {}

    func syncAll() async {
        await syncWorkouts(allowsReadProbe: true)
        await syncWeightEntries(allowsReadProbe: true)
        await HealthDailyMetricsSync.shared.syncAll()
        await HealthSleepSync.shared.syncAll()
    }

    func syncWorkouts(allowsReadProbe: Bool = false) async {
        guard HealthAuthorizationManager.hasRequestedWorkoutAuthorization else { return }
        if isSyncingWorkouts {
            needsAnotherWorkoutSync = true
            pendingWorkoutSyncAllowsReadProbe = pendingWorkoutSyncAllowsReadProbe || allowsReadProbe
            return
        }

        var nextPassAllowsReadProbe = allowsReadProbe
        while true {
            isSyncingWorkouts = true
            needsAnotherWorkoutSync = false
            let currentPassAllowsReadProbe = nextPassAllowsReadProbe
            nextPassAllowsReadProbe = false

            let context = makeBackgroundContext()
            guard SetupGuard.isReady(context: context) else {
                isSyncingWorkouts = false
                return
            }

            let retainRemovedHealthData = currentKeepRemovedHealthDataSetting(context: context)
            let descriptor = HKAnchoredObjectQueryDescriptor(predicates: [.workout()], anchor: HealthSyncPreferences.workoutAnchor)

            do {
                let result = try await descriptor.result(for: HealthAuthorizationManager.healthStore)
                let shouldAdvanceAnchor = await shouldAdvanceWorkoutAnchor(for: result, allowsReadProbe: currentPassAllowsReadProbe, context: context)

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
            nextPassAllowsReadProbe = pendingWorkoutSyncAllowsReadProbe
            pendingWorkoutSyncAllowsReadProbe = false
        }
    }

    func syncWeightEntries(allowsReadProbe: Bool = false) async {
        guard HealthAuthorizationManager.hasRequestedBodyMassAuthorization else { return }
        if isSyncingWeightEntries {
            needsAnotherWeightEntriesSync = true
            pendingWeightEntriesSyncAllowsReadProbe = pendingWeightEntriesSyncAllowsReadProbe || allowsReadProbe
            return
        }

        var nextPassAllowsReadProbe = allowsReadProbe
        while true {
            isSyncingWeightEntries = true
            needsAnotherWeightEntriesSync = false
            let currentPassAllowsReadProbe = nextPassAllowsReadProbe
            nextPassAllowsReadProbe = false

            let context = makeBackgroundContext()
            guard SetupGuard.isReady(context: context) else {
                isSyncingWeightEntries = false
                return
            }

            let retainRemovedHealthData = currentKeepRemovedHealthDataSetting(context: context)
            let descriptor = HKAnchoredObjectQueryDescriptor(predicates: [.quantitySample(type: HealthKitCatalog.bodyMassType)], anchor: HealthSyncPreferences.weightEntryAnchor)

            do {
                let result = try await descriptor.result(for: HealthAuthorizationManager.healthStore)
                let shouldAdvanceAnchor = await shouldAdvanceWeightAnchor(for: result, allowsReadProbe: currentPassAllowsReadProbe, context: context)

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
            nextPassAllowsReadProbe = pendingWeightEntriesSyncAllowsReadProbe
            pendingWeightEntriesSyncAllowsReadProbe = false
        }
    }

    func applyRemovedHealthDataRetentionSetting() async {
        guard !isSyncingWorkouts, !isSyncingWeightEntries else { return }

        let context = makeBackgroundContext()
        guard currentKeepRemovedHealthDataSetting(context: context) == false else { return }

        do {
            let unavailableWorkouts = try context.fetch(HealthWorkout.unavailableHealthWorkouts)
            let unavailableWeightEntries = try context.fetch(WeightEntry.unavailableEntries)
            let unavailableSleepNights = try context.fetch(HealthSleepNight.unavailableHealthSleepNights)

            for workout in unavailableWorkouts { context.delete(workout) }

            for entry in unavailableWeightEntries { context.delete(entry) }

            for night in unavailableSleepNights { context.delete(night) }

            guard unavailableWorkouts.isEmpty == false || unavailableWeightEntries.isEmpty == false || unavailableSleepNights.isEmpty == false else { return }

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

    private func shouldAdvanceWorkoutAnchor(
        for result: HKAnchoredObjectQueryDescriptor<HKWorkout>.Result,
        allowsReadProbe: Bool,
        context: ModelContext
    ) async -> Bool {
        if result.addedSamples.contains(where: { HealthMetadataKeys.workoutSessionID(from: $0) == nil }) { return true }
        if containsExternallyOwnedWorkoutDeletion(result.deletedObjects, context: context) { return true }
        guard allowsReadProbe else { return false }
        return await HealthReadProbe.hasReadableWorkoutSampleBeyondKnownLocalCount()
    }

    private func shouldAdvanceWeightAnchor(
        for result: HKAnchoredObjectQueryDescriptor<HKQuantitySample>.Result,
        allowsReadProbe: Bool,
        context: ModelContext
    ) async -> Bool {
        if result.addedSamples.contains(where: { HealthMetadataKeys.weightEntryID(from: $0) == nil }) { return true }
        if containsExternallyOwnedWeightDeletion(result.deletedObjects, context: context) { return true }
        guard allowsReadProbe else { return false }
        return await HealthReadProbe.hasReadableBodyMassSampleBeyondKnownLocalCount()
    }

    private func containsExternallyOwnedWorkoutDeletion(_ deletedObjects: [HKDeletedObject], context: ModelContext) -> Bool {
        deletedObjects.contains { deletedObject in
            let existing = try? context.fetch(HealthWorkout.byHealthWorkoutUUID(deletedObject.uuid)).first
            guard let existing else {
                return false
            }
            return existing.workoutSession == nil
        }
    }

    private func containsExternallyOwnedWeightDeletion(_ deletedObjects: [HKDeletedObject], context: ModelContext) -> Bool {
        deletedObjects.contains { deletedObject in
            let existing = try? context.fetch(WeightEntry.byHealthSampleUUID(deletedObject.uuid)).first
            guard let existing else {
                return false
            }
            return existing.hasBeenExportedToHealth == false
        }
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

extension HealthSleepNight {
    fileprivate static var unavailableHealthSleepNights: FetchDescriptor<HealthSleepNight> {
        let predicate = #Predicate<HealthSleepNight> { !$0.isAvailableInHealthKit }
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

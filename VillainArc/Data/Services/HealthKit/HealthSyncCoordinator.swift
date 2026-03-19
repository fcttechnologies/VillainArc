import Foundation
import HealthKit
import SwiftData

enum HealthWeightEntryLinker {
    private static let bodyMassType = HKQuantityType(.bodyMass)
    private static let weightUnit = HKUnit.gramUnit(with: .kilo)

    static func samplePredicate(for entryID: UUID) -> NSPredicate {
        HKQuery.predicateForObjects(withMetadataKey: HealthMetadataKeys.weightEntryID, operatorType: .equalTo, value: entryID.uuidString)
    }

    @MainActor
    @discardableResult
    static func upsertWeightEntry(for sample: HKQuantitySample, context: ModelContext, lastSyncedAt: Date = .now) throws -> WeightEntry {
        let existing = try fetchExistingEntry(for: sample, context: context)
        let weight = sample.quantity.doubleValue(for: weightUnit)

        if let existing {
            existing.recordedAt = sample.endDate
            existing.weight = weight
            existing.hasBeenExportedToHealth = true
            existing.healthSampleUUID = sample.uuid
            existing.isAvailableInHealthKit = true
            existing.lastSyncedAt = lastSyncedAt
            return existing
        }

        let entry = WeightEntry(
            recordedAt: sample.endDate,
            weight: weight,
            hasBeenExportedToHealth: true,
            healthSampleUUID: sample.uuid,
            isAvailableInHealthKit: true,
            lastSyncedAt: lastSyncedAt
        )
        context.insert(entry)
        return entry
    }

    @MainActor
    private static func fetchExistingEntry(for sample: HKQuantitySample, context: ModelContext) throws -> WeightEntry? {
        if let existing = try context.fetch(WeightEntry.byHealthSampleUUID(sample.uuid)).first {
            return existing
        }

        guard let entryID = HealthMetadataKeys.weightEntryID(from: sample) else { return nil }
        return try context.fetch(WeightEntry.byID(entryID)).first
    }
}

@MainActor
final class HealthSyncCoordinator {
    static let shared = HealthSyncCoordinator()

    private let authorizationManager = HealthAuthorizationManager.shared
    private let bodyMassType = HKQuantityType(.bodyMass)

    private var isSyncingWorkouts = false
    private var isSyncingWeightEntries = false

    private init() {}

    func syncAll() async {
        await syncWorkouts()
        await syncWeightEntries()
    }

    func syncWorkouts() async {
        guard authorizationManager.hasRequestedWorkoutAuthorization else { return }
        guard !isSyncingWorkouts else { return }

        isSyncingWorkouts = true
        defer { isSyncingWorkouts = false }

        let context = SharedModelContainer.container.mainContext
        let retainRemovedHealthData = currentKeepRemovedHealthDataSetting(context: context)
        let descriptor = HKAnchoredObjectQueryDescriptor(predicates: [.workout()], anchor: HealthSyncPreferences.workoutAnchor)

        do {
            let result = try await descriptor.result(for: authorizationManager.healthStore)
            let syncedAt = Date()

            for workout in result.addedSamples {
                try upsertHealthWorkout(for: workout, syncedAt: syncedAt, context: context)
            }

            for deletedObject in result.deletedObjects {
                try handleDeletedHealthWorkout(id: deletedObject.uuid, syncedAt: syncedAt, retainRemovedHealthData: retainRemovedHealthData, context: context)
            }

            try context.save()
            HealthSyncPreferences.workoutAnchor = result.newAnchor
            print("Health workout sync completed. Added or updated: \(result.addedSamples.count). Deleted: \(result.deletedObjects.count).")
        } catch {
            print("Failed to sync Health workouts: \(error)")
        }
    }

    func syncWeightEntries() async {
        guard authorizationManager.hasRequestedBodyMassAuthorization else { return }
        guard !isSyncingWeightEntries else { return }

        isSyncingWeightEntries = true
        defer { isSyncingWeightEntries = false }

        let context = SharedModelContainer.container.mainContext
        let retainRemovedHealthData = currentKeepRemovedHealthDataSetting(context: context)
        let descriptor = HKAnchoredObjectQueryDescriptor(predicates: [.quantitySample(type: bodyMassType)], anchor: HealthSyncPreferences.weightEntryAnchor)

        do {
            let result = try await descriptor.result(for: authorizationManager.healthStore)
            let syncedAt = Date()

            for sample in result.addedSamples {
                try upsertWeightEntry(for: sample, syncedAt: syncedAt, context: context)
            }

            for deletedObject in result.deletedObjects {
                try handleDeletedWeightEntry(id: deletedObject.uuid, syncedAt: syncedAt, retainRemovedHealthData: retainRemovedHealthData, context: context)
            }

            try context.save()
            HealthSyncPreferences.weightEntryAnchor = result.newAnchor
            print("Health weight sync completed. Added or updated: \(result.addedSamples.count). Deleted: \(result.deletedObjects.count).")
        } catch {
            print("Failed to sync Health weight entries: \(error)")
        }
    }

    func applyRemovedHealthDataRetentionSetting() async {
        guard !isSyncingWorkouts, !isSyncingWeightEntries else { return }

        let context = SharedModelContainer.container.mainContext
        guard currentKeepRemovedHealthDataSetting(context: context) == false else { return }

        do {
            let unavailableWorkouts = try context.fetch(HealthWorkout.unavailableHealthWorkouts)
            let unavailableWeightEntries = try context.fetch(WeightEntry.unavailableEntries)

            for workout in unavailableWorkouts {
                context.delete(workout)
            }

            for entry in unavailableWeightEntries {
                context.delete(entry)
            }

            guard unavailableWorkouts.isEmpty == false || unavailableWeightEntries.isEmpty == false else { return }

            try context.save()
            print("Removed \(unavailableWorkouts.count) retained Apple Health workouts and \(unavailableWeightEntries.count) retained Apple Health weight entries after disabling retention.")
        } catch {
            print("Failed to apply removed Apple Health data retention setting: \(error)")
        }
    }

    private func upsertHealthWorkout(for workout: HKWorkout, syncedAt: Date, context: ModelContext) throws {
        let linkedWorkoutSession = try fetchLinkedWorkoutSession(for: workout, context: context)
        _ = try HealthWorkoutLinker.upsertHealthWorkout(for: workout, linkedTo: linkedWorkoutSession, context: context, lastSyncedAt: syncedAt)
    }

    private func upsertWeightEntry(for sample: HKQuantitySample, syncedAt: Date, context: ModelContext) throws {
        _ = try HealthWeightEntryLinker.upsertWeightEntry(for: sample, context: context, lastSyncedAt: syncedAt)
    }

    private func handleDeletedHealthWorkout(id: UUID, syncedAt: Date, retainRemovedHealthData: Bool, context: ModelContext) throws {
        guard let existing = try context.fetch(HealthWorkout.byHealthWorkoutUUID(id)).first else { return }

        if retainRemovedHealthData {
            existing.isAvailableInHealthKit = false
            existing.lastSyncedAt = syncedAt
        } else {
            context.delete(existing)
        }
    }

    private func handleDeletedWeightEntry(id: UUID, syncedAt: Date, retainRemovedHealthData: Bool, context: ModelContext) throws {
        guard let existing = try context.fetch(WeightEntry.byHealthSampleUUID(id)).first else { return }

        if retainRemovedHealthData {
            existing.isAvailableInHealthKit = false
            existing.lastSyncedAt = syncedAt
        } else {
            context.delete(existing)
        }
    }

    private func fetchLinkedWorkoutSession(for workout: HKWorkout, context: ModelContext) throws -> WorkoutSession? {
        guard let workoutSessionID = HealthMetadataKeys.workoutSessionID(from: workout) else { return nil }
        return try context.fetch(WorkoutSession.byID(workoutSessionID)).first
    }

    private func currentKeepRemovedHealthDataSetting(context: ModelContext) -> Bool {
        (try? context.fetch(AppSettings.single).first?.keepRemovedHealthData) ?? true
    }
}

private extension HealthWorkout {
    static var unavailableHealthWorkouts: FetchDescriptor<HealthWorkout> {
        let predicate = #Predicate<HealthWorkout> { !$0.isAvailableInHealthKit }
        return FetchDescriptor(predicate: predicate)
    }
}

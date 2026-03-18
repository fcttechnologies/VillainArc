import Foundation
import HealthKit
import SwiftData

@MainActor
final class HealthWorkoutSyncCoordinator {
    static let shared = HealthWorkoutSyncCoordinator()

    private let authorizationManager = HealthAuthorizationManager.shared
    private var isSyncing = false

    private init() {}

    func syncWorkouts() async {
        guard authorizationManager.hasRequestedWorkoutAuthorization else { return }
        guard !isSyncing else { return }

        isSyncing = true
        defer { isSyncing = false }

        let context = SharedModelContainer.container.mainContext
        let retainRemovedHealthWorkouts = currentKeepRemovedHealthWorkoutsSetting(context: context)
        let descriptor = HKAnchoredObjectQueryDescriptor(predicates: [.workout()], anchor: HealthSyncPreferences.workoutAnchor)

        do {
            let result = try await descriptor.result(for: authorizationManager.healthStore)
            let syncedAt = Date()

            for workout in result.addedSamples {
                try upsertHealthWorkout(for: workout, syncedAt: syncedAt, context: context)
            }

            for deletedObject in result.deletedObjects {
                try handleDeletedHealthWorkout(id: deletedObject.uuid, syncedAt: syncedAt, retainRemovedHealthWorkouts: retainRemovedHealthWorkouts, context: context)
            }

            try context.save()
            HealthSyncPreferences.workoutAnchor = result.newAnchor
            print("Health workout sync completed. Added or updated: \(result.addedSamples.count). Deleted: \(result.deletedObjects.count).")
        } catch {
            print("Failed to sync Health workouts: \(error)")
        }
    }

    func applyRemovedWorkoutRetentionSetting() async {
        guard !isSyncing else { return }

        let context = SharedModelContainer.container.mainContext
        let retainRemovedHealthWorkouts = currentKeepRemovedHealthWorkoutsSetting(context: context)
        guard !retainRemovedHealthWorkouts else { return }

        do {
            let retainedDeletedWorkouts = try context.fetch(unavailableHealthWorkoutsDescriptor)
            guard !retainedDeletedWorkouts.isEmpty else { return }

            for workout in retainedDeletedWorkouts {
                context.delete(workout)
            }

            try context.save()
            print("Removed \(retainedDeletedWorkouts.count) retained Apple Health workout mirrors after disabling retention.")
        } catch {
            print("Failed to apply removed Apple Health workout retention setting: \(error)")
        }
    }

    private func upsertHealthWorkout(for workout: HKWorkout, syncedAt: Date, context: ModelContext) throws {
        let linkedWorkoutSession = try fetchLinkedWorkoutSession(for: workout, context: context)
        _ = try HealthWorkoutLinker.upsertHealthWorkout(for: workout, linkedTo: linkedWorkoutSession, context: context, lastSyncedAt: syncedAt)
    }

    private func handleDeletedHealthWorkout(id: UUID, syncedAt: Date, retainRemovedHealthWorkouts: Bool, context: ModelContext) throws {
        guard let existing = try fetchHealthWorkout(id: id, context: context) else { return }

        if retainRemovedHealthWorkouts {
            existing.isAvailableInHealthKit = false
            existing.lastSyncedAt = syncedAt
        } else {
            context.delete(existing)
        }
    }

    private func fetchHealthWorkout(id: UUID, context: ModelContext) throws -> HealthWorkout? {
        try context.fetch(HealthWorkout.byHealthWorkoutUUID(id)).first
    }

    private func fetchLinkedWorkoutSession(for workout: HKWorkout, context: ModelContext) throws -> WorkoutSession? {
        guard let workoutSessionID = HealthWorkoutMetadataKeys.workoutSessionID(from: workout) else { return nil }
        return try context.fetch(WorkoutSession.byID(workoutSessionID)).first
    }

    private func currentKeepRemovedHealthWorkoutsSetting(context: ModelContext) -> Bool {
        (try? context.fetch(AppSettings.single).first?.keepRemovedHealthWorkouts) ?? true
    }

    private var unavailableHealthWorkoutsDescriptor: FetchDescriptor<HealthWorkout> {
        let predicate = #Predicate<HealthWorkout> { !$0.isAvailableInHealthKit }
        return FetchDescriptor(predicate: predicate)
    }
}

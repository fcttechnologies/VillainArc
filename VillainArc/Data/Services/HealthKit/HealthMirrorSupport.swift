import Foundation
import HealthKit
import SwiftData

nonisolated enum HealthMetadataKeys {
    static let workoutSessionID = "com.villainarc.workoutsession.id"
    static let weightEntryID = "com.villainarc.weightentry.id"

    static func workoutSessionID(from workout: HKWorkout) -> UUID? {
        guard let rawValue = workout.metadata?[workoutSessionID] as? String else { return nil }
        return UUID(uuidString: rawValue)
    }

    static func weightEntryID(from sample: HKSample) -> UUID? {
        guard let rawValue = sample.metadata?[weightEntryID] as? String else { return nil }
        return UUID(uuidString: rawValue)
    }
}

nonisolated enum HealthWorkoutLinker {
    static func workoutPredicate(for sessionID: UUID) -> NSPredicate {
        HKQuery.predicateForObjects(withMetadataKey: HealthMetadataKeys.workoutSessionID, operatorType: .equalTo, value: sessionID.uuidString)
    }

    @discardableResult static func upsertHealthWorkout(for workout: HKWorkout, linkedTo workoutSession: WorkoutSession?, context: ModelContext) throws -> HealthWorkout {
        if let workoutSession { workoutSession.hasBeenExportedToHealth = true }

        if let existing = try context.fetch(HealthWorkout.byHealthWorkoutUUID(workout.uuid)).first {
            existing.update(from: workout)
            if let workoutSession { existing.workoutSession = workoutSession }
            return existing
        }

        let healthWorkout = HealthWorkout(workout: workout, workoutSession: workoutSession)
        context.insert(healthWorkout)
        return healthWorkout
    }
}

nonisolated enum HealthMirrorQueries {
    static func findSavedWorkout(for sessionID: UUID) async throws -> HKWorkout? {
        let descriptor = HKSampleQueryDescriptor(predicates: [.workout(HealthWorkoutLinker.workoutPredicate(for: sessionID))], sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)], limit: 1)
        return try await descriptor.result(for: HealthAuthorizationManager.healthStore).first
    }

    static func findSavedWeightSample(for entryID: UUID) async throws -> HKQuantitySample? {
        let predicate = HKQuery.predicateForObjects(withMetadataKey: HealthMetadataKeys.weightEntryID, operatorType: .equalTo, value: entryID.uuidString)
        let descriptor = HKSampleQueryDescriptor(predicates: [.quantitySample(type: HealthKitCatalog.bodyMassType, predicate: predicate)], sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)], limit: 1)
        return try await descriptor.result(for: HealthAuthorizationManager.healthStore).first
    }
}

nonisolated enum HealthWorkoutEffortSampleBuilder {
    static func makeSample(for session: WorkoutSession, endDate: Date) -> HKQuantitySample? {
        let mappedEffortScore = mappedWorkoutEffortScore(for: session)
        guard mappedEffortScore > 0 else { return nil }

        let duration = endDate.timeIntervalSince(session.startedAt)
        guard duration > 0 else { return nil }

        let sampleStartDate = session.startedAt.addingTimeInterval(min(1, max(0.001, duration / 2)))
        let quantity = HKQuantity(unit: HealthKitCatalog.appleEffortScoreUnit, doubleValue: mappedEffortScore)

        return HKQuantitySample(type: HealthKitCatalog.workoutEffortScoreType, quantity: quantity, start: sampleStartDate, end: endDate)
    }

    private static func mappedWorkoutEffortScore(for session: WorkoutSession) -> Double {
        let effort = max(0, min(session.postEffort, 10))
        guard effort > 0 else { return 0 }
        return Double(effort)
    }
}

actor HealthWorkoutMirrorImporter {
    static let shared = HealthWorkoutMirrorImporter()

    private var inFlightWorkoutImports: Set<UUID> = []

    private init() {}

    func importWorkout(_ workout: HKWorkout, linkedSessionID: UUID?) {
        guard beginImport(for: workout.uuid) else { return }
        defer { endImport(for: workout.uuid) }

        let context = ModelContext(SharedModelContainer.container)
        context.autosaveEnabled = false

        do {
            let linkedWorkoutSession = try fetchLinkedWorkoutSession(for: linkedSessionID, context: context)
            _ = try HealthWorkoutLinker.upsertHealthWorkout(for: workout, linkedTo: linkedWorkoutSession, context: context)
            try context.save()
        } catch {
            print("Failed to import mirrored Health workout \(workout.uuid): \(error)")
        }
    }

    func importWorkouts(_ workouts: [HKWorkout], linkedSessionIDsByWorkout: [UUID: UUID]) {
        let eligible = workouts.filter { beginImport(for: $0.uuid) }
        guard !eligible.isEmpty else { return }
        defer { eligible.forEach { endImport(for: $0.uuid) } }

        let context = ModelContext(SharedModelContainer.container)
        context.autosaveEnabled = false

        do {
            for workout in eligible {
                let linkedWorkoutSession = try fetchLinkedWorkoutSession(for: linkedSessionIDsByWorkout[workout.uuid], context: context)
                _ = try HealthWorkoutLinker.upsertHealthWorkout(for: workout, linkedTo: linkedWorkoutSession, context: context)
            }
            try context.save()
        } catch {
            print("Failed to batch import \(eligible.count) mirrored Health workouts: \(error)")
        }
    }

    private func fetchLinkedWorkoutSession(for workoutSessionID: UUID?, context: ModelContext) throws -> WorkoutSession? {
        guard let workoutSessionID else { return nil }
        return try context.fetch(WorkoutSession.byID(workoutSessionID)).first
    }

    private func beginImport(for healthWorkoutUUID: UUID) -> Bool {
        guard !inFlightWorkoutImports.contains(healthWorkoutUUID) else { return false }
        inFlightWorkoutImports.insert(healthWorkoutUUID)
        return true
    }

    private func endImport(for healthWorkoutUUID: UUID) {
        inFlightWorkoutImports.remove(healthWorkoutUUID)
    }
}

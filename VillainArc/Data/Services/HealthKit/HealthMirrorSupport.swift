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
    private static let bodyMassType = HKQuantityType(.bodyMass)

    static func findSavedWorkout(for sessionID: UUID) async throws -> HKWorkout? {
        let descriptor = HKSampleQueryDescriptor(predicates: [.workout(HealthWorkoutLinker.workoutPredicate(for: sessionID))], sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)], limit: 1)
        return try await descriptor.result(for: HealthAuthorizationManager.healthStore).first
    }

    static func findSavedWeightSample(for entryID: UUID) async throws -> HKQuantitySample? {
        let predicate = HKQuery.predicateForObjects(withMetadataKey: HealthMetadataKeys.weightEntryID, operatorType: .equalTo, value: entryID.uuidString)
        let descriptor = HKSampleQueryDescriptor(predicates: [.quantitySample(type: bodyMassType, predicate: predicate)], sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)], limit: 1)
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
        let quantity = HKQuantity(unit: .appleEffortScore(), doubleValue: mappedEffortScore)

        return HKQuantitySample(type: HKQuantityType(.workoutEffortScore), quantity: quantity, start: sampleStartDate, end: endDate)
    }

    private static func mappedWorkoutEffortScore(for session: WorkoutSession) -> Double {
        let effort = max(0, min(session.postEffort, 10))
        guard effort > 0 else { return 0 }
        return Double(effort)
    }
}

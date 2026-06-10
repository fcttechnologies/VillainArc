import Foundation
import HealthKit
import SwiftData

nonisolated enum HealthMetadataKeys {
    static let workoutSessionID = "com.villainarc.workoutsession.id"
    static let cardioSessionID = "com.villainarc.cardiosession.id"
    static let weightEntryID = "com.villainarc.weightentry.id"
    static let hydrationEntryID = "com.villainarc.hydrationentry.id"

    static func workoutSessionID(from workout: HKWorkout) -> UUID? {
        guard let rawValue = workout.metadata?[workoutSessionID] as? String else { return nil }
        return UUID(uuidString: rawValue)
    }

    static func cardioSessionID(from workout: HKWorkout) -> UUID? {
        guard let rawValue = workout.metadata?[cardioSessionID] as? String else { return nil }
        return UUID(uuidString: rawValue)
    }

    static func weightEntryID(from sample: HKSample) -> UUID? {
        guard let rawValue = sample.metadata?[weightEntryID] as? String else { return nil }
        return UUID(uuidString: rawValue)
    }

    static func hydrationEntryID(from sample: HKSample) -> UUID? {
        guard let rawValue = sample.metadata?[hydrationEntryID] as? String else { return nil }
        return UUID(uuidString: rawValue)
    }
}

nonisolated enum HealthWorkoutLinker {
    static func workoutPredicate(for sessionID: UUID) -> NSPredicate {
        HKQuery.predicateForObjects(withMetadataKey: HealthMetadataKeys.workoutSessionID, operatorType: .equalTo, value: sessionID.uuidString)
    }

    static func cardioWorkoutPredicate(for cardioSessionID: UUID) -> NSPredicate {
        HKQuery.predicateForObjects(withMetadataKey: HealthMetadataKeys.cardioSessionID, operatorType: .equalTo, value: cardioSessionID.uuidString)
    }

    @discardableResult static func upsertHealthWorkout(for workout: HKWorkout, linkedTo workoutSession: WorkoutSession?, cardioSession: CardioSession? = nil, context: ModelContext) throws -> HealthWorkout {
        if let workoutSession { workoutSession.hasBeenExportedToHealth = true }

        if let existing = try context.fetch(HealthWorkout.byHealthWorkoutUUID(workout.uuid)).first {
            existing.update(from: workout)
            if let workoutSession { existing.workoutSession = workoutSession }
            if let cardioSession {
                existing.cardioSession = cardioSession
                cardioSession.healthWorkout = existing
                cardioSession.healthWorkoutUUID = workout.uuid
            }
            return existing
        }

        let healthWorkout = HealthWorkout(workout: workout, workoutSession: workoutSession, cardioSession: cardioSession)
        if let cardioSession {
            cardioSession.healthWorkout = healthWorkout
            cardioSession.healthWorkoutUUID = workout.uuid
        }
        context.insert(healthWorkout)
        return healthWorkout
    }
}

nonisolated enum HealthMirrorQueries {
    static func findSavedWorkout(for sessionID: UUID) async throws -> HKWorkout? {
        let descriptor = HKSampleQueryDescriptor(predicates: [.workout(HealthWorkoutLinker.workoutPredicate(for: sessionID))], sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)], limit: 1)
        return try await descriptor.result(for: HealthAuthorizationManager.healthStore).first
    }

    static func findSavedCardioWorkout(for cardioSessionID: UUID) async throws -> HKWorkout? {
        let descriptor = HKSampleQueryDescriptor(predicates: [.workout(HealthWorkoutLinker.cardioWorkoutPredicate(for: cardioSessionID))], sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)], limit: 1)
        return try await descriptor.result(for: HealthAuthorizationManager.healthStore).first
    }

    static func findSavedWeightSample(for entryID: UUID) async throws -> HKQuantitySample? {
        let predicate = HKQuery.predicateForObjects(withMetadataKey: HealthMetadataKeys.weightEntryID, operatorType: .equalTo, value: entryID.uuidString)
        let descriptor = HKSampleQueryDescriptor(predicates: [.quantitySample(type: HealthKitCatalog.bodyMassType, predicate: predicate)], sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)], limit: 1)
        return try await descriptor.result(for: HealthAuthorizationManager.healthStore).first
    }

    static func findSavedHydrationSample(for entryID: UUID) async throws -> HKQuantitySample? {
        let predicate = HKQuery.predicateForObjects(withMetadataKey: HealthMetadataKeys.hydrationEntryID, operatorType: .equalTo, value: entryID.uuidString)
        let descriptor = HKSampleQueryDescriptor(predicates: [.quantitySample(type: HealthKitCatalog.dietaryWaterType, predicate: predicate)], sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)], limit: 1)
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

    static func makeSample(for session: CardioSession, endDate: Date) -> HKQuantitySample? {
        let effort = max(0, min(session.postEffort, 10))
        guard effort > 0, let startedAt = session.startedAt else { return nil }

        let duration = endDate.timeIntervalSince(startedAt)
        guard duration > 0 else { return nil }

        let sampleStartDate = startedAt.addingTimeInterval(min(1, max(0.001, duration / 2)))
        let quantity = HKQuantity(unit: HealthKitCatalog.appleEffortScoreUnit, doubleValue: Double(effort))

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

    func importWorkout(_ workout: HKWorkout, linkedSessionID: UUID? = nil, linkedCardioSessionID: UUID? = nil) {
        guard beginImport(for: workout.uuid) else { return }
        defer { endImport(for: workout.uuid) }

        let context = ModelContext(SharedModelContainer.container)
        context.autosaveEnabled = false

        do {
            let linkedWorkoutSession = try fetchLinkedWorkoutSession(for: linkedSessionID, context: context)
            let linkedCardioSession = try fetchLinkedCardioSession(for: linkedCardioSessionID, context: context)
            _ = try HealthWorkoutLinker.upsertHealthWorkout(for: workout, linkedTo: linkedWorkoutSession, cardioSession: linkedCardioSession, context: context)
            try context.save()
        } catch {
            AppLog.error("Failed to import mirrored Health workout \(workout.uuid)", error: error)
        }
    }

    func importWorkouts(_ workouts: [HKWorkout], linkedSessionIDsByWorkout: [UUID: UUID], linkedCardioSessionIDsByWorkout: [UUID: UUID] = [:]) {
        let eligible = workouts.filter { beginImport(for: $0.uuid) }
        guard !eligible.isEmpty else { return }
        defer { eligible.forEach { endImport(for: $0.uuid) } }

        let context = ModelContext(SharedModelContainer.container)
        context.autosaveEnabled = false

        do {
            for workout in eligible {
                let linkedWorkoutSession = try fetchLinkedWorkoutSession(for: linkedSessionIDsByWorkout[workout.uuid], context: context)
                let linkedCardioSession = try fetchLinkedCardioSession(for: linkedCardioSessionIDsByWorkout[workout.uuid], context: context)
                _ = try HealthWorkoutLinker.upsertHealthWorkout(for: workout, linkedTo: linkedWorkoutSession, cardioSession: linkedCardioSession, context: context)
            }
            try context.save()
        } catch {
            AppLog.error("Failed to batch import \(eligible.count) mirrored Health workouts", error: error)
        }
    }

    private func fetchLinkedWorkoutSession(for workoutSessionID: UUID?, context: ModelContext) throws -> WorkoutSession? {
        guard let workoutSessionID else { return nil }
        return try context.fetch(WorkoutSession.byID(workoutSessionID)).first
    }

    private func fetchLinkedCardioSession(for cardioSessionID: UUID?, context: ModelContext) throws -> CardioSession? {
        guard let cardioSessionID else { return nil }
        return try context.fetch(CardioSession.byID(cardioSessionID)).first
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

import Foundation
import HealthKit
import SwiftData

@MainActor
final class HealthExportCoordinator {
    static let shared = HealthExportCoordinator()

    private let authorizationManager = HealthAuthorizationManager.shared
    private let bodyMassType = HKQuantityType(.bodyMass)
    private let weightUnit = HKUnit.gramUnit(with: .kilo)
    private var inFlightSessionIDs: Set<UUID> = []
    private var inFlightWeightEntryIDs: Set<UUID> = []
    private var isReconcilingSessions = false
    private var isReconcilingWeightEntries = false

    private init() {}

    func exportIfEligible(session: WorkoutSession) async {
        guard authorizationManager.canWriteWorkouts else { return }
        guard !inFlightSessionIDs.contains(session.id) else { return }

        inFlightSessionIDs.insert(session.id)
        defer { inFlightSessionIDs.remove(session.id) }

        await exportLoadedSession(session)
    }

    func exportIfEligible(sessionID: UUID) async {
        guard authorizationManager.canWriteWorkouts else { return }
        guard !inFlightSessionIDs.contains(sessionID) else { return }

        inFlightSessionIDs.insert(sessionID)
        defer { inFlightSessionIDs.remove(sessionID) }

        let context = SharedModelContainer.container.mainContext

        guard let session = try? context.fetch(WorkoutSession.byID(sessionID)).first else { return }
        await exportLoadedSession(session)
    }

    func exportIfEligible(weightEntry: WeightEntry) async {
        guard authorizationManager.canWriteBodyMass else { return }
        guard !inFlightWeightEntryIDs.contains(weightEntry.id) else { return }

        inFlightWeightEntryIDs.insert(weightEntry.id)
        defer { inFlightWeightEntryIDs.remove(weightEntry.id) }

        await exportLoadedWeightEntry(weightEntry)
    }

    func exportIfEligible(weightEntryID: UUID) async {
        guard authorizationManager.canWriteBodyMass else { return }
        guard !inFlightWeightEntryIDs.contains(weightEntryID) else { return }

        inFlightWeightEntryIDs.insert(weightEntryID)
        defer { inFlightWeightEntryIDs.remove(weightEntryID) }

        let context = SharedModelContainer.container.mainContext
        guard let weightEntry = try? context.fetch(WeightEntry.byID(weightEntryID)).first else { return }
        await exportLoadedWeightEntry(weightEntry)
    }

    private func exportLoadedSession(_ session: WorkoutSession) async {
        guard session.statusValue == .done else { return }
        guard !session.isHidden else { return }
        guard !session.hasBeenExportedToHealth else { return }

        let context = SharedModelContainer.container.mainContext
        if let existingWorkout = try? await HealthLiveWorkoutSessionCoordinator.shared.findSavedWorkout(for: session.id) {
            do {
                try HealthWorkoutLinker.upsertHealthWorkout(for: existingWorkout, linkedTo: session, context: context, lastSyncedAt: .now)
                saveContext(context: context)
                print("Linked existing Apple Health workout \(existingWorkout.uuid) to local session \(session.id)")
            } catch {
                print("Failed to link existing Apple Health workout for \(session.id): \(error)")
            }
            return
        }

        let endDate = max(session.startedAt, session.endedAt ?? session.startedAt)
        let workoutEffortSample = makeWorkoutEffortSample(for: session, endDate: endDate)
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor
        let workoutBuilder = HKWorkoutBuilder(healthStore: authorizationManager.healthStore, configuration: configuration, device: nil)

        do {
            try await workoutBuilder.beginCollection(at: session.startedAt)
            try await workoutBuilder.addMetadata(authorizationManager.metadata(for: session))
            try await workoutBuilder.endCollection(at: endDate)

            guard let workout = try await workoutBuilder.finishWorkout() else {
                print("HealthKit finished export for \(session.id), but the workout sample was unavailable.")
                return
            }

            if let workoutEffortSample, authorizationManager.canWriteWorkoutEffortScore {
                do {
                    _ = try await authorizationManager.healthStore.relateWorkoutEffortSample(workoutEffortSample,with: workout, activity: nil)
                } catch {
                    print("Failed to relate workout effort score for \(session.id): \(error)")
                }
            }

            try HealthWorkoutLinker.upsertHealthWorkout(for: workout, linkedTo: session, context: context, lastSyncedAt: endDate)
            saveContext(context: context)
            print("Saved workout session \(session.id) to Apple Health as \(workout.uuid)")
        } catch {
            print("Failed to export workout \(session.id) to HealthKit: \(error)")
        }
    }

    private func exportLoadedWeightEntry(_ weightEntry: WeightEntry) async {
        guard !weightEntry.hasBeenExportedToHealth else { return }

        let context = SharedModelContainer.container.mainContext
        if let existingSample = try? await findSavedWeightSample(for: weightEntry.id) {
            do {
                try HealthWeightEntryLinker.upsertWeightEntry(for: existingSample, context: context, lastSyncedAt: .now)
                saveContext(context: context)
                print("Linked existing Apple Health body mass sample \(existingSample.uuid) to local weight entry \(weightEntry.id)")
            } catch {
                print("Failed to link existing Apple Health body mass sample for \(weightEntry.id): \(error)")
            }
            return
        }

        let sampleDate = weightEntry.recordedAt
        let quantity = HKQuantity(unit: weightUnit, doubleValue: weightEntry.weight)
        let sample = HKQuantitySample(
            type: bodyMassType,
            quantity: quantity,
            start: sampleDate,
            end: sampleDate,
            metadata: authorizationManager.metadata(for: weightEntry)
        )

        do {
            try await authorizationManager.healthStore.save(sample)
            try HealthWeightEntryLinker.upsertWeightEntry(for: sample, context: context, lastSyncedAt: sampleDate)
            saveContext(context: context)
            print("Saved weight entry \(weightEntry.id) to Apple Health as \(sample.uuid)")
        } catch {
            print("Failed to export weight entry \(weightEntry.id) to HealthKit: \(error)")
        }
    }

    func reconcilePendingExports() async {
        await reconcileCompletedSessions()
        await reconcileWeightEntries()
    }

    func reconcileCompletedSessions() async {
        guard authorizationManager.canWriteWorkouts else { return }
        guard !isReconcilingSessions else { return }

        isReconcilingSessions = true
        defer { isReconcilingSessions = false }

        let context = SharedModelContainer.container.mainContext
        let sessions = (try? context.fetch(WorkoutSession.completedSessionsNeedingHealthExport)) ?? []
        print("Reconciling \(sessions.count) completed workouts for Apple Health export")

        for session in sessions {
            await exportIfEligible(session: session)
        }

        print("Finished Apple Health export reconciliation")
    }

    func reconcileWeightEntries() async {
        guard authorizationManager.canWriteBodyMass else { return }
        guard !isReconcilingWeightEntries else { return }

        isReconcilingWeightEntries = true
        defer { isReconcilingWeightEntries = false }

        let context = SharedModelContainer.container.mainContext
        let weightEntries = (try? context.fetch(WeightEntry.entriesNeedingHealthExport)) ?? []
        print("Reconciling \(weightEntries.count) weight entries for Apple Health export")

        for weightEntry in weightEntries {
            await exportIfEligible(weightEntry: weightEntry)
        }

        print("Finished Apple Health weight export reconciliation")
    }

    private func findSavedWeightSample(for entryID: UUID) async throws -> HKQuantitySample? {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: bodyMassType, predicate: HealthWeightEntryLinker.samplePredicate(for: entryID))],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1
        )

        return try await descriptor.result(for: authorizationManager.healthStore).first
    }

    private func makeWorkoutEffortSample(for session: WorkoutSession, endDate: Date) -> HKQuantitySample? {
        let mappedEffortScore = mappedWorkoutEffortScore(for: session)
        guard mappedEffortScore > 0 else { return nil }

        let duration = endDate.timeIntervalSince(session.startedAt)
        guard duration > 0 else { return nil }

        let sampleStartDate = session.startedAt.addingTimeInterval(min(1, max(0.001, duration / 2)))
        let quantity = HKQuantity(unit: .appleEffortScore(), doubleValue: mappedEffortScore)

        return HKQuantitySample(type: HKQuantityType(.workoutEffortScore), quantity: quantity, start: sampleStartDate, end: endDate)
    }

    private func mappedWorkoutEffortScore(for session: WorkoutSession) -> Double {
        let effort = max(0, min(session.postEffort, 10))
        guard effort > 0 else { return 0 }
        return Double(effort)
    }
}

import Foundation
import HealthKit
import SwiftData

actor HealthExportCoordinator {
    static let shared = HealthExportCoordinator()
    private var inFlightSessionIDs: Set<UUID> = []
    private var inFlightWeightEntryIDs: Set<UUID> = []
    private var isReconcilingSessions = false
    private var isReconcilingWeightEntries = false

    private init() {}

    func exportIfEligible(sessionID: UUID) async {
        guard HealthAuthorizationManager.canWriteWorkouts else { return }
        guard !inFlightSessionIDs.contains(sessionID) else { return }

        inFlightSessionIDs.insert(sessionID)
        defer { inFlightSessionIDs.remove(sessionID) }

        let context = makeBackgroundContext()
        guard let session = try? context.fetch(WorkoutSession.byID(sessionID)).first else { return }
        await exportLoadedSession(session)
    }

    func exportIfEligible(weightEntryID: UUID) async {
        guard HealthAuthorizationManager.canWriteBodyMass else { return }
        guard !inFlightWeightEntryIDs.contains(weightEntryID) else { return }

        inFlightWeightEntryIDs.insert(weightEntryID)
        defer { inFlightWeightEntryIDs.remove(weightEntryID) }

        let context = makeBackgroundContext()
        guard let weightEntry = try? context.fetch(WeightEntry.byID(weightEntryID)).first else { return }
        await exportLoadedWeightEntry(weightEntry, context: context)
    }

    private func exportLoadedSession(_ session: WorkoutSession) async {
        guard session.statusValue == .done else { return }
        guard !session.isHidden else { return }
        guard !session.hasBeenExportedToHealth else { return }

        if let existingWorkout = try? await HealthMirrorQueries.findSavedWorkout(for: session.id) {
            await HealthWorkoutMirrorImporter.shared.importWorkout(existingWorkout, linkedSessionID: session.id)
            AppLog.info("Linked existing Apple Health workout \(existingWorkout.uuid) to local session \(session.id).")
            return
        }

        let endDate = max(session.startedAt, session.endedAt ?? session.startedAt)
        let workoutEffortSample = HealthWorkoutEffortSampleBuilder.makeSample(for: session, endDate: endDate)
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor
        let workoutBuilder = HKWorkoutBuilder(healthStore: HealthAuthorizationManager.healthStore, configuration: configuration, device: nil)

        do {
            try await workoutBuilder.beginCollection(at: session.startedAt)
            try await workoutBuilder.addMetadata(HealthAuthorizationManager.metadata(for: session))
            try await workoutBuilder.endCollection(at: endDate)

            guard let workout = try await workoutBuilder.finishWorkout() else {
                AppLog.error("HealthKit finished export for \(session.id), but the workout sample was unavailable.")
                return
            }

            if let workoutEffortSample, HealthAuthorizationManager.canWriteWorkoutEffortScore {
                do {
                    _ = try await HealthAuthorizationManager.healthStore.relateWorkoutEffortSample(workoutEffortSample, with: workout, activity: nil)
                } catch {
                    AppLog.error("Failed to relate workout effort score for \(session.id)", error: error)
                }
            }

            await HealthWorkoutMirrorImporter.shared.importWorkout(workout, linkedSessionID: session.id)
            AppLog.info("Saved workout session \(session.id) to Apple Health as \(workout.uuid).")
        } catch { AppLog.error("Failed to export workout \(session.id) to HealthKit", error: error) }
    }

    private func exportLoadedWeightEntry(_ weightEntry: WeightEntry, context: ModelContext) async {
        guard !weightEntry.hasBeenExportedToHealth else { return }

        if let existingSample = try? await HealthMirrorQueries.findSavedWeightSample(for: weightEntry.id) {
            do {
                try HealthWeightEntryLinker.upsertWeightEntry(for: existingSample, context: context)
                try context.save()
                AppLog.info("Linked existing Apple Health body mass sample \(existingSample.uuid) to local weight entry \(weightEntry.id).")
            } catch { AppLog.error("Failed to link existing Apple Health body mass sample for \(weightEntry.id)", error: error) }
            return
        }

        let sampleDate = weightEntry.date
        let quantity = HKQuantity(unit: HealthKitCatalog.kilogramUnit, doubleValue: weightEntry.weight)
        let sample = HKQuantitySample(type: HealthKitCatalog.bodyMassType, quantity: quantity, start: sampleDate, end: sampleDate, metadata: HealthAuthorizationManager.metadata(for: weightEntry))

        do {
            try await HealthAuthorizationManager.healthStore.save(sample)
            try HealthWeightEntryLinker.upsertWeightEntry(for: sample, context: context)
            try context.save()
            AppLog.info("Saved weight entry \(weightEntry.id) to Apple Health as \(sample.uuid).")
        } catch { AppLog.error("Failed to export weight entry \(weightEntry.id) to HealthKit", error: error) }
    }

    func reconcilePendingExports() async {
        await reconcileCompletedSessions()
        await reconcileWeightEntries()
    }

    func reconcileCompletedSessions() async {
        guard HealthAuthorizationManager.canWriteWorkouts else { return }
        guard !isReconcilingSessions else { return }

        isReconcilingSessions = true
        defer { isReconcilingSessions = false }

        let context = makeBackgroundContext()
        let sessionIDs = ((try? context.fetch(WorkoutSession.completedSessionsNeedingHealthExport)) ?? []).map(\.id)

        for sessionID in sessionIDs { await exportIfEligible(sessionID: sessionID) }
    }

    func reconcileWeightEntries() async {
        guard HealthAuthorizationManager.canWriteBodyMass else { return }
        guard !isReconcilingWeightEntries else { return }

        isReconcilingWeightEntries = true
        defer { isReconcilingWeightEntries = false }

        let context = makeBackgroundContext()
        let weightEntryIDs = ((try? context.fetch(WeightEntry.entriesNeedingHealthExport)) ?? []).map(\.id)

        for weightEntryID in weightEntryIDs { await exportIfEligible(weightEntryID: weightEntryID) }
    }

    private func makeBackgroundContext() -> ModelContext {
        let context = ModelContext(SharedModelContainer.container)
        context.autosaveEnabled = false
        return context
    }
}

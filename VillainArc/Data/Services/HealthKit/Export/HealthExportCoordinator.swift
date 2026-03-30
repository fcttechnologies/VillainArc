import Foundation
import HealthKit
import SwiftData

actor HealthExportCoordinator {
    static let shared = HealthExportCoordinator()
    private let bodyMassType = HKQuantityType(.bodyMass)
    private let weightUnit = HKUnit.gramUnit(with: .kilo)
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
        await exportLoadedSession(session, context: context)
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

    private func exportLoadedSession(_ session: WorkoutSession, context: ModelContext) async {
        guard session.statusValue == .done else { return }
        guard !session.isHidden else { return }
        guard !session.hasBeenExportedToHealth else { return }

        if let existingWorkout = try? await HealthMirrorQueries.findSavedWorkout(for: session.id) {
            do {
                try HealthWorkoutLinker.upsertHealthWorkout(for: existingWorkout, linkedTo: session, context: context)
                try context.save()
                print("Linked existing Apple Health workout \(existingWorkout.uuid) to local session \(session.id)")
            } catch { print("Failed to link existing Apple Health workout for \(session.id): \(error)") }
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
                print("HealthKit finished export for \(session.id), but the workout sample was unavailable.")
                return
            }

            if let workoutEffortSample, HealthAuthorizationManager.canWriteWorkoutEffortScore {
                do {
                    _ = try await HealthAuthorizationManager.healthStore.relateWorkoutEffortSample(workoutEffortSample, with: workout, activity: nil)
                } catch {
                    print("Failed to relate workout effort score for \(session.id): \(error)")
                }
            }

            try HealthWorkoutLinker.upsertHealthWorkout(for: workout, linkedTo: session, context: context)
            try context.save()
            print("Saved workout session \(session.id) to Apple Health as \(workout.uuid)")
        } catch { print("Failed to export workout \(session.id) to HealthKit: \(error)") }
    }

    private func exportLoadedWeightEntry(_ weightEntry: WeightEntry, context: ModelContext) async {
        guard !weightEntry.hasBeenExportedToHealth else { return }

        if let existingSample = try? await HealthMirrorQueries.findSavedWeightSample(for: weightEntry.id) {
            do {
                try HealthWeightEntryLinker.upsertWeightEntry(for: existingSample, context: context)
                try context.save()
                print("Linked existing Apple Health body mass sample \(existingSample.uuid) to local weight entry \(weightEntry.id)")
            } catch { print("Failed to link existing Apple Health body mass sample for \(weightEntry.id): \(error)") }
            return
        }

        let sampleDate = weightEntry.date
        let quantity = HKQuantity(unit: weightUnit, doubleValue: weightEntry.weight)
        let sample = HKQuantitySample(type: bodyMassType, quantity: quantity, start: sampleDate, end: sampleDate, metadata: HealthAuthorizationManager.metadata(for: weightEntry))

        do {
            try await HealthAuthorizationManager.healthStore.save(sample)
            try HealthWeightEntryLinker.upsertWeightEntry(for: sample, context: context)
            try context.save()
            print("Saved weight entry \(weightEntry.id) to Apple Health as \(sample.uuid)")
        } catch { print("Failed to export weight entry \(weightEntry.id) to HealthKit: \(error)") }
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
        print("Reconciling \(sessionIDs.count) completed workouts for Apple Health export")

        for sessionID in sessionIDs { await exportIfEligible(sessionID: sessionID) }

        print("Finished Apple Health export reconciliation")
    }

    func reconcileWeightEntries() async {
        guard HealthAuthorizationManager.canWriteBodyMass else { return }
        guard !isReconcilingWeightEntries else { return }

        isReconcilingWeightEntries = true
        defer { isReconcilingWeightEntries = false }

        let context = makeBackgroundContext()
        let weightEntryIDs = ((try? context.fetch(WeightEntry.entriesNeedingHealthExport)) ?? []).map(\.id)
        print("Reconciling \(weightEntryIDs.count) weight entries for Apple Health export")

        for weightEntryID in weightEntryIDs { await exportIfEligible(weightEntryID: weightEntryID) }

        print("Finished Apple Health weight export reconciliation")
    }

    private func makeBackgroundContext() -> ModelContext {
        let context = ModelContext(SharedModelContainer.container)
        context.autosaveEnabled = false
        return context
    }
}

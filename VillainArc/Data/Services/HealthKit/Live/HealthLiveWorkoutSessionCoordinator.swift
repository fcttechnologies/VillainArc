import Foundation
import HealthKit
import Observation
import SwiftData

@Observable final class HealthLiveWorkoutSessionCoordinator: NSObject {
    static let shared = HealthLiveWorkoutSessionCoordinator()

    private(set) var activeWorkoutSessionID: UUID?
    private(set) var latestHeartRate: Double?
    private(set) var activeEnergyBurned: Double?
    private(set) var restingEnergyBurned: Double?

    @ObservationIgnored private var liveWorkoutSession: HKWorkoutSession?
    @ObservationIgnored private var liveWorkoutBuilder: HKLiveWorkoutBuilder?
    @ObservationIgnored private var stoppedStateContinuation: CheckedContinuation<Void, Never>?
    @ObservationIgnored private var isFinishingWorkout = false

    private override init() {
        super.init()
    }

    var totalEnergyBurned: Double? {
        guard let activeEnergyBurned, let restingEnergyBurned else { return nil }
        return activeEnergyBurned + restingEnergyBurned
    }

    var isRunningLiveWorkoutCollection: Bool {
        guard activeWorkoutSessionID != nil else { return false }
        guard liveWorkoutSession != nil, liveWorkoutBuilder != nil else { return false }
        return !isFinishingWorkout
    }

    func ensureRunning(for workout: WorkoutSession) async {
        guard workout.statusValue == .active else { return }
        guard HealthAuthorizationManager.canWriteWorkouts else { return }

        if activeWorkoutSessionID == workout.id, liveWorkoutSession != nil, liveWorkoutBuilder != nil { return }

        guard liveWorkoutSession == nil, liveWorkoutBuilder == nil else { return }

        let configuration = makeWorkoutConfiguration()

        if await recoverIfPossible(for: workout, configuration: configuration) { return }

        do {
            let session = try HKWorkoutSession(healthStore: HealthAuthorizationManager.healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()

            attachLiveObjects(session: session, builder: builder, workout: workout, configuration: configuration)

            session.startActivity(with: workout.startedAt)
            try await builder.beginCollection(at: workout.startedAt)
            try await builder.addMetadata(HealthAuthorizationManager.metadata(for: workout))
        } catch {
            clearLiveWorkoutState()
            print("Failed to start live Health workout session for \(workout.id): \(error)")
        }
    }

    func finishIfRunning(for workout: WorkoutSession, context: ModelContext) async {
        if workout.healthWorkout == nil, let savedWorkout = try? await HealthMirrorQueries.findSavedWorkout(for: workout.id) {
            await HealthWorkoutMirrorImporter.shared.importWorkout(savedWorkout, linkedSessionID: workout.id)
            refreshLinkedHealthWorkout(for: workout, healthWorkoutUUID: savedWorkout.uuid, context: context)
            print("Linked existing Apple Health workout \(savedWorkout.uuid) to live session \(workout.id)")
            return
        }

        guard activeWorkoutSessionID == workout.id, let liveWorkoutSession, let liveWorkoutBuilder else { return }

        guard !isFinishingWorkout else { return }
        isFinishingWorkout = true

        let endDate = max(workout.startedAt, workout.endedAt ?? .now)
        let workoutEffortSample = HealthWorkoutEffortSampleBuilder.makeSample(for: workout, endDate: endDate)

        liveWorkoutSession.stopActivity(with: endDate)
        await waitForSessionToStop(liveWorkoutSession)

        do {
            try await liveWorkoutBuilder.addMetadata(HealthAuthorizationManager.metadata(for: workout))
            try await liveWorkoutBuilder.endCollection(at: endDate)

            let savedWorkout = try await liveWorkoutBuilder.finishWorkout()

            if let savedWorkout {
                if let workoutEffortSample, HealthAuthorizationManager.canWriteWorkoutEffortScore {
                    do {
                        _ = try await HealthAuthorizationManager.healthStore.relateWorkoutEffortSample(workoutEffortSample, with: savedWorkout, activity: nil as HKWorkoutActivity?)
                    } catch {
                        print("Failed to relate workout effort score for \(workout.id): \(error)")
                    }
                }

                await HealthWorkoutMirrorImporter.shared.importWorkout(savedWorkout, linkedSessionID: workout.id)
                refreshLinkedHealthWorkout(for: workout, healthWorkoutUUID: savedWorkout.uuid, context: context)
                print("Saved live workout session \(workout.id) to Apple Health as \(savedWorkout.uuid)")
            } else {
                print("HealthKit finished live workout for \(workout.id), but the workout sample was unavailable.")
            }
        } catch {
            print("Failed to finish live Health workout session for \(workout.id): \(error)")
        }

        liveWorkoutSession.end()
        isFinishingWorkout = false
        clearLiveWorkoutState()
    }

    func discardIfRunning(for workout: WorkoutSession) {
        guard activeWorkoutSessionID == workout.id else { return }
        liveWorkoutBuilder?.discardWorkout()
        liveWorkoutSession?.end()
        isFinishingWorkout = false
        clearLiveWorkoutState()
    }

    private func makeWorkoutConfiguration() -> HKWorkoutConfiguration {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor
        return configuration
    }

    private func recoverIfPossible(for workout: WorkoutSession, configuration: HKWorkoutConfiguration) async -> Bool {
        guard let recoveredSession = try? await HealthAuthorizationManager.healthStore.recoverActiveWorkoutSession() else { return false }

        let recoveredBuilder = recoveredSession.associatedWorkoutBuilder()
        let recoveredSessionID = recoveredBuilder.metadata[HealthMetadataKeys.workoutSessionID] as? String

        if let recoveredSessionID, recoveredSessionID != workout.id.uuidString {
            print("Recovered Health workout session metadata mismatch. Expected \(workout.id.uuidString), got \(recoveredSessionID).")
            return false
        }

        attachLiveObjects(session: recoveredSession, builder: recoveredBuilder, workout: workout, configuration: configuration)
        updateLiveStatistics(from: recoveredBuilder, collectedTypes: Set<HKSampleType>([HealthKitCatalog.heartRateType, HealthKitCatalog.activeEnergyBurnedType, HealthKitCatalog.restingEnergyBurnedType]))
        return true
    }

    private func attachLiveObjects(session: HKWorkoutSession, builder: HKLiveWorkoutBuilder, workout: WorkoutSession, configuration: HKWorkoutConfiguration) {
        session.delegate = self
        builder.delegate = self
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: HealthAuthorizationManager.healthStore, workoutConfiguration: configuration)

        activeWorkoutSessionID = workout.id
        latestHeartRate = nil
        activeEnergyBurned = nil
        restingEnergyBurned = nil
        liveWorkoutSession = session
        liveWorkoutBuilder = builder
    }

    private func waitForSessionToStop(_ session: HKWorkoutSession) async {
        if session.state == .stopped || session.state == .ended { return }

        await withCheckedContinuation { continuation in stoppedStateContinuation = continuation }
    }

    private func updateLiveStatistics(from workoutBuilder: HKLiveWorkoutBuilder, collectedTypes: Set<HKSampleType>) {
        let heartRateType = HealthKitCatalog.heartRateType
        let activeEnergyType = HealthKitCatalog.activeEnergyBurnedType
        let restingEnergyType = HealthKitCatalog.restingEnergyBurnedType
        var didChangeDisplayedMetrics = false

        if collectedTypes.contains(heartRateType) {
            let latestCollectedHeartRate = workoutBuilder.statistics(for: heartRateType)?.mostRecentQuantity()?.doubleValue(for: HealthKitCatalog.bpmUnit)
            if displayedMetricChanged(from: latestHeartRate, to: latestCollectedHeartRate) {
                latestHeartRate = latestCollectedHeartRate
                didChangeDisplayedMetrics = true
            }
        }

        if collectedTypes.contains(activeEnergyType) {
            let collectedActiveEnergyBurned = workoutBuilder.statistics(for: activeEnergyType)?.sumQuantity()?.doubleValue(for: HealthKitCatalog.kilocalorieUnit)
            if displayedMetricChanged(from: activeEnergyBurned, to: collectedActiveEnergyBurned) {
                activeEnergyBurned = collectedActiveEnergyBurned
                didChangeDisplayedMetrics = true
            }
        }

        if collectedTypes.contains(restingEnergyType) {
            let collectedRestingEnergyBurned = workoutBuilder.statistics(for: restingEnergyType)?.sumQuantity()?.doubleValue(for: HealthKitCatalog.kilocalorieUnit)
            if displayedMetricChanged(from: restingEnergyBurned, to: collectedRestingEnergyBurned) {
                restingEnergyBurned = collectedRestingEnergyBurned
            }
        }

        if didChangeDisplayedMetrics, activeWorkoutSessionID != nil {
            WorkoutActivityManager.updateLiveMetrics()
        }
    }

    private func clearLiveWorkoutState() {
        stoppedStateContinuation?.resume()
        stoppedStateContinuation = nil
        liveWorkoutSession = nil
        liveWorkoutBuilder = nil
        activeWorkoutSessionID = nil
        latestHeartRate = nil
        activeEnergyBurned = nil
        restingEnergyBurned = nil
    }

    private func displayedMetricChanged(from previousValue: Double?, to nextValue: Double?) -> Bool {
        roundedDisplayMetric(previousValue) != roundedDisplayMetric(nextValue)
    }

    private func roundedDisplayMetric(_ value: Double?) -> Int? {
        guard let value else { return nil }
        return Int(value.rounded())
    }

    private func refreshLinkedHealthWorkout(for workout: WorkoutSession, healthWorkoutUUID: UUID, context: ModelContext) {
        guard let mirroredWorkout = try? context.fetch(HealthWorkout.byHealthWorkoutUUID(healthWorkoutUUID)).first else { return }
        if workout.healthWorkout?.healthWorkoutUUID != mirroredWorkout.healthWorkoutUUID {
            workout.healthWorkout = mirroredWorkout
        }
        workout.hasBeenExportedToHealth = true
        saveContext(context: context)
    }
}

extension HealthLiveWorkoutSessionCoordinator: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        Task { @MainActor in
            if toState == .stopped || toState == .ended {
                stoppedStateContinuation?.resume()
                stoppedStateContinuation = nil
            }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: any Error) {
        Task { @MainActor in
            isFinishingWorkout = false
            stoppedStateContinuation?.resume()
            stoppedStateContinuation = nil
            clearLiveWorkoutState()
            if let endDate = RestTimerState.shared.endDate, RestTimerState.shared.isRunning {
                Task {
                    await NotificationCoordinator.scheduleRestTimer(endDate: endDate)
                }
            }
            print("Live Health workout session failed: \(error)")
        }
    }
}

extension HealthLiveWorkoutSessionCoordinator: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        Task { @MainActor in
            updateLiveStatistics(from: workoutBuilder, collectedTypes: collectedTypes)
        }
    }
}

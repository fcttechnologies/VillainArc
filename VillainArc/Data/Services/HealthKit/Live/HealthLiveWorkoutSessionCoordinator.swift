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
    private(set) var currentSessionState: HKWorkoutSessionState?
    private(set) var lastErrorMessage: String?

    private var liveWorkoutSession: HKWorkoutSession?
    private var liveWorkoutBuilder: HKLiveWorkoutBuilder?
    private var stoppedStateContinuation: CheckedContinuation<Void, Never>?
    private var isFinishingWorkout = false

    private override init() {
        super.init()
    }

    var totalEnergyBurned: Double? {
        guard let activeEnergyBurned, let restingEnergyBurned else { return nil }
        return activeEnergyBurned + restingEnergyBurned
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
            lastErrorMessage = "Unable to start Apple Health workout collection."
            clearLiveWorkoutState()
            print("Failed to start live Health workout session for \(workout.id): \(error)")
        }
    }

    func finishIfRunning(for workout: WorkoutSession, context: ModelContext) async {
        if workout.healthWorkout == nil, let savedWorkout = try? await HealthMirrorQueries.findSavedWorkout(for: workout.id) {
            do {
                try HealthWorkoutLinker.upsertHealthWorkout(for: savedWorkout, linkedTo: workout, context: context)
                saveContext(context: context)
            } catch { print("Failed to relink saved Health workout for \(workout.id): \(error)") }
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

                try HealthWorkoutLinker.upsertHealthWorkout(for: savedWorkout, linkedTo: workout, context: context)
                saveContext(context: context)
            } else {
                print("HealthKit finished live workout for \(workout.id), but the workout sample was unavailable.")
            }
        } catch {
            lastErrorMessage = "Unable to finish Apple Health workout collection."
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
            lastErrorMessage = "Recovered Apple Health workout did not match the active workout."
            print("Recovered Health workout session metadata mismatch. Expected \(workout.id.uuidString), got \(recoveredSessionID).")
            return false
        }

        attachLiveObjects(session: recoveredSession, builder: recoveredBuilder, workout: workout, configuration: configuration)
        updateLiveStatistics(from: recoveredBuilder, collectedTypes: Set<HKSampleType>([HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned), HKQuantityType(.basalEnergyBurned)]))
        return true
    }

    private func attachLiveObjects(session: HKWorkoutSession, builder: HKLiveWorkoutBuilder, workout: WorkoutSession, configuration: HKWorkoutConfiguration) {
        session.delegate = self
        builder.delegate = self
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: HealthAuthorizationManager.healthStore, workoutConfiguration: configuration)

        activeWorkoutSessionID = workout.id
        currentSessionState = session.state
        latestHeartRate = nil
        activeEnergyBurned = nil
        restingEnergyBurned = nil
        lastErrorMessage = nil
        liveWorkoutSession = session
        liveWorkoutBuilder = builder
    }

    private func waitForSessionToStop(_ session: HKWorkoutSession) async {
        if session.state == .stopped || session.state == .ended { return }

        await withCheckedContinuation { continuation in stoppedStateContinuation = continuation }
    }

    private func updateLiveStatistics(from workoutBuilder: HKLiveWorkoutBuilder, collectedTypes: Set<HKSampleType>) {
        let heartRateType = HKQuantityType(.heartRate)
        let activeEnergyType = HKQuantityType(.activeEnergyBurned)
        let restingEnergyType = HKQuantityType(.basalEnergyBurned)
        let previousHeartRate = latestHeartRate
        let previousActiveEnergyBurned = activeEnergyBurned
        var didChangeDisplayedMetrics = false

        if collectedTypes.contains(heartRateType) {
            let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
            let latestCollectedHeartRate = workoutBuilder.statistics(for: heartRateType)?.mostRecentQuantity()?.doubleValue(for: heartRateUnit)
            didChangeDisplayedMetrics = didChangeDisplayedMetrics || displayedMetricChanged(from: previousHeartRate, to: latestCollectedHeartRate)
            latestHeartRate = latestCollectedHeartRate
        }

        if collectedTypes.contains(activeEnergyType) {
            let collectedActiveEnergyBurned = workoutBuilder.statistics(for: activeEnergyType)?.sumQuantity()?.doubleValue(for: .kilocalorie())
            didChangeDisplayedMetrics = didChangeDisplayedMetrics || displayedMetricChanged(from: previousActiveEnergyBurned, to: collectedActiveEnergyBurned)
            activeEnergyBurned = collectedActiveEnergyBurned
        }

        if collectedTypes.contains(restingEnergyType) { restingEnergyBurned = workoutBuilder.statistics(for: restingEnergyType)?.sumQuantity()?.doubleValue(for: .kilocalorie()) }

        if didChangeDisplayedMetrics, activeWorkoutSessionID != nil { WorkoutActivityManager.update() }
    }

    private func clearLiveWorkoutState() {
        stoppedStateContinuation?.resume()
        stoppedStateContinuation = nil
        liveWorkoutSession = nil
        liveWorkoutBuilder = nil
        activeWorkoutSessionID = nil
        currentSessionState = nil
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
}

extension HealthLiveWorkoutSessionCoordinator: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        Task { @MainActor in
            currentSessionState = toState

            if toState == .stopped || toState == .ended {
                stoppedStateContinuation?.resume()
                stoppedStateContinuation = nil
            }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: any Error) {
        Task { @MainActor in
            lastErrorMessage = "Apple Health workout session failed."
            isFinishingWorkout = false
            stoppedStateContinuation?.resume()
            stoppedStateContinuation = nil
            clearLiveWorkoutState()
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

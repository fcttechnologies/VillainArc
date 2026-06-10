import Foundation
import HealthKit
import Observation
import SwiftData

@Observable final class CardioHealthWorkoutCoordinator: NSObject {
    static let shared = CardioHealthWorkoutCoordinator()

    private(set) var activeCardioSessionID: UUID?
    private(set) var latestHeartRate: Double?
    private(set) var activeEnergyBurned: Double?
    private(set) var distanceMeters: Double?

    @ObservationIgnored private var liveWorkoutSession: HKWorkoutSession?
    @ObservationIgnored private var liveWorkoutBuilder: HKLiveWorkoutBuilder?
    @ObservationIgnored private var stoppedStateContinuation: CheckedContinuation<Void, Never>?
    @ObservationIgnored private var isFinishingWorkout = false

    private override init() {
        super.init()
    }

    var isRunningLiveWorkoutCollection: Bool {
        guard activeCardioSessionID != nil else { return false }
        guard liveWorkoutSession != nil, liveWorkoutBuilder != nil else { return false }
        return !isFinishingWorkout
    }

    func prepareForSession(_ session: CardioSession) async {
        guard session.statusValue == .active else { return }
        guard HealthAuthorizationManager.canWriteWorkouts else { return }
        guard activeCardioSessionID == nil, liveWorkoutSession == nil, liveWorkoutBuilder == nil else { return }

        let configuration = makeWorkoutConfiguration(for: session)

        do {
            let workoutSession = try HKWorkoutSession(healthStore: HealthAuthorizationManager.healthStore, configuration: configuration)
            let builder = workoutSession.associatedWorkoutBuilder()
            attachLiveObjects(session: workoutSession, builder: builder, cardioSession: session, configuration: configuration)
            workoutSession.prepare()
        } catch {
            clearLiveWorkoutState()
            AppLog.error("Failed to prepare cardio Health session for \(session.id)", error: error)
        }
    }

    func beginActiveCollection(for session: CardioSession) async {
        guard session.statusValue == .active else { return }
        guard HealthAuthorizationManager.canWriteWorkouts else { return }

        if let liveWorkoutSession, let liveWorkoutBuilder, activeCardioSessionID == session.id,
           liveWorkoutSession.state == .prepared || liveWorkoutSession.state == .notStarted {
            do {
                let startDate = session.startedAt ?? .now
                liveWorkoutSession.startActivity(with: startDate)
                try await liveWorkoutBuilder.beginCollection(at: startDate)
                try await liveWorkoutBuilder.addMetadata(HealthAuthorizationManager.metadata(for: session))
            } catch {
                AppLog.error("Failed to begin cardio Health workout collection for \(session.id)", error: error)
            }
            return
        }

        await ensureRunning(for: session)
    }

    func ensureRunning(for session: CardioSession) async {
        guard session.statusValue == .active else { return }
        guard HealthAuthorizationManager.canWriteWorkouts else { return }

        if activeCardioSessionID == session.id, liveWorkoutSession != nil, liveWorkoutBuilder != nil { return }
        guard liveWorkoutSession == nil, liveWorkoutBuilder == nil else { return }

        let configuration = makeWorkoutConfiguration(for: session)

        if await recoverIfPossible(for: session, configuration: configuration) { return }

        do {
            let workoutSession = try HKWorkoutSession(healthStore: HealthAuthorizationManager.healthStore, configuration: configuration)
            let builder = workoutSession.associatedWorkoutBuilder()

            attachLiveObjects(session: workoutSession, builder: builder, cardioSession: session, configuration: configuration)

            let startDate = session.startedAt ?? .now
            workoutSession.startActivity(with: startDate)
            try await builder.beginCollection(at: startDate)
            try await builder.addMetadata(HealthAuthorizationManager.metadata(for: session))
        } catch {
            clearLiveWorkoutState()
            AppLog.error("Failed to start live cardio Health workout for \(session.id)", error: error)
        }
    }

    func finishIfRunning(for session: CardioSession, context: ModelContext) async {
        // Dedup guard (mirrors the strength flow): if a Health workout was already
        // saved for this cardio session — e.g. an orphaned session that survived an
        // app relaunch and resolved on its own — link it instead of saving a second
        // one. This is what prevents the "two workouts in Health" double-save.
        if session.healthWorkout == nil, let savedWorkout = try? await HealthMirrorQueries.findSavedCardioWorkout(for: session.id) {
            await HealthWorkoutMirrorImporter.shared.importWorkout(savedWorkout, linkedCardioSessionID: session.id)
            if activeCardioSessionID == session.id {
                liveWorkoutBuilder?.discardWorkout()
                liveWorkoutSession?.end()
                isFinishingWorkout = false
                clearLiveWorkoutState()
            }
            AppLog.info("Linked existing Apple Health cardio workout \(savedWorkout.uuid) to session \(session.id) instead of re-saving.")
            return
        }

        guard activeCardioSessionID == session.id, let liveWorkoutSession, let liveWorkoutBuilder else { return }
        guard !isFinishingWorkout else { return }
        isFinishingWorkout = true

        let endDate = max(session.startedAt ?? .now, session.endedAt ?? .now)
        let effortSample = HealthWorkoutEffortSampleBuilder.makeSample(for: session, endDate: endDate)
        liveWorkoutSession.stopActivity(with: endDate)
        await waitForSessionToStop(liveWorkoutSession)

        do {
            if let distanceSample = distanceSample(for: session, endDate: endDate),
               HealthAuthorizationManager.canWriteWalkingRunningDistance {
                try await addSamples([distanceSample], to: liveWorkoutBuilder)
            }

            try await liveWorkoutBuilder.addMetadata(HealthAuthorizationManager.metadata(for: session))
            try await liveWorkoutBuilder.endCollection(at: endDate)

            guard let savedWorkout = try await liveWorkoutBuilder.finishWorkout() else {
                AppLog.error("HealthKit finished cardio export for \(session.id), but the workout sample was unavailable.")
                return
            }

            if let effortSample, HealthAuthorizationManager.canWriteWorkoutEffortScore {
                do {
                    _ = try await HealthAuthorizationManager.healthStore.relateWorkoutEffortSample(effortSample, with: savedWorkout, activity: nil as HKWorkoutActivity?)
                } catch {
                    AppLog.error("Failed to relate cardio effort score for \(session.id)", error: error)
                }
            }

            apply(savedWorkout: savedWorkout, to: session, context: context)
            await HealthWorkoutMirrorImporter.shared.importWorkout(savedWorkout, linkedCardioSessionID: session.id)
            AppLog.info("Saved cardio session \(session.id) to Apple Health as \(savedWorkout.uuid).")
        } catch {
            AppLog.error("Failed to finish live cardio Health workout \(session.id)", error: error)
        }

        liveWorkoutSession.end()
        isFinishingWorkout = false
        clearLiveWorkoutState()
    }

    func discardIfRunning(for session: CardioSession) {
        guard activeCardioSessionID == session.id else { return }
        liveWorkoutBuilder?.discardWorkout()
        liveWorkoutSession?.end()
        isFinishingWorkout = false
        clearLiveWorkoutState()
    }

    private func makeWorkoutConfiguration(for session: CardioSession) -> HKWorkoutConfiguration {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = session.healthActivityType
        configuration.locationType = session.healthLocationType
        return configuration
    }

    private func recoverIfPossible(for session: CardioSession, configuration: HKWorkoutConfiguration) async -> Bool {
        guard let recoveredSession = try? await HealthAuthorizationManager.healthStore.recoverActiveWorkoutSession() else { return false }

        let recoveredBuilder = recoveredSession.associatedWorkoutBuilder()
        let recoveredSessionID = recoveredBuilder.metadata[HealthMetadataKeys.cardioSessionID] as? String

        if let recoveredSessionID, recoveredSessionID != session.id.uuidString {
            // A stale active session from a different cardio session (only one cardio
            // flow runs at a time, so this is an orphan). End it instead of leaving it
            // active — an orphaned live session is what later double-saves to Health.
            AppLog.info("Recovered cardio Health workout metadata mismatch. Expected \(session.id.uuidString), got \(recoveredSessionID). Ending the stale session.")
            recoveredSession.end()
            return false
        }

        attachLiveObjects(session: recoveredSession, builder: recoveredBuilder, cardioSession: session, configuration: configuration)
        updateLiveStatistics(from: recoveredBuilder, collectedTypes: Set<HKSampleType>([HealthKitCatalog.heartRateType, HealthKitCatalog.activeEnergyBurnedType, HealthKitCatalog.walkingRunningDistanceType]))
        return true
    }

    private func attachLiveObjects(session: HKWorkoutSession, builder: HKLiveWorkoutBuilder, cardioSession: CardioSession, configuration: HKWorkoutConfiguration) {
        session.delegate = self
        builder.delegate = self
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: HealthAuthorizationManager.healthStore, workoutConfiguration: configuration)

        activeCardioSessionID = cardioSession.id
        latestHeartRate = nil
        activeEnergyBurned = nil
        distanceMeters = nil
        liveWorkoutSession = session
        liveWorkoutBuilder = builder
    }

    private func waitForSessionToStop(_ session: HKWorkoutSession) async {
        if session.state == .stopped || session.state == .ended { return }
        await withCheckedContinuation { continuation in stoppedStateContinuation = continuation }
    }

    private func updateLiveStatistics(from workoutBuilder: HKLiveWorkoutBuilder, collectedTypes: Set<HKSampleType>) {
        var didChangeDisplayedMetrics = false

        if collectedTypes.contains(HealthKitCatalog.heartRateType) {
            let latestCollectedHeartRate = workoutBuilder.statistics(for: HealthKitCatalog.heartRateType)?.mostRecentQuantity()?.doubleValue(for: HealthKitCatalog.bpmUnit)
            if roundedDisplayMetric(latestHeartRate) != roundedDisplayMetric(latestCollectedHeartRate) {
                latestHeartRate = latestCollectedHeartRate
                didChangeDisplayedMetrics = true
            }
        }

        if collectedTypes.contains(HealthKitCatalog.activeEnergyBurnedType) {
            let collectedActiveEnergy = workoutBuilder.statistics(for: HealthKitCatalog.activeEnergyBurnedType)?.sumQuantity()?.doubleValue(for: HealthKitCatalog.kilocalorieUnit)
            if roundedDisplayMetric(activeEnergyBurned) != roundedDisplayMetric(collectedActiveEnergy) {
                activeEnergyBurned = collectedActiveEnergy
                didChangeDisplayedMetrics = true
            }
        }

        if collectedTypes.contains(HealthKitCatalog.walkingRunningDistanceType) {
            let collectedDistance = workoutBuilder.statistics(for: HealthKitCatalog.walkingRunningDistanceType)?.sumQuantity()?.doubleValue(for: HealthKitCatalog.meterUnit)
            if roundedDisplayMetric(distanceMeters) != roundedDisplayMetric(collectedDistance) {
                distanceMeters = collectedDistance
                didChangeDisplayedMetrics = true
            }
        }

        if didChangeDisplayedMetrics, let activeCardioSessionID {
            let context = SharedModelContainer.container.mainContext
            if let session = try? context.fetch(CardioSession.byID(activeCardioSessionID)).first {
                if let distanceMeters, distanceMeters > session.totalDistanceMeters {
                    session.totalDistanceMeters = distanceMeters
                    session.source = .appleHealth
                }
                saveContext(context: context)
                CardioActivityManager.update(for: session)
            } else {
                CardioActivityManager.update()
            }
        }
    }

    private func distanceSample(for session: CardioSession, endDate: Date) -> HKQuantitySample? {
        guard session.totalDistanceMeters > 0 else { return nil }
        let quantity = HKQuantity(unit: HealthKitCatalog.meterUnit, doubleValue: session.totalDistanceMeters)
        return HKQuantitySample(type: HealthKitCatalog.walkingRunningDistanceType, quantity: quantity, start: session.startedAt ?? endDate, end: endDate, metadata: HealthAuthorizationManager.metadata(for: session))
    }

    private func addSamples(_ samples: [HKSample], to workoutBuilder: HKLiveWorkoutBuilder) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            workoutBuilder.add(samples) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: CocoaError(.featureUnsupported))
                }
            }
        }
    }

    private func apply(savedWorkout: HKWorkout, to session: CardioSession, context: ModelContext) {
        session.healthWorkoutUUID = savedWorkout.uuid
        session.source = .appleHealth
        if let workoutDistance = savedWorkout.totalDistance?.doubleValue(for: HealthKitCatalog.meterUnit), workoutDistance > 0 {
            session.totalDistanceMeters = max(session.totalDistanceMeters, workoutDistance)
        }
        saveContext(context: context)
    }

    private func clearLiveWorkoutState() {
        stoppedStateContinuation?.resume()
        stoppedStateContinuation = nil
        liveWorkoutSession = nil
        liveWorkoutBuilder = nil
        activeCardioSessionID = nil
        latestHeartRate = nil
        activeEnergyBurned = nil
        distanceMeters = nil
    }

    private func roundedDisplayMetric(_ value: Double?) -> Int? {
        guard let value else { return nil }
        return Int(value.rounded())
    }
}

extension CardioHealthWorkoutCoordinator: HKWorkoutSessionDelegate {
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
            AppLog.error("Live cardio Health workout failed", error: error)
        }
    }
}

extension CardioHealthWorkoutCoordinator: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        Task { @MainActor in
            updateLiveStatistics(from: workoutBuilder, collectedTypes: collectedTypes)
        }
    }
}

import Foundation
import HealthKit
import SwiftData

@MainActor
final class HealthExportCoordinator {
    static let shared = HealthExportCoordinator()

    private let authorizationManager = HealthAuthorizationManager.shared
    private var inFlightSessionIDs: Set<UUID> = []
    private var isReconciling = false

    private init() {}

    func exportIfEligible(session: WorkoutSession) async {
        guard authorizationManager.currentAuthorizationState.isAuthorized else { return }
        guard !inFlightSessionIDs.contains(session.id) else { return }

        inFlightSessionIDs.insert(session.id)
        defer { inFlightSessionIDs.remove(session.id) }

        await exportLoadedSession(session)
    }

    func exportIfEligible(sessionID: UUID) async {
        guard authorizationManager.currentAuthorizationState.isAuthorized else { return }
        guard !inFlightSessionIDs.contains(sessionID) else { return }

        inFlightSessionIDs.insert(sessionID)
        defer { inFlightSessionIDs.remove(sessionID) }

        let context = SharedModelContainer.container.mainContext

        guard let session = try? context.fetch(WorkoutSession.byID(sessionID)).first else { return }
        await exportLoadedSession(session)
    }

    private func exportLoadedSession(_ session: WorkoutSession) async {
        guard session.statusValue == .done else { return }
        guard !session.isHidden else { return }
        guard session.healthWorkout == nil else { return }

        let context = SharedModelContainer.container.mainContext
        let endDate = max(session.startedAt, session.endedAt ?? session.startedAt)
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        let workoutBuilder = HKWorkoutBuilder(healthStore: authorizationManager.healthStore, configuration: configuration, device: nil)

        do {
            try await workoutBuilder.beginCollection(at: session.startedAt)
            try await workoutBuilder.addMetadata(authorizationManager.metadata(for: session))
            try await workoutBuilder.endCollection(at: endDate)

            guard let workout = try await workoutBuilder.finishWorkout() else {
                print("HealthKit finished export for \(session.id), but the workout sample was unavailable.")
                return
            }

            let healthWorkout = HealthWorkout(healthWorkoutUUID: workout.uuid, workoutSession: session)
            context.insert(healthWorkout)
            saveContext(context: context)
        } catch {
            print("Failed to export workout \(session.id) to HealthKit: \(error)")
        }
    }

    func reconcileCompletedSessions() async {
        guard authorizationManager.currentAuthorizationState.isAuthorized else { return }
        guard !isReconciling else { return }

        isReconciling = true
        defer { isReconciling = false }

        let context = SharedModelContainer.container.mainContext
        let sessions = (try? context.fetch(WorkoutSession.completedSessionsNeedingHealthExport)) ?? []

        for session in sessions {
            await exportIfEligible(session: session)
        }
    }
}

import HealthKit
import Testing

@testable import VillainArc

struct CardioDetailRoutingTests {
    @Test @MainActor
    func outdoorRouteSessionKeepsCardioDetailDestination() {
        let session = CardioSession(activity: .run, environment: .outdoor, captureMode: .gpsRoute)

        guard case .cardioSessionDetail(let routedSession) = AppRouter.detailDestination(for: session) else {
            Issue.record("Expected outdoor route sessions to keep the cardio detail destination.")
            return
        }

        #expect(routedSession.id == session.id)
    }

    @Test @MainActor
    func indoorSessionWithHealthMirrorUsesHealthDetailDestination() {
        let session = CardioSession(activity: .walk, environment: .indoor, captureMode: .machineIntervals)
        let workout = HealthWorkout(workout: HKWorkout(activityType: .walking, start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSince1970: 1800)), cardioSession: session)
        session.healthWorkout = workout

        guard case .healthWorkoutDetail(let routedWorkout) = AppRouter.detailDestination(for: session) else {
            Issue.record("Expected indoor mirrored cardio sessions to open the Health workout detail.")
            return
        }

        #expect(routedWorkout.healthWorkoutUUID == workout.healthWorkoutUUID)
    }

    @Test @MainActor
    func indoorSessionWithoutHealthMirrorFallsBackToCardioDetailDestination() {
        let session = CardioSession(activity: .walk, environment: .indoor, captureMode: .machineIntervals)

        guard case .cardioSessionDetail(let routedSession) = AppRouter.detailDestination(for: session) else {
            Issue.record("Expected unmirrored indoor sessions to keep the fallback cardio detail destination.")
            return
        }

        #expect(routedSession.id == session.id)
    }
}

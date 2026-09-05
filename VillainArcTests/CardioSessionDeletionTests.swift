import Foundation
import SwiftData
import Testing

@testable import VillainArc

/// The one deletion seam both the detail screens' affordance and `DeleteCardioSessionIntent` run
/// through. What it must be true about: the recorded detail goes with the session, an Apple Health
/// workout mirrored from it does not, and an incomplete session is refused outright.
@MainActor
struct CardioSessionDeletionTests {
    private func completedSession(in context: ModelContext) -> CardioSession {
        let session = CardioSession(activity: .run, environment: .outdoor, captureMode: .gpsRoute)
        session.status = CardioSessionStatus.done.rawValue
        session.startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        session.endedAt = Date(timeIntervalSince1970: 1_700_003_600)
        context.insert(session)
        return session
    }

    @Test func deletingCompletedSessionRemovesItsRecordedRoute() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)
        let session = completedSession(in: context)
        let point = CardioRoutePoint(index: 0, latitude: 30.27, longitude: -97.74, timestamp: session.startedAt ?? .now)
        point.session = session
        context.insert(point)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<CardioRoutePoint>()) == 1)

        CardioDeletionCoordinator.deleteCompletedSession(session, context: context)

        #expect(try context.fetchCount(FetchDescriptor<CardioSession>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<CardioRoutePoint>()) == 0)
    }

    @Test func deletingCompletedSessionLeavesItsHealthWorkoutStanding() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)
        let session = completedSession(in: context)
        let workout = HealthWorkout(debugPlaceholder: true)
        context.insert(workout)
        workout.cardioSession = session
        session.healthWorkout = workout
        try context.save()

        CardioDeletionCoordinator.deleteCompletedSession(session, context: context)

        let survivors = try context.fetch(FetchDescriptor<HealthWorkout>())
        #expect(survivors.count == 1)
        #expect(survivors.first?.cardioSession == nil)
    }

    @Test func deletionRefusesASessionThatIsStillRunning() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)
        let session = CardioSession(activity: .run, environment: .outdoor, captureMode: .gpsRoute)
        context.insert(session)
        try context.save()
        #expect(session.statusValue == .active)

        CardioDeletionCoordinator.deleteCompletedSession(session, context: context)

        #expect(session.isDeleted == false)
        #expect(try context.fetchCount(FetchDescriptor<CardioSession>()) == 1)
    }
}

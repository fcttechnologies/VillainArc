import AppIntents
import Foundation
import SwiftData
import Testing

@testable import VillainArc

@Suite(.serialized)
@MainActor
struct CardioSessionEntityTests {

    // MARK: - Helpers

    private static let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeOutdoorRun(context: ModelContext, distanceMeters: Double = 5000, minutes: Double = 30) -> CardioSession {
        let session = CardioSession(activity: .run, environment: .outdoor, captureMode: .gpsRoute)
        context.insert(session)
        session.startedAt = Self.start
        session.totalDistanceMeters = distanceMeters
        // No route points recorded, so finish keeps the distance set above.
        session.finish(at: Self.start.addingTimeInterval(minutes * 60))
        return session
    }

    private func makeTreadmillWalk(context: ModelContext, minutes: Double = 20) -> CardioSession {
        let session = CardioSession(activity: .walk, environment: .indoor, captureMode: .machineIntervals)
        context.insert(session)
        session.startedAt = Self.start
        let first = CardioMachineInterval(index: 0, speedKPH: 6, inclinePercent: 2, addedAt: Self.start, session: session)
        let second = CardioMachineInterval(index: 1, speedKPH: 7.5, inclinePercent: 3, addedAt: Self.start.addingTimeInterval(minutes * 30), session: session)
        context.insert(first)
        context.insert(second)
        session.machineIntervals?.append(contentsOf: [first, second])
        session.finish(at: Self.start.addingTimeInterval(minutes * 60))
        return session
    }

    private func makeActiveRun(context: ModelContext) -> CardioSession {
        let session = CardioSession(activity: .run, environment: .outdoor, captureMode: .gpsRoute)
        context.insert(session)
        session.startedAt = Self.start.addingTimeInterval(3600)
        return session
    }

    // MARK: - Entity mapping

    @Test func entityMapsCompletedOutdoorRun() throws {
        let context = ModelContext(try TestModelContainer.make())
        let session = makeOutdoorRun(context: context, distanceMeters: 5000, minutes: 30)

        let entity = CardioSessionEntity(cardioSession: session)

        #expect(entity.id == session.id)
        #expect(entity.title == "Outdoor Run")
        #expect(entity.kind == "Outdoor Run")
        #expect(entity.startedAt == session.startedAt)
        #expect(entity.summary == session.spotlightSummary)
        #expect(entity.fullContent.id == session.id)
        #expect(entity.fullContent.distanceMeters == 5000)
        #expect(entity.fullContent.activity == "Run")
        #expect(entity.fullContent.environment == "Outdoor")
        #expect(entity.fullContent.endedAt == session.endedAt)
        #expect(entity.fullContent.durationSeconds == 30 * 60)
        #expect(entity.fullContent.machineIntervals.isEmpty)
        #expect(entity.fullContent.notes == nil)
    }

    @Test func entityIncludesMachineIntervalsForTreadmill() throws {
        let context = ModelContext(try TestModelContainer.make())
        let session = makeTreadmillWalk(context: context)

        let entity = CardioSessionEntity(cardioSession: session)

        #expect(entity.kind == "Treadmill Walk")
        #expect(entity.fullContent.machineIntervals.count == 2)
        #expect(entity.fullContent.machineIntervals.map(\.index) == [0, 1])
        #expect(entity.fullContent.machineIntervals.first?.speedKPH == 6)
        #expect(entity.fullContent.machineIntervals.last?.inclinePercent == 3)
    }

    @Test func entityDisplayRepresentationUsesSummarySubtitle() throws {
        let context = ModelContext(try TestModelContainer.make())
        let session = makeOutdoorRun(context: context)

        let representation = CardioSessionEntity(cardioSession: session).displayRepresentation
        #expect(String(localized: representation.title) == "Outdoor Run")
    }

    // MARK: - Spotlight summary (the entity subtitle + description seed)

    @Test func spotlightSummaryIncludesKindDistanceAndDuration() throws {
        let context = ModelContext(try TestModelContainer.make())
        let session = makeOutdoorRun(context: context, distanceMeters: 5000, minutes: 30)

        let summary = session.spotlightSummary
        #expect(summary.contains("Outdoor Run"))
        #expect(summary.contains(secondsToTimeWithHours(30 * 60)))
        #expect(summary.contains(DistanceUnit.systemDefault.display(5000)))
        #expect(summary.contains("Optional(") == false)
    }

    @Test func spotlightSummaryOmitsDistanceWhenZero() throws {
        let context = ModelContext(try TestModelContainer.make())
        let session = CardioSession(activity: .swim, environment: .indoor, captureMode: .healthKitOnly)
        context.insert(session)
        session.startedAt = Self.start
        session.finish(at: Self.start.addingTimeInterval(20 * 60))

        let summary = session.spotlightSummary
        #expect(summary.contains("Pool Swim"))
        #expect(summary == "Pool Swim · \(secondsToTimeWithHours(20 * 60))")
    }

    // MARK: - Query fetch factories (string-query behavior)

    @Test func completedMatchingFiltersByTitleAndExcludesActive() throws {
        let context = ModelContext(try TestModelContainer.make())
        let run = makeOutdoorRun(context: context)
        let walk = makeTreadmillWalk(context: context)
        let active = makeActiveRun(context: context)
        try context.save()

        let runMatches = try context.fetch(CardioSession.completedMatching("run", limit: 30))
        #expect(runMatches.contains { $0.id == run.id })
        #expect(runMatches.contains { $0.id == walk.id } == false)
        #expect(runMatches.contains { $0.id == active.id } == false)
        #expect(runMatches.allSatisfy { $0.statusValue == .done })

        let allCompleted = try context.fetch(CardioSession.completedMatching("", limit: 30))
        #expect(allCompleted.contains { $0.id == run.id })
        #expect(allCompleted.contains { $0.id == walk.id })
        #expect(allCompleted.contains { $0.id == active.id } == false)
    }

    @Test func completedIDsFetchExcludesActiveSessions() throws {
        let context = ModelContext(try TestModelContainer.make())
        let run = makeOutdoorRun(context: context)
        let active = makeActiveRun(context: context)
        try context.save()

        let fetched = try context.fetch(CardioSession.completed(ids: [run.id, active.id]))
        #expect(fetched.contains { $0.id == run.id })
        #expect(fetched.contains { $0.id == active.id } == false)
    }

    // MARK: - Spotlight identifier

    @Test func spotlightIdentifierUsesCardioPrefix() {
        let id = UUID()
        let identifier = SpotlightIndexer.cardioSessionIdentifier(for: id)
        #expect(identifier.hasPrefix(SpotlightIndexer.cardioSessionIdentifierPrefix))
        #expect(identifier == "cardioSession:\(id.uuidString)")
    }
}

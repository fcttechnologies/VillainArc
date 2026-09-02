#if DEBUG
import Foundation
import SwiftData
import Testing

@testable import VillainArc

/// The Screenshot Studio seed runs against the detached debug store, so what it may delete is not
/// the question — `DetachedDebugStoreTests` settles that the store is a different file. What is
/// left is the property the captures depend on: the button is pressed repeatedly, and every press
/// has to leave the same curated rows reading as today. A demo session that duplicated on a second
/// press, or that was rebuilt as a new row rather than moved forward, photographs differently on
/// Tuesday than it did on Monday.
@MainActor
struct ScreenshotStudioSeederTests {
    // MARK: - Idempotence

    @Test func secondSeedDuplicatesNothingAndMovesTheDemoRowsRatherThanRebuildingThem() throws {
        let context = ModelContext(try TestModelContainer.make())

        try ScreenshotStudioSeeder.seedAll(in: context)
        let before = try snapshot(context)

        try ScreenshotStudioSeeder.seedAll(in: context)
        let after = try snapshot(context)

        for (table, rowsBefore) in before.sorted(by: { $0.key < $1.key }) {
            let rowsAfter = after[table] ?? []
            #expect(rowsAfter.count == rowsBefore.count, "the second seed changed the \(table) row count: \(rowsBefore.count) → \(rowsAfter.count)")
            guard Self.fixedIdentityTables.contains(table) else { continue }
            let replaced = rowsBefore.subtracting(rowsAfter)
            #expect(replaced.isEmpty, "the second seed rebuilt \(replaced.count) of \(rowsBefore.count) \(table) row(s) instead of moving them forward")
        }
    }

    /// The rows the seeder writes under a fixed `DemoID` and re-anchors on a re-seed. The health
    /// window is deliberately not among them: the health seed rebuilds its 35 days every press,
    /// which is what makes switching scenarios switch the data.
    private static let fixedIdentityTables: Set<String> = [
        "WorkoutPlan", "ExercisePrescription", "SetPrescription",
        "WorkoutSession", "ExercisePerformance", "SetPerformance",
        "CardioSession", "CardioRoutePoint", "Exercise",
    ]

    // MARK: - The demo content the scenes photograph

    @Test func everySceneHasItsDataAfterOneSeedAndAfterTwo() throws {
        let context = ModelContext(try TestModelContainer.make())

        try ScreenshotStudioSeeder.seedAll(in: context)
        try assertDemoContent(in: context, after: "one seed")

        try ScreenshotStudioSeeder.seedAll(in: context)
        try assertDemoContent(in: context, after: "two seeds")
    }

    @Test func aStaleSeedIsMovedForwardRatherThanReplaced() throws {
        let context = ModelContext(try TestModelContainer.make())

        try ScreenshotStudioSeeder.seedAll(in: context)
        try ageDemoSessions(by: -7 * 86400, in: context)
        let before = try snapshot(context)

        try ScreenshotStudioSeeder.seedAll(in: context)
        let after = try snapshot(context)

        try assertDemoContent(in: context, after: "a re-seed of a week-old store")
        for table in Self.fixedIdentityTables.sorted() {
            let replaced = (before[table] ?? []).subtracting(after[table] ?? [])
            #expect(replaced.isEmpty, "re-seeding a week-old store rebuilt \(replaced.count) \(table) row(s) instead of moving them forward")
        }
    }

    /// Winds every session back, the way a store seeded before the last release reads.
    private func ageDemoSessions(by interval: TimeInterval, in context: ModelContext) throws {
        for session in try context.fetch(FetchDescriptor<WorkoutSession>()) {
            session.startedAt = session.startedAt.addingTimeInterval(interval)
            session.endedAt = session.endedAt?.addingTimeInterval(interval)
            for performance in session.sortedExercises {
                performance.date = performance.date.addingTimeInterval(interval)
                for set in performance.sortedSets {
                    set.completedAt = set.completedAt?.addingTimeInterval(interval)
                }
            }
        }
        for cardio in try context.fetch(FetchDescriptor<CardioSession>()) {
            cardio.startedAt = cardio.startedAt?.addingTimeInterval(interval)
            cardio.endedAt = cardio.endedAt?.addingTimeInterval(interval)
            for point in cardio.routePoints ?? [] {
                point.timestamp = point.timestamp.addingTimeInterval(interval)
            }
        }
        try context.save()
    }

    /// Each scenario button hands back exactly its own 35 days: switching scenarios switches the
    /// data rather than layering onto it.
    @Test func switchingScenarioRewritesTheWholeWindow() throws {
        let context = ModelContext(try TestModelContainer.make())

        try DebugOperations.seedHealthSamples(scenario: .daily, in: context)
        #expect(try context.fetch(FetchDescriptor<HealthStepsDistance>()).count == 35)
        #expect(try context.fetch(FetchDescriptor<WeightEntry>()).count == 35)
        #expect(try context.fetch(FetchDescriptor<WeightGoal>()).count == 1)

        // `.rareFastCut` logs a weigh-in on four of the 35 days, so it replaced rather than merged.
        try DebugOperations.seedHealthSamples(scenario: .rareFastCut, in: context)
        #expect(try context.fetch(FetchDescriptor<HealthStepsDistance>()).count == 35)
        #expect(try context.fetch(FetchDescriptor<WeightEntry>()).count == 4)
        #expect(try context.fetch(FetchDescriptor<WeightGoal>()).count == 1)
    }

    // MARK: - Store snapshot

    /// Every table the seed writes, keyed by name. `PersistentIdentifier` is the row's store
    /// identity, so a row that was deleted and re-inserted reads as a different row — which is how
    /// a rebuild is told apart from a re-anchor.
    private func snapshot(_ context: ModelContext) throws -> [String: Set<PersistentIdentifier>] {
        var tables: [String: Set<PersistentIdentifier>] = [:]
        func add<T: PersistentModel>(_ type: T.Type) throws {
            tables["\(T.self)"] = Set(try context.fetch(FetchDescriptor<T>()).map(\.persistentModelID))
        }
        try add(WorkoutPlan.self)
        try add(ExercisePrescription.self)
        try add(SetPrescription.self)
        try add(WorkoutSession.self)
        try add(ExercisePerformance.self)
        try add(SetPerformance.self)
        try add(ExerciseHistory.self)
        try add(CardioSession.self)
        try add(CardioRoutePoint.self)
        try add(CardioMachineInterval.self)
        try add(Exercise.self)
        try add(WeightEntry.self)
        try add(WeightGoal.self)
        try add(HydrationEntry.self)
        try add(HealthStepsDistance.self)
        try add(HealthEnergy.self)
        try add(HealthHeart.self)
        try add(HealthRespiratoryRate.self)
        try add(HealthWristTemperature.self)
        try add(HealthSleepNight.self)
        try add(HealthSleepBlock.self)
        return tables
    }

    // MARK: - Demo content

    /// The rows every studio scene fetches, and the numbers the screenshots are composed of.
    private func assertDemoContent(in context: ModelContext, after moment: String) throws {
        let lbs = WeightUnit.lbs

        let plan = try context.fetch(FetchDescriptor<WorkoutPlan>(predicate: #Predicate { $0.title == "Push Day" })).first
        #expect(plan?.totalExercises == 4, "the demo plan lost its exercises after \(moment)")
        #expect(plan?.totalSets == 13, "the demo plan lost its target sets after \(moment)")
        #expect(plan?.id == ScreenshotStudioSeeder.DemoID.plan, "the AI-result scene would not find the demo plan after \(moment)")

        let done = SessionStatus.done.rawValue
        let history = try context.fetch(FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.status == done }))
        #expect(history.count == 14, "the demo history is \(history.count) sessions after \(moment), not 14")
        #expect(history.allSatisfy { $0.totalSets == 14 }, "a demo history session lost sets after \(moment)")
        let newest = history.map(\.startedAt).max().map { Date.now.timeIntervalSince($0) } ?? .infinity
        #expect(newest < 4 * 86400, "the demo history drifted out of the heatmap's recent window after \(moment)")

        let active = SessionStatus.active.rawValue
        let activeSession = try context.fetch(FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.status == active })).first
        #expect(activeSession?.title == "Push Day", "no active demo session after \(moment)")
        #expect(activeSession?.id == ScreenshotStudioSeeder.DemoID.activeSession, "the active scene would not find the demo session after \(moment)")
        #expect((activeSession.map { Date.now.timeIntervalSince($0.startedAt) } ?? 0) < 30 * 60, "the active demo session is no longer reading as live after \(moment)")
        let benchDone = activeSession?.sortedExercises.first { $0.catalogID == "barbell_bench_press" }?.sortedSets.filter(\.complete).count
        #expect(benchDone == 3, "the active demo session's logged sets changed after \(moment)")

        let summary = SessionStatus.summary.rawValue
        let summarySession = try context.fetch(FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.status == summary })).first
        #expect(summarySession?.totalSets == 14, "the demo summary session lost sets after \(moment)")
        #expect(summarySession?.id == ScreenshotStudioSeeder.DemoID.summarySession, "the summary scene would not find the demo session after \(moment)")
        let topBench = summarySession?.sortedExercises.first { $0.catalogID == "barbell_bench_press" }?.sortedSets.map(\.weight).max() ?? 0
        #expect(abs(topBench - lbs.toKg(185)) < 0.001, "the demo PR weight changed after \(moment)")

        let cardio = try context.fetch(CardioSession.byID(ScreenshotStudioSeeder.DemoID.cardioSession)).first
        #expect(cardio?.routePoints?.count == 81, "the demo route changed after \(moment)")
        #expect((cardio?.totalDistanceMeters ?? 0) > 2_000, "the demo route distance collapsed after \(moment)")

        let benchHistory = try context.fetch(ExerciseHistory.forCatalogID("barbell_bench_press")).first
        let lastLift = benchHistory?.lastCompletedAt.map { Date.now.timeIntervalSince($0) } ?? .infinity
        #expect(lastLift < 4 * 86400, "the cached bench history is stale after \(moment)")

        let steps = try context.fetch(FetchDescriptor<HealthStepsDistance>())
        #expect(steps.count == 35, "the demo health window is \(steps.count) days after \(moment), not 35")
    }
}
#endif

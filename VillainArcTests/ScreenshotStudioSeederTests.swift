#if DEBUG
import Foundation
import SwiftData
import Testing

@testable import VillainArc

/// The Screenshot Studio seed runs against the signed-in account's own store, and the models it
/// touches are sync-enrolled, so a deletion here rides the persistent-history feed out to every
/// device on the account. The seed therefore converges: it may insert, it may re-anchor what it
/// wrote before, and it may never delete. These pin all three — the user's own rows survive a
/// seed, a second seed neither deletes nor duplicates the first one's, and the demo content the
/// screenshots are captured from is exactly what it was.
@MainActor
struct ScreenshotStudioSeederTests {
    // MARK: - Convergence

    @Test func secondSeedDeletesNothingAndDuplicatesNothing() throws {
        let context = ModelContext(try TestModelContainer.make())

        try ScreenshotStudioSeeder.seedAll(in: context)
        let before = try snapshot(context)

        try ScreenshotStudioSeeder.seedAll(in: context)
        let after = try snapshot(context)

        for (table, rowsBefore) in before.sorted(by: { $0.key < $1.key }) {
            let rowsAfter = after[table] ?? []
            let deleted = rowsBefore.subtracting(rowsAfter)
            #expect(deleted.isEmpty, "the second seed deleted \(deleted.count) of \(rowsBefore.count) \(table) row(s)")
            #expect(rowsAfter.count == rowsBefore.count, "the second seed changed the \(table) row count: \(rowsBefore.count) → \(rowsAfter.count)")
        }
    }

    @Test func userAuthoredRowsSurviveEverySeed() throws {
        let context = ModelContext(try TestModelContainer.make())
        let own = try seedUserAuthoredData(in: context)

        try ScreenshotStudioSeeder.seedAll(in: context)
        try assertUserAuthoredDataIntact(own, in: context, after: "the first seed")

        try ScreenshotStudioSeeder.seedAll(in: context)
        try assertUserAuthoredDataIntact(own, in: context, after: "the second seed")
    }

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
        for (table, rowsBefore) in before.sorted(by: { $0.key < $1.key }) {
            let deleted = rowsBefore.subtracting(after[table] ?? [])
            #expect(deleted.isEmpty, "re-seeding a week-old store deleted \(deleted.count) \(table) row(s)")
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

    /// The Debug scenario buttons still replace: each one hands back exactly its own 35 days, and
    /// switching scenarios switches the data rather than layering onto it.
    @Test func aReplacingHealthSeedStillRewritesTheWholeWindow() throws {
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

    /// Every table the seed writes or used to clear, keyed by name. `PersistentIdentifier` is the
    /// row's store identity, so a row that was deleted and re-inserted reads as a different row —
    /// which is the deletion this is looking for.
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

    // MARK: - User-authored data

    private struct UserAuthoredData {
        let planID: UUID
        let sessionID: UUID
        let cardioID: UUID
        let weightEntryID: UUID
        let weightGoalID: UUID
        let catalogID: String
    }

    /// A plan, a completed session on an exercise the demo set never touches (so its cached
    /// history row is the user's alone), a cardio session, a weigh-in and a weight goal.
    private func seedUserAuthoredData(in context: ModelContext) throws -> UserAuthoredData {
        let catalogID = "barbell_squat"
        let exercise = Exercise(from: ExerciseCatalog.byID[catalogID]!)
        context.insert(exercise)

        let plan = WorkoutPlan(title: "My Own Plan", completed: true)
        context.insert(plan)
        plan.addExercise(exercise)

        let session = WorkoutSession(from: plan)
        session.title = "My Own Workout"
        session.startedAt = .now.addingTimeInterval(-3 * 86400)
        session.endedAt = session.startedAt.addingTimeInterval(3600)
        session.status = SessionStatus.done.rawValue
        context.insert(session)
        for performance in session.sortedExercises {
            for set in performance.sortedSets {
                set.weight = 102.5
                set.reps = 5
                set.complete = true
                set.completedAt = session.startedAt.addingTimeInterval(600)
            }
            performance.syncDateToLatestCompletedSet()
        }
        ExerciseHistoryUpdater.updateHistoriesForCompletedWorkout(session, context: context)

        let cardio = CardioSession(activity: .walk, environment: .outdoor)
        cardio.startedAt = .now.addingTimeInterval(-5 * 86400)
        cardio.endedAt = cardio.startedAt?.addingTimeInterval(1800)
        cardio.statusValue = .done
        context.insert(cardio)

        let weightEntry = WeightEntry(date: .now.addingTimeInterval(-86400), weight: 81.5)
        context.insert(weightEntry)

        let weightGoal = WeightGoal(type: .cut, startWeight: 81.5, targetWeight: 78)
        context.insert(weightGoal)

        try context.save()
        return UserAuthoredData(
            planID: plan.id,
            sessionID: session.id,
            cardioID: cardio.id,
            weightEntryID: weightEntry.id,
            weightGoalID: weightGoal.id,
            catalogID: catalogID
        )
    }

    private func assertUserAuthoredDataIntact(_ own: UserAuthoredData, in context: ModelContext, after moment: String) throws {
        let plan = try context.fetch(WorkoutPlan.byID(own.planID)).first
        #expect(plan?.title == "My Own Plan", "the user's plan did not survive \(moment)")

        let session = try context.fetch(WorkoutSession.byID(own.sessionID)).first
        #expect(session?.title == "My Own Workout", "the user's workout did not survive \(moment)")
        #expect(session?.totalSets == 1, "the user's workout lost its sets in \(moment)")

        let cardio = try context.fetch(CardioSession.byID(own.cardioID)).first
        #expect(cardio != nil, "the user's cardio session did not survive \(moment)")

        let history = try context.fetch(ExerciseHistory.forCatalogID(own.catalogID)).first
        #expect(history != nil, "the user's \(own.catalogID) history did not survive \(moment)")

        let weightEntryID = own.weightEntryID
        let weightEntry = try context.fetch(FetchDescriptor<WeightEntry>(predicate: #Predicate { $0.id == weightEntryID })).first
        #expect(weightEntry?.weight == 81.5, "the user's weigh-in did not survive \(moment)")

        let weightGoalID = own.weightGoalID
        let weightGoal = try context.fetch(FetchDescriptor<WeightGoal>(predicate: #Predicate { $0.id == weightGoalID })).first
        #expect(weightGoal != nil, "the user's weight goal did not survive \(moment)")
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

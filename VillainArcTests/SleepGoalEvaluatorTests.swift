import Foundation
import SwiftData
import Testing

@testable import VillainArc

struct SleepGoalEvaluatorTests {
    private func pastDay(_ days: Int) -> Date {
        Calendar.autoupdatingCurrent.date(byAdding: .day, value: -days, to: .now)!
    }

    private func todaySummary(timeAsleep: TimeInterval) -> HealthSleepNight {
        let night = HealthSleepNight(wakeDay: .now)
        night.timeAsleep = timeAsleep
        return night
    }

    @Test func reachingGoalTodayReturnsNotificationAndStampsState() throws {
        let context = try TestDataFactory.makeContext()
        context.insert(SleepGoal(startedOnDay: pastDay(30), targetSleepDuration: 7 * 3_600))
        let summary = todaySummary(timeAsleep: 8 * 3_600)
        context.insert(summary)
        let syncState = HealthSyncState()
        context.insert(syncState)

        let notification = try SleepGoalEvaluator.reconcileToday(summary: summary, syncState: syncState, context: context)
        #expect(notification != nil)
        #expect(notification?.title == "Sleep Goal Reached")
        #expect(syncState.sleepGoalLastNotifiedWakeDay == HealthSleepNight.wakeDayKey(for: .now))
    }

    @Test func sameDayDoesNotNotifyTwice() throws {
        let context = try TestDataFactory.makeContext()
        context.insert(SleepGoal(startedOnDay: pastDay(30), targetSleepDuration: 7 * 3_600))
        let summary = todaySummary(timeAsleep: 8 * 3_600)
        context.insert(summary)
        let syncState = HealthSyncState()
        syncState.sleepGoalLastNotifiedWakeDay = HealthSleepNight.wakeDayKey(for: .now)
        context.insert(syncState)

        #expect(try SleepGoalEvaluator.reconcileToday(summary: summary, syncState: syncState, context: context) == nil)
    }

    @Test func belowTargetReturnsNil() throws {
        let context = try TestDataFactory.makeContext()
        context.insert(SleepGoal(startedOnDay: pastDay(30), targetSleepDuration: 8 * 3_600))
        let summary = todaySummary(timeAsleep: 6 * 3_600)
        context.insert(summary)
        let syncState = HealthSyncState()
        context.insert(syncState)

        #expect(try SleepGoalEvaluator.reconcileToday(summary: summary, syncState: syncState, context: context) == nil)
    }

    @Test func noGoalReturnsNil() throws {
        let context = try TestDataFactory.makeContext()
        let summary = todaySummary(timeAsleep: 8 * 3_600)
        context.insert(summary)
        let syncState = HealthSyncState()
        context.insert(syncState)

        #expect(try SleepGoalEvaluator.reconcileToday(summary: summary, syncState: syncState, context: context) == nil)
    }

    @Test func nilSummaryReturnsNil() throws {
        let context = try TestDataFactory.makeContext()
        context.insert(SleepGoal(startedOnDay: pastDay(1), targetSleepDuration: 7 * 3_600))
        let syncState = HealthSyncState()
        context.insert(syncState)

        #expect(try SleepGoalEvaluator.reconcileToday(summary: nil, syncState: syncState, context: context) == nil)
    }

    @Test func sleepGoalNotificationLocalVersionRespectsMode() {
        let note = SleepGoalNotification(wakeDay: .now, timeAsleep: 8 * 3_600, targetSleepDuration: 7 * 3_600)
        #expect(note.localNotificationVersion(for: .off) == nil)
        #expect(note.localNotificationVersion(for: .goalOnly) == note)
        #expect(note.localNotificationVersion(for: .coaching) == note)
        #expect(note.title == "Sleep Goal Reached")
        #expect(note.body.contains("8h"))
        #expect(note.body.contains("7h"))
    }
}

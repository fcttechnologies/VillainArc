import Foundation
import SwiftData
import Testing

@testable import VillainArc

struct StepsCoachingEvaluatorTests {
    private let calendar = Calendar.autoupdatingCurrent

    private func today() -> Date { calendar.startOfDay(for: .now) }

    private func summary(stepCount: Int, target: Int?, daysAgo: Int = 0) -> HealthStepsDistance {
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: .now)!
        return HealthStepsDistance(date: day, stepCount: stepCount, goalTargetSteps: target)
    }

    private func seedHistory(_ context: ModelContext, stepCount: Int, daysAgo: Int) {
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: .now)!
        context.insert(HealthStepsDistance(date: day, stepCount: stepCount))
    }

    // MARK: - Evaluator state machine

    @Test func goalMilestoneFiresWithoutNewBestWhenPriorBestIsHigher() throws {
        let context = try TestDataFactory.makeContext()
        seedHistory(context, stepCount: 8_000, daysAgo: 1)   // prior best, so today (6k) is not a new best
        let s = summary(stepCount: 6_000, target: 5_000)
        context.insert(s)
        let state = HealthSyncState()
        context.insert(state)

        let note = try StepsCoachingEvaluator.reconcileToday(summary: s, syncState: state, context: context, goalJustAchieved: true, trigger: .syncUpdate)
        #expect(note?.milestone == .goal)
        #expect(note?.includesNewBest == false)
        #expect(note?.includesGoalCompletion == true)
    }

    @Test func doubleGoalFiresThenDedupesSameDay() throws {
        let context = try TestDataFactory.makeContext()
        seedHistory(context, stepCount: 30_000, daysAgo: 1)
        let s = summary(stepCount: 11_000, target: 5_000)   // >= 2x, < 3x
        context.insert(s)
        let state = HealthSyncState()
        context.insert(state)

        let first = try StepsCoachingEvaluator.reconcileToday(summary: s, syncState: state, context: context, goalJustAchieved: false, trigger: .syncUpdate)
        #expect(first?.milestone == .doubleGoal)

        let second = try StepsCoachingEvaluator.reconcileToday(summary: s, syncState: state, context: context, goalJustAchieved: false, trigger: .syncUpdate)
        #expect(second == nil)
    }

    @Test func tripleGoalAlsoStampsDoubleSoDoubleIsSuppressed() throws {
        let context = try TestDataFactory.makeContext()
        seedHistory(context, stepCount: 50_000, daysAgo: 1)
        let s = summary(stepCount: 16_000, target: 5_000)   // >= 3x
        context.insert(s)
        let state = HealthSyncState()
        context.insert(state)

        let note = try StepsCoachingEvaluator.reconcileToday(summary: s, syncState: state, context: context, goalJustAchieved: false, trigger: .syncUpdate)
        #expect(note?.milestone == .tripleGoal)
        #expect(calendar.isDate(state.doubleGoalLastTriggeredDay ?? .distantPast, inSameDayAs: today()))
        #expect(calendar.isDate(state.tripleGoalLastTriggeredDay ?? .distantPast, inSameDayAs: today()))
    }

    @Test func newBestFiresAndUpdatesBestKnown() throws {
        let context = try TestDataFactory.makeContext()
        seedHistory(context, stepCount: 5_000, daysAgo: 1)
        let s = summary(stepCount: 9_000, target: nil)
        context.insert(s)
        let state = HealthSyncState()
        context.insert(state)

        let note = try StepsCoachingEvaluator.reconcileToday(summary: s, syncState: state, context: context, goalJustAchieved: false, trigger: .syncUpdate)
        #expect(note?.includesNewBest == true)
        #expect(note?.milestone == nil)
        #expect(state.bestDailyStepsKnown == 9_000)
    }

    @Test func newBestDoesNotRefireSameDay() throws {
        let context = try TestDataFactory.makeContext()
        seedHistory(context, stepCount: 5_000, daysAgo: 1)
        let s = summary(stepCount: 9_000, target: nil)
        context.insert(s)
        let state = HealthSyncState()
        context.insert(state)
        _ = try StepsCoachingEvaluator.reconcileToday(summary: s, syncState: state, context: context, goalJustAchieved: false, trigger: .syncUpdate)

        s.stepCount = 11_000   // higher later in the same day → updates best, no second notification
        let note = try StepsCoachingEvaluator.reconcileToday(summary: s, syncState: state, context: context, goalJustAchieved: false, trigger: .syncUpdate)
        #expect(note == nil)
        #expect(state.bestDailyStepsKnown == 11_000)
    }

    @Test func goalChangeTriggerUpdatesStateButReturnsNil() throws {
        let context = try TestDataFactory.makeContext()
        seedHistory(context, stepCount: 30_000, daysAgo: 1)
        let s = summary(stepCount: 11_000, target: 5_000)
        context.insert(s)
        let state = HealthSyncState()
        context.insert(state)

        let note = try StepsCoachingEvaluator.reconcileToday(summary: s, syncState: state, context: context, goalJustAchieved: false, trigger: .goalChange)
        #expect(note == nil)
        #expect(calendar.isDate(state.doubleGoalLastTriggeredDay ?? .distantPast, inSameDayAs: today()))
    }

    @Test func nilSummaryClearsTodaysMilestoneState() throws {
        let context = try TestDataFactory.makeContext()
        let state = HealthSyncState()
        state.doubleGoalLastTriggeredDay = today()
        state.tripleGoalLastTriggeredDay = today()
        context.insert(state)

        let note = try StepsCoachingEvaluator.reconcileToday(summary: nil, syncState: state, context: context, goalJustAchieved: false, trigger: .syncUpdate)
        #expect(note == nil)
        #expect(state.doubleGoalLastTriggeredDay == nil)
        #expect(state.tripleGoalLastTriggeredDay == nil)
    }

    @Test func nonTodaySummaryReturnsNil() throws {
        let context = try TestDataFactory.makeContext()
        let s = summary(stepCount: 20_000, target: 5_000, daysAgo: 1)
        context.insert(s)
        let state = HealthSyncState()
        context.insert(state)

        let note = try StepsCoachingEvaluator.reconcileToday(summary: s, syncState: state, context: context, goalJustAchieved: true, trigger: .syncUpdate)
        #expect(note == nil)
    }

    @Test func historicalBestExcludesGivenDay() throws {
        let context = try TestDataFactory.makeContext()
        seedHistory(context, stepCount: 8_000, daysAgo: 1)
        seedHistory(context, stepCount: 12_000, daysAgo: 2)
        context.insert(HealthStepsDistance(date: .now, stepCount: 10_000))   // excluded
        let best = try StepsCoachingEvaluator.historicalBestDailySteps(excluding: .now, context: context)
        #expect(best == 12_000)
    }

    // MARK: - StepsEventNotification

    @Test func notificationTitlesMatchMilestones() {
        #expect(StepsEventNotification(stepCount: 1, targetSteps: 1, milestone: .goal, includesNewBest: false, includesGoalCompletion: true).title == "Steps Goal Reached")
        #expect(StepsEventNotification(stepCount: 1, targetSteps: 1, milestone: .doubleGoal, includesNewBest: false, includesGoalCompletion: true).title == "Double Goal Reached")
        #expect(StepsEventNotification(stepCount: 1, targetSteps: 1, milestone: .tripleGoal, includesNewBest: false, includesGoalCompletion: true).title == "Triple Goal Reached")
        #expect(StepsEventNotification(stepCount: 1, targetSteps: nil, milestone: nil, includesNewBest: true, includesGoalCompletion: false).title == "New Personal Best")
        #expect(StepsEventNotification(stepCount: 1, targetSteps: nil, milestone: nil, includesNewBest: false, includesGoalCompletion: false).title == "Steps Update")
    }

    @Test func notificationBodyAppendsNewBestSuffixForMilestone() {
        let note = StepsEventNotification(stepCount: 12_000, targetSteps: 5_000, milestone: .doubleGoal, includesNewBest: true, includesGoalCompletion: true)
        #expect(note.body.hasSuffix("new best for you."))
    }

    @Test func notificationLocalVersionRespectsMode() {
        let coaching = StepsEventNotification(stepCount: 12_000, targetSteps: 5_000, milestone: .doubleGoal, includesNewBest: false, includesGoalCompletion: true)
        #expect(coaching.localNotificationVersion(for: .off) == nil)
        #expect(coaching.localNotificationVersion(for: .coaching) == coaching)

        let goalOnly = coaching.localNotificationVersion(for: .goalOnly)
        #expect(goalOnly?.milestone == .goal)
        #expect(goalOnly?.includesNewBest == false)

        let noGoalCompletion = StepsEventNotification(stepCount: 9_000, targetSteps: nil, milestone: nil, includesNewBest: true, includesGoalCompletion: false)
        #expect(noGoalCompletion.localNotificationVersion(for: .goalOnly) == nil)
    }
}

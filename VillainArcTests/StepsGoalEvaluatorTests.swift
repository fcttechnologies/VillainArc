import Foundation
import SwiftData
import Testing

@testable import VillainArc

struct StepsGoalEvaluatorTests {
    private let calendar = Calendar.autoupdatingCurrent

    private func pastDay(_ days: Int) -> Date {
        calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: .now))!
    }

    @Test func meetingGoalTodayViaSyncReturnsTrueAndStampsCompletion() throws {
        let context = try TestDataFactory.makeContext()
        context.insert(StepsGoal(startedOnDay: pastDay(30), targetSteps: 10_000))
        let summary = HealthStepsDistance(date: .now, stepCount: 12_000)
        context.insert(summary)

        let didNotify = try StepsGoalEvaluator.reevaluateAchievement(for: summary, context: context, trigger: .syncUpdate)
        #expect(didNotify == true)
        #expect(summary.goalCompleted == true)
        #expect(summary.goalCompletedAt != nil)
        #expect(summary.goalTargetSteps == 10_000)
    }

    @Test func meetingGoalOnPastDayCompletesButDoesNotNotify() throws {
        let context = try TestDataFactory.makeContext()
        context.insert(StepsGoal(startedOnDay: pastDay(30), targetSteps: 10_000))
        let yesterday = calendar.date(byAdding: .day, value: -1, to: .now)!
        let summary = HealthStepsDistance(date: yesterday, stepCount: 12_000)
        context.insert(summary)

        let didNotify = try StepsGoalEvaluator.reevaluateAchievement(for: summary, context: context, trigger: .syncUpdate)
        #expect(didNotify == false)
        #expect(summary.goalCompleted == true)
        #expect(summary.goalCompletedAt == calendar.startOfDay(for: yesterday))
    }

    @Test func goalChangeTriggerNeverNotifiesEvenWhenNewlyCompleteToday() throws {
        let context = try TestDataFactory.makeContext()
        context.insert(StepsGoal(startedOnDay: pastDay(30), targetSteps: 10_000))
        let summary = HealthStepsDistance(date: .now, stepCount: 12_000)
        context.insert(summary)

        let didNotify = try StepsGoalEvaluator.reevaluateAchievement(for: summary, context: context, trigger: .goalChange)
        #expect(didNotify == false)
        #expect(summary.goalCompleted == true)
    }

    @Test func droppingBelowGoalClearsCompletion() throws {
        let context = try TestDataFactory.makeContext()
        context.insert(StepsGoal(startedOnDay: pastDay(30), targetSteps: 10_000))
        let summary = HealthStepsDistance(date: .now, stepCount: 5_000, goalCompletedAt: .now)
        context.insert(summary)
        #expect(summary.goalCompleted == true)

        let didNotify = try StepsGoalEvaluator.reevaluateAchievement(for: summary, context: context, trigger: .syncUpdate)
        #expect(didNotify == false)
        #expect(summary.goalCompletedAt == nil)
        #expect(summary.goalCompleted == false)
    }

    @Test func noGoalMeansNotCompleted() throws {
        let context = try TestDataFactory.makeContext()
        let summary = HealthStepsDistance(date: .now, stepCount: 12_000)
        context.insert(summary)

        let didNotify = try StepsGoalEvaluator.reevaluateAchievement(for: summary, context: context, trigger: .syncUpdate)
        #expect(didNotify == false)
        #expect(summary.goalCompleted == false)
        #expect(summary.goalTargetSteps == nil)
    }

    @Test func alreadyCompletedDoesNotRetrigger() throws {
        let context = try TestDataFactory.makeContext()
        context.insert(StepsGoal(startedOnDay: pastDay(30), targetSteps: 10_000))
        let summary = HealthStepsDistance(date: .now, stepCount: 12_000, goalCompletedAt: .now)
        context.insert(summary)

        let didNotify = try StepsGoalEvaluator.reevaluateAchievement(for: summary, context: context, trigger: .syncUpdate)
        #expect(didNotify == false)
        #expect(summary.goalCompleted == true)
    }
}

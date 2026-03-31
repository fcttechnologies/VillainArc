import Foundation
import SwiftData

nonisolated enum StepsGoalMilestone: String, Sendable {
    case goal
    case doubleGoal
    case tripleGoal
}

nonisolated struct StepsEventNotification: Sendable, Equatable {
    let stepCount: Int
    let targetSteps: Int?
    let milestone: StepsGoalMilestone?
    let includesNewBest: Bool
    let includesGoalCompletion: Bool

    var title: String {
        switch (milestone, includesNewBest) {
        case (.goal, _):
            return "Steps Goal Reached"
        case (.doubleGoal, _):
            return "Double Goal Reached"
        case (.tripleGoal, _):
            return "Triple Goal Reached"
        case (nil, true):
            return "New Personal Best"
        case (nil, false):
            return "Steps Update"
        }
    }

    var body: String {
        let compactStepCount = Self.compactStepsText(stepCount)
        let baseMessage: String

        switch milestone {
        case .goal:
            let compactTargetSteps = targetSteps.map(Self.compactStepsText) ?? compactStepCount
            baseMessage = "You hit \(compactStepCount) steps and cleared your \(compactTargetSteps) daily step goal."
        case .doubleGoal:
            let compactTargetSteps = targetSteps.map(Self.compactStepsText) ?? compactStepCount
            baseMessage = "You reached \(compactStepCount) steps, 2x your \(compactTargetSteps) step goal."
        case .tripleGoal:
            let compactTargetSteps = targetSteps.map(Self.compactStepsText) ?? compactStepCount
            baseMessage = "You reached \(compactStepCount) steps, 3x your \(compactTargetSteps) step goal."
        case nil:
            baseMessage = "You hit \(compactStepCount) steps, a new personal best."
        }

        guard includesNewBest, milestone != nil else { return baseMessage }
        return String(baseMessage.dropLast()) + ", which is also a new best for you."
    }

    func localNotificationVersion(for mode: StepsEventNotificationMode) -> StepsEventNotification? {
        switch mode {
        case .off:
            return nil
        case .goalOnly:
            guard let targetSteps, includesGoalCompletion else { return nil }
            return StepsEventNotification(stepCount: stepCount, targetSteps: targetSteps, milestone: .goal, includesNewBest: false, includesGoalCompletion: true)
        case .coaching:
            return self
        }
    }

    private static func compactStepsText(_ steps: Int) -> String {
        steps.formatted(.number.notation(.compactName).precision(.fractionLength(0...1))).lowercased()
    }
}

nonisolated enum StepsCoachingEvaluator {
    enum Trigger {
        case syncUpdate
        case goalChange
    }

    private static let calendar = Calendar.autoupdatingCurrent

    static func reconcileToday(summary: HealthStepsDistance?, syncState: HealthSyncState, context: ModelContext, goalJustAchieved: Bool, trigger: Trigger, recomputeBestDailyStepsKnown: Bool = false) throws -> StepsEventNotification? {
        let today = calendar.startOfDay(for: .now)

        if recomputeBestDailyStepsKnown || syncState.bestDailyStepsKnown == nil {
            syncState.bestDailyStepsKnown = try historicalBestDailySteps(excluding: today, context: context)
        }

        guard let summary else {
            clearGoalMilestoneStateIfTrackedToday(syncState: syncState, today: today)
            if recomputeBestDailyStepsKnown, isTracked(syncState.newHighStepsLastTriggeredDay, on: today) {
                syncState.newHighStepsLastTriggeredDay = nil
            }
            return nil
        }

        let summaryDay = calendar.startOfDay(for: summary.date)
        guard summaryDay == today else { return nil }

        let targetSteps = max(summary.goalTargetSteps ?? 0, 0)
        let qualifiesForDoubleGoal = targetSteps > 0 && summary.stepCount >= targetSteps * 2
        let qualifiesForTripleGoal = targetSteps > 0 && summary.stepCount >= targetSteps * 3

        reconcileGoalMilestoneState(syncState: syncState, today: today, qualifiesForDoubleGoal: qualifiesForDoubleGoal, qualifiesForTripleGoal: qualifiesForTripleGoal)

        let bestBeforeToday = syncState.bestDailyStepsKnown ?? 0
        let isNewBest = summary.stepCount > bestBeforeToday
        if isNewBest {
            syncState.bestDailyStepsKnown = summary.stepCount
        }

        let shouldTriggerNewBest = isNewBest && !isTracked(syncState.newHighStepsLastTriggeredDay, on: today)
        if isNewBest || trigger == .goalChange {
            syncState.newHighStepsLastTriggeredDay = isNewBest ? today : syncState.newHighStepsLastTriggeredDay
        }

        let milestoneToDeliver: StepsGoalMilestone?
        if qualifiesForTripleGoal && !isTracked(syncState.tripleGoalLastTriggeredDay, on: today) {
            syncState.tripleGoalLastTriggeredDay = today
            syncState.doubleGoalLastTriggeredDay = today
            milestoneToDeliver = .tripleGoal
        } else if qualifiesForDoubleGoal && !isTracked(syncState.doubleGoalLastTriggeredDay, on: today) {
            syncState.doubleGoalLastTriggeredDay = today
            milestoneToDeliver = .doubleGoal
        } else if goalJustAchieved {
            milestoneToDeliver = .goal
        } else {
            milestoneToDeliver = nil
        }

        if shouldTriggerNewBest {
            syncState.newHighStepsLastTriggeredDay = today
        } else if !isNewBest && isTracked(syncState.newHighStepsLastTriggeredDay, on: today) && recomputeBestDailyStepsKnown {
            syncState.newHighStepsLastTriggeredDay = nil
        }

        guard trigger == .syncUpdate else { return nil }
        guard milestoneToDeliver != nil || shouldTriggerNewBest else { return nil }

        return StepsEventNotification(stepCount: summary.stepCount, targetSteps: targetSteps > 0 ? targetSteps : nil, milestone: milestoneToDeliver, includesNewBest: shouldTriggerNewBest, includesGoalCompletion: goalJustAchieved)
    }

    static func reconcileTodayForGoalChange(context: ModelContext) throws {
        let today = calendar.startOfDay(for: .now)
        guard let syncState = try context.fetch(HealthSyncState.single).first else { return }
        let summary = try context.fetch(HealthStepsDistance.forDay(today)).first
        _ = try reconcileToday(summary: summary, syncState: syncState, context: context, goalJustAchieved: false, trigger: .goalChange)
    }

    static func historicalBestDailySteps(excluding excludedDay: Date, context: ModelContext) throws -> Int? {
        let excludedDay = calendar.startOfDay(for: excludedDay)
        let entries = try context.fetch(HealthStepsDistance.history)
        return entries.filter { calendar.startOfDay(for: $0.date) != excludedDay }.map(\.stepCount).max()
    }

    private static func reconcileGoalMilestoneState(syncState: HealthSyncState, today: Date, qualifiesForDoubleGoal: Bool, qualifiesForTripleGoal: Bool) {
        if qualifiesForTripleGoal {
            if isTracked(syncState.tripleGoalLastTriggeredDay, on: today) { syncState.doubleGoalLastTriggeredDay = today }
        } else if isTracked(syncState.tripleGoalLastTriggeredDay, on: today) {
            syncState.tripleGoalLastTriggeredDay = nil
        }

        if !qualifiesForDoubleGoal, isTracked(syncState.doubleGoalLastTriggeredDay, on: today) {
            syncState.doubleGoalLastTriggeredDay = nil
        }
    }

    private static func clearGoalMilestoneStateIfTrackedToday(syncState: HealthSyncState, today: Date) {
        if isTracked(syncState.doubleGoalLastTriggeredDay, on: today) { syncState.doubleGoalLastTriggeredDay = nil }
        if isTracked(syncState.tripleGoalLastTriggeredDay, on: today) { syncState.tripleGoalLastTriggeredDay = nil }
    }

    private static func isTracked(_ day: Date?, on comparisonDay: Date) -> Bool {
        guard let day else { return false }
        return calendar.isDate(day, inSameDayAs: comparisonDay)
    }
}

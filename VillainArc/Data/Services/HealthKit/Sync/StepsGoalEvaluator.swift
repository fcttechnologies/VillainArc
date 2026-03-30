import Foundation
import SwiftData

enum StepsGoalEvaluator {
    enum Trigger {
        case syncUpdate
        case goalChange
    }

    nonisolated private static let calendar = Calendar.autoupdatingCurrent

    @discardableResult
    nonisolated static func reevaluateAchievement(for summary: HealthStepsDistance, context: ModelContext, trigger: Trigger = .syncUpdate) throws -> Bool {
        let wasCompleted = summary.goalCompleted
        let day = calendar.startOfDay(for: summary.date)
        let goal = try context.fetch(StepsGoal.forDay(day)).first
        summary.goalTargetSteps = goal?.targetSteps
        let meetsGoal = goal.map { summary.stepCount >= $0.targetSteps } ?? false

        if meetsGoal {
            if !wasCompleted {
                switch trigger {
                case .syncUpdate:
                    if calendar.isDateInToday(day) {
                        summary.goalCompletedAt = .now
                    } else {
                        summary.goalCompletedAt = day
                    }
                case .goalChange:
                    summary.goalCompletedAt = .now
                }
            }
        } else {
            summary.goalCompletedAt = nil
        }

        guard !wasCompleted, summary.goalCompleted, calendar.isDateInToday(day) else { return false }
        switch trigger {
        case .syncUpdate:
            return true
        case .goalChange:
            return false
        }
    }

    nonisolated static func reevaluateAchievement(forDay day: Date, context: ModelContext, trigger: Trigger = .goalChange) throws {
        guard let summary = try context.fetch(HealthStepsDistance.forDay(day)).first else { return }
        _ = try reevaluateAchievement(for: summary, context: context, trigger: trigger)
    }
}

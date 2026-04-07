import Foundation
import SwiftData

struct SplitScheduleResolution {
    let split: WorkoutSplit
    let date: Date
    let splitDay: WorkoutSplitDay?
    let activeCondition: TrainingConditionPeriod?
    let effectiveDate: Date

    var isPaused: Bool {
        activeCondition?.trainingImpact == .pauseTraining
    }

    var isModified: Bool {
        activeCondition?.trainingImpact == .trainModified
    }

    var isContextOnly: Bool {
        activeCondition?.trainingImpact == .contextOnly
    }

    var isRestDay: Bool {
        !isPaused && splitDay?.isRestDay == true
    }

    var workoutPlan: WorkoutPlan? {
        guard !isPaused, let splitDay, !splitDay.isRestDay else { return nil }
        return splitDay.workoutPlan
    }

    var dayIndex: Int? {
        split.dayIndex(for: effectiveDate)
    }

    var conditionStatusText: String? {
        guard let activeCondition else { return nil }

        if let endDay = displayedEndDay(for: activeCondition.endDate) {
            return "\(activeCondition.kind.title) • Ends \(formattedRecentDay(endDay))"
        }

        return "\(activeCondition.kind.title) • Until changed"
    }

    var contextNoteText: String? {
        guard let activeCondition else { return nil }

        switch activeCondition.trainingImpact {
        case .contextOnly:
            return "\(activeCondition.kind.title) context"
        case .trainModified:
            return "Adjusted for \(activeCondition.kind.title)"
        case .pauseTraining:
            return nil
        }
    }

    private func displayedEndDay(for endDate: Date?) -> Date? {
        guard let endDate else { return nil }
        return endDate.addingTimeInterval(-1)
    }
}

enum SplitScheduleResolver {
    static func resolveActive(at date: Date = .now, context: ModelContext) -> SplitScheduleResolution? {
        guard let split = try? context.fetch(WorkoutSplit.active).first else { return nil }
        return resolve(split, at: date, context: context)
    }

    static func resolve(_ split: WorkoutSplit, at date: Date = .now, context: ModelContext, syncProgress: Bool = true) -> SplitScheduleResolution {
        let calendar = Calendar.current
        let activeCondition = try? context.fetch(TrainingConditionPeriod.active(at: date)).first

        if syncProgress {
            synchronizeRotationIfNeeded(split, at: date, activeCondition: activeCondition, context: context, calendar: calendar)
        }

        let effectiveDate = effectiveScheduleDate(for: date, activeCondition: activeCondition, calendar: calendar)
        let splitDay = split.splitDay(for: effectiveDate, calendar: calendar)

        return SplitScheduleResolution(
            split: split,
            date: date,
            splitDay: splitDay,
            activeCondition: activeCondition,
            effectiveDate: effectiveDate
        )
    }

    private static func synchronizeRotationIfNeeded(_ split: WorkoutSplit, at date: Date, activeCondition: TrainingConditionPeriod?, context: ModelContext, calendar: Calendar) {
        guard split.mode == .rotation else { return }
        guard calendar.isDateInToday(date) else { return }

        let startToday = calendar.startOfDay(for: date)

        if activeCondition?.trainingImpact == .pauseTraining {
            let lastUpdatedDay = split.rotationLastUpdatedDate.map(calendar.startOfDay(for:))
            guard lastUpdatedDay != startToday else { return }
            split.rotationLastUpdatedDate = startToday
            try? context.save()
            return
        }

        split.refreshRotationIfNeeded(today: date, context: context)
    }

    private static func effectiveScheduleDate(for date: Date, activeCondition: TrainingConditionPeriod?, calendar: Calendar) -> Date {
        guard let activeCondition, activeCondition.trainingImpact == .pauseTraining else { return date }

        let targetDay = calendar.startOfDay(for: date)
        let pauseStartDay = calendar.startOfDay(for: activeCondition.startDate)
        return min(targetDay, pauseStartDay)
    }
}

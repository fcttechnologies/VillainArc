import Foundation
import SwiftData

nonisolated struct SleepGoalNotification: Sendable, Equatable {
    let wakeDay: Date
    let timeAsleep: TimeInterval
    let targetSleepDuration: TimeInterval

    var title: String {
        "Sleep Goal Reached"
    }

    var body: String {
        "You slept \(Self.formattedDurationText(timeAsleep)) and reached your \(Self.formattedDurationText(targetSleepDuration)) sleep goal."
    }

    func localNotificationVersion(for mode: SleepNotificationMode) -> SleepGoalNotification? {
        switch mode {
        case .off:
            return nil
        case .goalOnly, .coaching:
            return self
        }
    }

    private static func formattedDurationText(_ duration: TimeInterval) -> String {
        let totalMinutes = Int((duration / 60).rounded())
        let hours = max(totalMinutes / 60, 0)
        let minutes = max(totalMinutes % 60, 0)

        if minutes == 0 {
            return String(localized: "\(hours)h")
        }
        if hours == 0 {
            return String(localized: "\(minutes)m")
        }
        return String(localized: "\(hours)h \(minutes)m")
    }
}

nonisolated enum SleepGoalEvaluator {
    nonisolated private static let calendar = Calendar.autoupdatingCurrent

    static func reconcileToday(summary: HealthSleepNight?, syncState: HealthSyncState, context: ModelContext) throws -> SleepGoalNotification? {
        let todayWakeDay = HealthSleepNight.wakeDayKey(for: .now)
        guard let summary, summary.wakeDay == todayWakeDay else { return nil }

        guard let goal = try context.fetch(SleepGoal.forDay(todayWakeDay)).first else { return nil }
        guard goal.targetSleepDuration > 0 else { return nil }
        guard summary.timeAsleep >= goal.targetSleepDuration else { return nil }

        if let lastNotifiedWakeDay = syncState.sleepGoalLastNotifiedWakeDay,
           calendar.isDate(lastNotifiedWakeDay, inSameDayAs: todayWakeDay) {
            return nil
        }

        syncState.sleepGoalLastNotifiedWakeDay = todayWakeDay
        return SleepGoalNotification(wakeDay: todayWakeDay, timeAsleep: summary.timeAsleep, targetSleepDuration: goal.targetSleepDuration)
    }
}

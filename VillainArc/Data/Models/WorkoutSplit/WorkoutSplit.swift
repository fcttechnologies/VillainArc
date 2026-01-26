import Foundation
import SwiftData

@Model
class WorkoutSplit {
    var mode: SplitMode = SplitMode.weekly
    var isActive: Bool = true
    
    // Weekly mode: offset when user skips a day
    var weeklySplitOffset: Int = 0
    
    // Rotation mode: current position in the cycle
    var rotationCurrentIndex: Int = 0
    var rotationLastUpdatedDate: Date? = nil
    
    @Relationship(deleteRule: .cascade, inverse: \WorkoutSplitDay.split)
    var days: [WorkoutSplitDay] = []
    
    var sortedDays: [WorkoutSplitDay] {
        switch mode {
        case .weekly:
            return days.sorted(by: { $0.weekday < $1.weekday })
        case .rotation:
            return days.sorted(by: { $0.index < $1.index })
        }
    }
    
    init() {}

    func missedDay() {
        weeklySplitOffset = (weeklySplitOffset + 1) % 7
    }

    func resetSplit() {
        weeklySplitOffset = 0
    }

    func updateCurrentIndex(advanced: Bool, today: Date = .now) {
        let cal = Calendar.current
        let startToday = cal.startOfDay(for: today)
        rotationLastUpdatedDate = startToday
        guard !days.isEmpty else { return }
        let delta = advanced ? 1 : -1
        let count = days.count
        let normalized = ((rotationCurrentIndex + delta) % count + count) % count
        rotationCurrentIndex = normalized
    }
    
    func refreshRotationIfNeeded(today: Date = .now) {
        guard mode == .rotation && !days.isEmpty else { return }
        let cal = Calendar.current
        let last = rotationLastUpdatedDate ?? today
        let startLast = cal.startOfDay(for: last)
        let startToday = cal.startOfDay(for: today)
        let delta = cal.dateComponents([.day], from: startLast, to: startToday).day ?? 0
        guard delta > 0 else {
            rotationLastUpdatedDate = startToday
            return
        }
        rotationCurrentIndex = (rotationCurrentIndex + delta) % days.count
        rotationLastUpdatedDate = startToday
    }
    
    var todaysDayIndex: Int? {
        switch mode {
        case .weekly:
            let weekday = Calendar.current.component(.weekday, from: .now)
            let adjusted = weekday + weeklySplitOffset
            let wrapped = ((adjusted - 1) % 7 + 7) % 7 + 1
            return wrapped
        case .rotation:
            let count = sortedDays.count
            guard count > 0 else { return nil }
            let normalized = ((rotationCurrentIndex % count) + count) % count
            return normalized
        }
    }
    
    var todaysSplitDay: WorkoutSplitDay? {
        switch mode {
        case .weekly:
            guard let weekday = todaysDayIndex else { return nil }
            return days.first { $0.weekday == weekday }
        case .rotation:
            guard let position = todaysDayIndex else { return nil }
            let ordered = sortedDays
            guard position >= 0 && position < ordered.count else { return nil }
            return ordered[position]
        }
    }
    
    var todaysTemplate: WorkoutTemplate? {
        guard let day = todaysSplitDay, !day.isRestDay else { return nil }
        return day.template
    }
}

extension WorkoutSplit {
    static var active: FetchDescriptor<WorkoutSplit> {
        var descriptor = FetchDescriptor(predicate: #Predicate<WorkoutSplit> { $0.isActive })
        descriptor.fetchLimit = 1
        return descriptor
    }
}

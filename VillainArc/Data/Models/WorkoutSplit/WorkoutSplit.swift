import Foundation
import SwiftData

@Model
class WorkoutSplit {
    var title: String = ""
    var mode: SplitMode = SplitMode.weekly
    var isActive: Bool = false
    
    // Weekly mode: offset when user misses a day
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
    
    init(mode: SplitMode) {
        self.mode = mode
    }

    // Test/sample initializer to reduce setup boilerplate.
    convenience init(title: String = "", mode: SplitMode = .weekly, isActive: Bool = false) {
        self.init(mode: mode)
        self.title = title
        self.isActive = isActive
    }

    func missedDay() {
        weeklySplitOffset = wrappedWeeklyOffset(weeklySplitOffset - 1)
    }

    func resetSplit() {
        weeklySplitOffset = 0
    }

    var normalizedWeeklyOffset: Int {
        wrappedWeeklyOffset(weeklySplitOffset)
    }

    private func wrappedWeeklyOffset(_ value: Int) -> Int {
        let mod = ((value % 7) + 7) % 7
        return mod == 0 ? 0 : mod - 7
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
    
    @MainActor
    func refreshRotationIfNeeded(today: Date = .now, context: ModelContext) {
        guard mode == .rotation && !days.isEmpty else { return }
        let cal = Calendar.current
        let last = rotationLastUpdatedDate ?? today
        let startLast = cal.startOfDay(for: last)
        let startToday = cal.startOfDay(for: today)
        let delta = cal.dateComponents([.day], from: startLast, to: startToday).day ?? 0
        var didUpdate = false
        if delta > 0 {
            rotationCurrentIndex = (rotationCurrentIndex + delta) % days.count
            rotationLastUpdatedDate = startToday
            didUpdate = true
        } else if rotationLastUpdatedDate == nil || startLast != startToday {
            rotationLastUpdatedDate = startToday
            didUpdate = true
        }
        if didUpdate {
            saveContext(context: context)
        }
    }

    func deleteDay(_ day: WorkoutSplitDay) {
        let ordered = sortedDays
        guard let deletedIndex = ordered.firstIndex(of: day) else { return }

        days.removeAll { $0 == day }

        let reordered = sortedDays
        for (newIndex, splitDay) in reordered.enumerated() {
            splitDay.index = newIndex
        }

        if rotationCurrentIndex > deletedIndex {
            rotationCurrentIndex -= 1
        }

        if rotationCurrentIndex >= reordered.count {
            rotationCurrentIndex = max(0, reordered.count - 1)
        }
    }
    
    var todaysDayIndex: Int? {
        dayIndex(for: .now)
    }
    
    var todaysSplitDay: WorkoutSplitDay? {
        splitDay(for: .now)
    }
    
    var todaysWorkoutPlan: WorkoutPlan? {
        workoutPlan(for: .now)
    }

    func dayIndex(for date: Date, calendar: Calendar = .current) -> Int? {
        switch mode {
        case .weekly:
            let weekday = calendar.component(.weekday, from: date)
            let adjusted = weekday + normalizedWeeklyOffset
            let wrapped = ((adjusted - 1) % 7 + 7) % 7 + 1
            return wrapped
        case .rotation:
            let count = sortedDays.count
            guard count > 0 else { return nil }
            let baseDate = rotationLastUpdatedDate ?? date
            let startBase = calendar.startOfDay(for: baseDate)
            let startTarget = calendar.startOfDay(for: date)
            let delta = calendar.dateComponents([.day], from: startBase, to: startTarget).day ?? 0
            let normalized = ((rotationCurrentIndex + delta) % count + count) % count
            return normalized
        }
    }

    func splitDay(for date: Date, calendar: Calendar = .current) -> WorkoutSplitDay? {
        switch mode {
        case .weekly:
            guard let weekday = dayIndex(for: date, calendar: calendar) else { return nil }
            return days.first { $0.weekday == weekday }
        case .rotation:
            guard let position = dayIndex(for: date, calendar: calendar) else { return nil }
            let ordered = sortedDays
            guard position >= 0 && position < ordered.count else { return nil }
            return ordered[position]
        }
    }

    func workoutPlan(for date: Date, calendar: Calendar = .current) -> WorkoutPlan? {
        guard let day = splitDay(for: date, calendar: calendar), !day.isRestDay else { return nil }
        return day.workoutPlan
    }
}

extension WorkoutSplit {
    static var active: FetchDescriptor<WorkoutSplit> {
        var descriptor = FetchDescriptor(predicate: #Predicate<WorkoutSplit> { $0.isActive })
        descriptor.fetchLimit = 1
        return descriptor
    }
}

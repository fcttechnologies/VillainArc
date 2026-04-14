import Foundation
import SwiftData

@Model final class TrainingGoal {
    #Index<TrainingGoal>([\.startedOnDay])

    private static let calendar = Calendar.autoupdatingCurrent

    var startedOnDay: Date = Date()
    var endedOnDay: Date?
    var kind: TrainingGoalKind = TrainingGoalKind.generalTraining

    init(startedOnDay: Date = Date(), kind: TrainingGoalKind) {
        self.startedOnDay = Self.calendar.startOfDay(for: startedOnDay)
        self.kind = kind
    }
}

extension TrainingGoal {
    static var history: FetchDescriptor<TrainingGoal> {
        FetchDescriptor(sortBy: [SortDescriptor(\.startedOnDay, order: .reverse)])
    }

    static var active: FetchDescriptor<TrainingGoal> {
        let predicate = #Predicate<TrainingGoal> { $0.endedOnDay == nil }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.startedOnDay, order: .reverse)])
        descriptor.fetchLimit = 1
        return descriptor
    }

    static func forDay(_ day: Date) -> FetchDescriptor<TrainingGoal> {
        let normalizedDay = Calendar.autoupdatingCurrent.startOfDay(for: day)
        let predicate = #Predicate<TrainingGoal> {
            $0.startedOnDay <= normalizedDay && ($0.endedOnDay == nil || normalizedDay <= ($0.endedOnDay ?? normalizedDay))
        }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.startedOnDay, order: .reverse)])
        descriptor.fetchLimit = 1
        return descriptor
    }

    func contains(day: Date) -> Bool {
        let normalizedDay = Self.calendar.startOfDay(for: day)
        guard normalizedDay >= startedOnDay else { return false }
        guard let endedOnDay else { return true }
        return normalizedDay <= endedOnDay
    }

    @discardableResult
    static func replaceActiveGoal(with kind: TrainingGoalKind, on day: Date = .now, context: ModelContext) throws -> Bool {
        let calendar = Calendar.autoupdatingCurrent
        let normalizedDay = calendar.startOfDay(for: day)
        let activeGoal = try context.fetch(active).first

        if activeGoal?.kind == kind {
            return false
        }

        if let activeGoal {
            if calendar.isDate(activeGoal.startedOnDay, inSameDayAs: normalizedDay) {
                context.delete(activeGoal)
            } else {
                activeGoal.endedOnDay = calendar.date(byAdding: .day, value: -1, to: normalizedDay)
            }
        }

        context.insert(TrainingGoal(startedOnDay: normalizedDay, kind: kind))
        return true
    }
}

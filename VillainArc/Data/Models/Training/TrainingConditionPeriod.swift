import Foundation
import SwiftData

@Model final class TrainingConditionPeriod {
    #Index<TrainingConditionPeriod>([\.startDate], [\.endDate])
    var kind: TrainingConditionKind = TrainingConditionKind.recovering
    var trainingImpact: TrainingImpact = TrainingImpact.contextOnly
    var startDate: Date = Date()
    var endDate: Date?
    var affectedMuscles: [Muscle]?

    init(kind: TrainingConditionKind, trainingImpact: TrainingImpact, startDate: Date = .now, endDate: Date? = nil, affectedMuscles: [Muscle]? = nil) {
        self.kind = kind
        self.trainingImpact = trainingImpact
        self.startDate = startDate
        self.endDate = endDate
        self.affectedMuscles = affectedMuscles
    }

    var sortedAffectedMuscles: [Muscle] { (affectedMuscles ?? []).sorted { $0.displayName < $1.displayName } }
    var hasAffectedMuscles: Bool { !(affectedMuscles ?? []).isEmpty }

    func contains(_ date: Date) -> Bool {
        guard date >= startDate else { return false }
        guard let endDate else { return true }
        return date < endDate
    }

    func isActive(at date: Date = .now) -> Bool { contains(date) }
}

extension TrainingConditionPeriod {
    static var history: FetchDescriptor<TrainingConditionPeriod> { FetchDescriptor(sortBy: [SortDescriptor(\.startDate, order: .reverse)]) }

    static var activeNow: FetchDescriptor<TrainingConditionPeriod> { active(at: .now) }

    static func active(at date: Date) -> FetchDescriptor<TrainingConditionPeriod> {
        let referenceDate = date
        let predicate = #Predicate<TrainingConditionPeriod> { $0.startDate <= referenceDate && ($0.endDate == nil || referenceDate < ($0.endDate ?? referenceDate)) }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        descriptor.fetchLimit = 1
        return descriptor
    }

    static func forDate(_ date: Date) -> FetchDescriptor<TrainingConditionPeriod> { active(at: date) }

    static var latestEnded: FetchDescriptor<TrainingConditionPeriod> {
        let predicate = #Predicate<TrainingConditionPeriod> { $0.endDate != nil }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.endDate, order: .reverse)])
        descriptor.fetchLimit = 1
        return descriptor
    }
}

import Foundation
import SwiftData

enum TrainingConditionStore {
    nonisolated private static let calendar = Calendar.autoupdatingCurrent

    nonisolated static func exclusiveEndDate(forEndDay endDay: Date?) -> Date? {
        guard let endDay else { return nil }
        let startOfEndDay = calendar.startOfDay(for: endDay)
        return calendar.date(byAdding: .day, value: 1, to: startOfEndDay) ?? startOfEndDay
    }

    nonisolated static func displayedEndDay(for endDate: Date?) -> Date? {
        guard let endDate else { return nil }
        return endDate.addingTimeInterval(-1)
    }

    static func createOrReplaceActive(kind: TrainingConditionKind, trainingImpact: TrainingImpact, startDate: Date, endDay: Date?, affectedMuscles: [Muscle], context: ModelContext) throws {
        if let active = try context.fetch(TrainingConditionPeriod.active(at: startDate)).first {
            active.endDate = startDate
            if active.endDate != nil, (active.endDate ?? startDate) <= active.startDate {
                context.delete(active)
            }
        }

        let period = TrainingConditionPeriod(kind: kind, trainingImpact: trainingImpact, startDate: startDate, endDate: exclusiveEndDate(forEndDay: endDay), affectedMuscles: kind.usesAffectedMuscles ? affectedMuscles : [])
        context.insert(period)
        try context.save()
    }

    static func defaultImpact(for kind: TrainingConditionKind) -> TrainingImpact {
        switch kind {
        case .onBreak:
            return .pauseTraining
        default:
            return .contextOnly
        }
    }

    static func update(_ period: TrainingConditionPeriod, kind: TrainingConditionKind, trainingImpact: TrainingImpact, startDate: Date, endDay: Date?, affectedMuscles: [Muscle], context: ModelContext) throws {
        period.kind = kind
        period.trainingImpact = trainingImpact
        period.startDate = startDate
        period.endDate = exclusiveEndDate(forEndDay: endDay)
        period.affectedMuscles = kind.usesAffectedMuscles ? affectedMuscles : []
        try context.save()
    }

    static func endActiveCondition(_ period: TrainingConditionPeriod, on date: Date = .now, context: ModelContext) throws {
        period.endDate = date
        if (period.endDate ?? date) <= period.startDate {
            context.delete(period)
        }
        try context.save()
    }
}

import Foundation
import SwiftData
import Testing

@testable import VillainArc

struct TrainingConditionStoreTests {
    private let calendar = Calendar.autoupdatingCurrent

    @Test func exclusiveEndDateAddsADayOrPassesNilThrough() {
        #expect(TrainingConditionStore.exclusiveEndDate(forEndDay: nil) == nil)
        let endDay = calendar.startOfDay(for: .now)
        #expect(TrainingConditionStore.exclusiveEndDate(forEndDay: endDay) == calendar.date(byAdding: .day, value: 1, to: endDay))
    }

    @Test func displayedEndDaySubtractsASecondOrPassesNilThrough() {
        #expect(TrainingConditionStore.displayedEndDay(for: nil) == nil)
        let endDate = Date()
        #expect(TrainingConditionStore.displayedEndDay(for: endDate) == endDate.addingTimeInterval(-1))
    }

    @Test func defaultImpactPausesForBreakOtherwiseContextOnly() {
        #expect(TrainingConditionStore.defaultImpact(for: .onBreak) == .pauseTraining)
        #expect(TrainingConditionStore.defaultImpact(for: .sick) == .contextOnly)
        #expect(TrainingConditionStore.defaultImpact(for: .injured) == .contextOnly)
    }

    @Test func createActiveKeepsMusclesForMuscleKinds() throws {
        let context = try TestDataFactory.makeContext()
        try TrainingConditionStore.createOrReplaceActive(kind: .injured, trainingImpact: .trainModified, startDate: .now, endDay: nil, affectedMuscles: [.chest], context: context)
        let active = try context.fetch(TrainingConditionPeriod.active(at: .now)).first
        #expect(active?.kind == .injured)
        #expect(active?.affectedMuscles == [.chest])
    }

    @Test func createActiveDropsMusclesForNonMuscleKinds() throws {
        let context = try TestDataFactory.makeContext()
        try TrainingConditionStore.createOrReplaceActive(kind: .sick, trainingImpact: .contextOnly, startDate: .now, endDay: nil, affectedMuscles: [.chest], context: context)
        let active = try context.fetch(TrainingConditionPeriod.active(at: .now)).first
        #expect(active?.kind == .sick)
        #expect(active?.affectedMuscles?.isEmpty == true)
    }

    @Test func updateMutatesFieldsAndGatesMuscles() throws {
        let context = try TestDataFactory.makeContext()
        let period = TrainingConditionPeriod(kind: .injured, trainingImpact: .trainModified, startDate: .now, endDate: nil, affectedMuscles: [.chest])
        context.insert(period)

        try TrainingConditionStore.update(period, kind: .sick, trainingImpact: .contextOnly, startDate: .now, endDay: nil, affectedMuscles: [.back], context: context)
        #expect(period.kind == .sick)
        #expect(period.trainingImpact == .contextOnly)
        #expect(period.affectedMuscles?.isEmpty == true)
    }

    @Test func endActiveConditionDeletesWhenEndedSameDayAsStart() throws {
        let context = try TestDataFactory.makeContext()
        let start = Date()
        let period = TrainingConditionPeriod(kind: .onBreak, trainingImpact: .pauseTraining, startDate: start, endDate: nil)
        context.insert(period)

        try TrainingConditionStore.endActiveCondition(period, on: start, context: context)
        let count = try context.fetch(TrainingConditionPeriod.active(at: start)).count
        #expect(count == 0)
    }

    @Test func endActiveConditionSetsEndDateWhenEndedLater() throws {
        let context = try TestDataFactory.makeContext()
        let start = calendar.date(byAdding: .day, value: -5, to: .now)!
        let period = TrainingConditionPeriod(kind: .onBreak, trainingImpact: .pauseTraining, startDate: start, endDate: nil)
        context.insert(period)

        try TrainingConditionStore.endActiveCondition(period, on: .now, context: context)
        #expect(period.endDate != nil)
    }
}

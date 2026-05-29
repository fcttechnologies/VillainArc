import Foundation
import SwiftData
import Testing

@testable import VillainArc

@MainActor
struct SplitScheduleResolverTests {
    private func makeResolution(
        impact: TrainingImpact?,
        isRestDay: Bool = false,
        hasPlan: Bool = false,
        conditionEndDate: Date? = nil,
        context: ModelContext
    ) -> SplitScheduleResolution {
        let split = WorkoutSplit(title: "Test", mode: .weekly)
        context.insert(split)
        let day = WorkoutSplitDay(index: 0, split: split, isRestDay: isRestDay)
        context.insert(day)
        if hasPlan {
            let plan = WorkoutPlan.makeForTests()
            context.insert(plan)
            day.workoutPlan = plan
        }
        var condition: TrainingConditionPeriod?
        if let impact {
            let made = TrainingConditionPeriod(kind: .sick, trainingImpact: impact, startDate: .now, endDate: conditionEndDate)
            context.insert(made)
            condition = made
        }
        return SplitScheduleResolution(split: split, date: .now, splitDay: day, activeCondition: condition, effectiveDate: .now)
    }

    @Test func impactFlagsReflectTrainingImpact() throws {
        let context = try TestDataFactory.makeContext()
        #expect(makeResolution(impact: .pauseTraining, context: context).isPaused == true)
        #expect(makeResolution(impact: .trainModified, context: context).isModified == true)
        #expect(makeResolution(impact: .contextOnly, context: context).isContextOnly == true)

        let none = makeResolution(impact: nil, context: context)
        #expect(none.isPaused == false)
        #expect(none.isModified == false)
        #expect(none.isContextOnly == false)
        #expect(none.conditionStatusText == nil)
        #expect(none.contextNoteText == nil)
    }

    @Test func restDayIsGatedByPause() throws {
        let context = try TestDataFactory.makeContext()
        #expect(makeResolution(impact: nil, isRestDay: true, context: context).isRestDay == true)
        #expect(makeResolution(impact: .pauseTraining, isRestDay: true, context: context).isRestDay == false)
    }

    @Test func workoutPlanIsGatedByPauseAndRest() throws {
        let context = try TestDataFactory.makeContext()
        #expect(makeResolution(impact: nil, isRestDay: false, hasPlan: true, context: context).workoutPlan != nil)
        #expect(makeResolution(impact: .pauseTraining, isRestDay: false, hasPlan: true, context: context).workoutPlan == nil)
        #expect(makeResolution(impact: nil, isRestDay: true, hasPlan: true, context: context).workoutPlan == nil)
    }

    @Test func contextNoteTextVariesByImpact() throws {
        let context = try TestDataFactory.makeContext()
        #expect(makeResolution(impact: .contextOnly, context: context).contextNoteText?.contains(TrainingConditionKind.sick.title) == true)
        #expect(makeResolution(impact: .trainModified, context: context).contextNoteText?.contains(TrainingConditionKind.sick.title) == true)
        #expect(makeResolution(impact: .pauseTraining, context: context).contextNoteText == nil)
    }

    @Test func conditionStatusTextSaysUntilChangedWithoutEndDate() throws {
        let context = try TestDataFactory.makeContext()
        let resolution = makeResolution(impact: .contextOnly, context: context)
        #expect(resolution.conditionStatusText?.contains("Until changed") == true)
    }
}

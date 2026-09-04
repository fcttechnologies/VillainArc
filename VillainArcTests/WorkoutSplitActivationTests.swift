import Foundation
import SwiftData
import Testing

@testable import VillainArc

/// Activation is exclusive, and the whole day-resolution path assumes it: `WorkoutSplit.active`
/// fetches with a limit of one, so a second split left active makes today's workout depend on
/// SwiftData's row order. The splits list, the split screen, and `ActivateWorkoutSplitIntent` all
/// go through `WorkoutSplitActivation`, so this is where that invariant is answered for.
@MainActor
struct WorkoutSplitActivationTests {
    private func makeSplits(context: ModelContext, modes: [SplitMode]) -> [WorkoutSplit] {
        modes.enumerated().map { index, mode in
            let split = WorkoutSplit(title: "Split \(index)", mode: mode)
            context.insert(split)
            return split
        }
    }

    @Test func activatingOneSplitDeactivatesEveryOther() throws {
        let context = try TestDataFactory.makeContext()
        let splits = makeSplits(context: context, modes: [.weekly, .weekly, .weekly])
        splits[0].isActive = true

        WorkoutSplitActivation.activate(splits[2], among: splits, context: context)

        #expect(splits.filter(\.isActive).map(\.title) == ["Split 2"])
        #expect(try context.fetch(WorkoutSplit.active).map(\.title) == ["Split 2"])
    }

    /// A rotation carries a position, and a split activated months after it was last used would
    /// otherwise resume mid-cycle on a date it never ran.
    @Test func activatingARotationRestartsItAtTodaysFirstDay() throws {
        let context = try TestDataFactory.makeContext()
        let splits = makeSplits(context: context, modes: [.rotation])
        let rotation = splits[0]
        rotation.rotationCurrentIndex = 3
        rotation.rotationLastUpdatedDate = Date(timeIntervalSince1970: 0)

        WorkoutSplitActivation.activate(rotation, among: splits, context: context)

        #expect(rotation.rotationCurrentIndex == 0)
        #expect(rotation.rotationLastUpdatedDate == Calendar.current.startOfDay(for: .now))
    }

    /// A weekly split's own offset is the user's place in the week, not a rotation position, so
    /// activation leaves it alone.
    @Test func activatingAWeeklySplitKeepsItsOffset() throws {
        let context = try TestDataFactory.makeContext()
        let splits = makeSplits(context: context, modes: [.weekly])
        splits[0].weeklySplitOffset = -2

        WorkoutSplitActivation.activate(splits[0], among: splits, context: context)

        #expect(splits[0].weeklySplitOffset == -2)
        #expect(splits[0].isActive)
    }
}

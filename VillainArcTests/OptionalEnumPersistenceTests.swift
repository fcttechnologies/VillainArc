import Foundation
import SwiftData
import Testing

@testable import VillainArc

/// Optional enum attributes, proven to survive a real store round trip.
///
/// A value that is set, saved, and then read back from a store opened fresh is the only proof that
/// persistence happened: the in-memory object graph answers from its own snapshot and agrees with
/// itself whether or not anything reached the file.
@MainActor
struct OptionalEnumPersistenceTests {
    /// Opens a fresh on-disk store, runs `write`, closes it, reopens the same file in a brand-new
    /// container, and hands `read` what actually persisted. A new container is the point: it is a
    /// relaunch, with no cached row anywhere to answer from.
    private func acrossARelaunch<T: PersistentModel>(
        write: (ModelContext) throws -> Void,
        read: (T) throws -> Void
    ) throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("VillainArcTests-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }
        let configuration = ModelConfiguration(nil, schema: SharedModelContainer.schema, url: url, allowsSave: true, cloudKitDatabase: .none)

        let writeContainer = try ModelContainer(for: SharedModelContainer.schema, configurations: [configuration])
        try write(writeContainer.mainContext)
        try writeContainer.mainContext.save()

        let readContainer = try ModelContainer(for: SharedModelContainer.schema, configurations: [configuration])
        let stored = try #require(try readContainer.mainContext.fetch(FetchDescriptor<T>()).first)
        try read(stored)
    }

    @Test func userProfileFitnessLevelSurvivesARelaunch() throws {
        let setAt = Date(timeIntervalSince1970: 1_772_000_000)
        try acrossARelaunch { context in
            let profile = UserProfile()
            profile.name = "Fernando"
            profile.fitnessLevel = .advanced
            profile.fitnessLevelSetAt = setAt
            context.insert(profile)
        } read: { (profile: UserProfile) in
            #expect(profile.fitnessLevel == .advanced)
            #expect(profile.fitnessLevelSetAt == setAt)
        }
    }

    @Test func weightGoalEndReasonSurvivesARelaunch() throws {
        try acrossARelaunch { context in
            let goal = WeightGoal(type: .cut, startWeight: 90, targetWeight: 80)
            goal.endReason = .achieved
            context.insert(goal)
        } read: { (goal: WeightGoal) in
            #expect(goal.endReason == .achieved)
        }
    }

    @Test func suggestionEventEnumsSurviveARelaunch() throws {
        try acrossARelaunch { context in
            let event = SuggestionEvent()
            event.ruleID = .immediateProgressionRange
            event.decisionReason = .tooAggressive
            event.userFeedback = .tooEasy
            context.insert(event)
        } read: { (event: SuggestionEvent) in
            #expect(event.ruleID == .immediateProgressionRange)
            #expect(event.decisionReason == .tooAggressive)
            #expect(event.userFeedback == .tooEasy)
        }
    }
}

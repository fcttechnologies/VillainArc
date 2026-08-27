import Foundation
import SwiftData

@testable import VillainArc

enum TestModelContainer {
    @MainActor static func make() throws -> ModelContainer {
        let storeURL = FileManager.default.temporaryDirectory.appendingPathComponent("VillainArcTests-\(UUID().uuidString).store")
        let configuration = ModelConfiguration(nil, schema: SharedModelContainer.schema, url: storeURL, allowsSave: true, cloudKitDatabase: .none)
        return try ModelContainer(for: SharedModelContainer.schema, configurations: [configuration])
    }
}

extension WorkoutPlan { static func makeForTests(title: String = "Test Plan") -> WorkoutPlan { WorkoutPlan(title: title) } }

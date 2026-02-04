import SwiftData
@testable import VillainArc

enum TestModelContainer {
    @MainActor
    static func make() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: SharedModelContainer.schema,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(
            for: SharedModelContainer.schema,
            configurations: [configuration]
        )
    }
}

extension WorkoutPlan {
    static func makeForTests(title: String = "Test Plan") -> WorkoutPlan {
        let plan = WorkoutPlan()
        plan.title = title
        return plan
    }
}

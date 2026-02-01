import AppIntents
import CoreTransferable
import SwiftData

struct WorkoutPlanEntity: AppEntity, IndexedEntity, Identifiable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Workout Plan")
    static let defaultQuery = WorkoutPlanEntityQuery()

    let id: UUID
    let title: String
    let summary: String
    let exerciseNames: [String]

    var displayRepresentation: DisplayRepresentation {
        if summary.isEmpty {
            return DisplayRepresentation(title: "\(title)")
        }
        return DisplayRepresentation(title: "\(title)", subtitle: "\(summary)")
    }

}

extension WorkoutPlanEntity {
    init(workoutPlan: WorkoutPlan) {
        id = workoutPlan.id
        title = workoutPlan.title
        summary = workoutPlan.spotlightSummary
        exerciseNames = workoutPlan.currentVersion?.sortedExercises.map(\.name) ?? []
    }
}

extension WorkoutPlanEntity: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation { entity in
            "\(entity.title)\n\(entity.summary)"
        }
    }
}

struct WorkoutPlanEntityQuery: EntityQuery, EntityStringQuery {
    @MainActor
    func entities(for identifiers: [WorkoutPlanEntity.ID]) async throws -> [WorkoutPlanEntity] {
        guard !identifiers.isEmpty else { return [] }
        let context = SharedModelContainer.container.mainContext
        let ids = identifiers
        let predicate = #Predicate<WorkoutPlan> { ids.contains($0.id) }
        let descriptor = FetchDescriptor(predicate: predicate)
        return try context.fetch(descriptor).map(WorkoutPlanEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [WorkoutPlanEntity] {
        let context = SharedModelContainer.container.mainContext
        let templates = (try? context.fetch(WorkoutPlan.all)) ?? []
        return templates.map(WorkoutPlanEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [WorkoutPlanEntity] {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let context = SharedModelContainer.container.mainContext
        let descriptor: FetchDescriptor<WorkoutPlan>
        if trimmed.isEmpty {
            descriptor = WorkoutPlan.all
        } else {
            let predicate = #Predicate<WorkoutPlan> {
                $0.completed && $0.title.localizedStandardContains(trimmed)
            }
            descriptor = FetchDescriptor(predicate: predicate, sortBy: WorkoutPlan.recentsSort)
        }
        return try context.fetch(descriptor).map(WorkoutPlanEntity.init)
    }
}

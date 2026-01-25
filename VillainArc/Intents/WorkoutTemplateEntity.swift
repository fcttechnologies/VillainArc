import AppIntents
import SwiftData

struct WorkoutTemplateEntity: AppEntity, Identifiable {
    nonisolated static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Workout Template")
    nonisolated static let defaultQuery = WorkoutTemplateEntityQuery()

    nonisolated let id: UUID
    nonisolated let name: String
    nonisolated let muscles: String

    nonisolated var displayRepresentation: DisplayRepresentation {
        if muscles.isEmpty {
            return DisplayRepresentation(title: "\(name)")
        }
        return DisplayRepresentation(title: "\(name)", subtitle: "\(muscles)")
    }
}

extension WorkoutTemplateEntity {
    init(template: WorkoutTemplate) {
        id = template.id
        name = template.name
        muscles = template.musclesTargeted()
    }
}

struct WorkoutTemplateEntityQuery: EntityQuery, EntityStringQuery {
    @MainActor
    func entities(for identifiers: [WorkoutTemplateEntity.ID]) async throws -> [WorkoutTemplateEntity] {
        guard !identifiers.isEmpty else { return [] }
        let context = SharedModelContainer.container.mainContext
        let templates = (try? context.fetch(FetchDescriptor<WorkoutTemplate>())) ?? []
        let idSet = Set(identifiers)
        return templates.filter { idSet.contains($0.id) }.map(WorkoutTemplateEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [WorkoutTemplateEntity] {
        let context = SharedModelContainer.container.mainContext
        var descriptor = FetchDescriptor(predicate: WorkoutTemplate.completedPredicate, sortBy: WorkoutTemplate.recentsSort)
        descriptor.fetchLimit = 6
        let templates = (try? context.fetch(descriptor)) ?? []
        return templates.map(WorkoutTemplateEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [WorkoutTemplateEntity] {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let context = SharedModelContainer.container.mainContext
        let descriptor = FetchDescriptor(predicate: WorkoutTemplate.completedPredicate, sortBy: WorkoutTemplate.recentsSort)
        let templates = (try? context.fetch(descriptor)) ?? []
        let filtered = trimmed.isEmpty
            ? templates
            : templates.filter { $0.name.localizedStandardContains(trimmed) }
        return filtered.map(WorkoutTemplateEntity.init)
    }
}

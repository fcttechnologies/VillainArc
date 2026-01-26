import AppIntents
import CoreSpotlight
import SwiftData

struct WorkoutTemplateEntity: AppEntity, IndexedEntity, Identifiable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Workout Template")
    static let defaultQuery = WorkoutTemplateEntityQuery()

    let id: UUID
    let name: String
    let summary: String
    let exerciseNames: [String]

    var displayRepresentation: DisplayRepresentation {
        if summary.isEmpty {
            return DisplayRepresentation(title: "\(name)")
        }
        return DisplayRepresentation(title: "\(name)", subtitle: "\(summary)")
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet()
        attributes.title = name
        attributes.displayName = name
        attributes.contentDescription = summary
        attributes.keywords = [name] + exerciseNames + ["Template"]
        return attributes
    }
}

extension WorkoutTemplateEntity {
    init(template: WorkoutTemplate) {
        id = template.id
        name = template.name
        summary = template.spotlightSummary
        exerciseNames = template.sortedExercises.map(\.name)
    }
}

struct WorkoutTemplateEntityQuery: EntityQuery, EntityStringQuery {
    @MainActor
    func entities(for identifiers: [WorkoutTemplateEntity.ID]) async throws -> [WorkoutTemplateEntity] {
        guard !identifiers.isEmpty else { return [] }
        let context = SharedModelContainer.container.mainContext
        let ids = identifiers
        let predicate = #Predicate<WorkoutTemplate> { ids.contains($0.id) }
        let descriptor = FetchDescriptor(predicate: predicate)
        return try context.fetch(descriptor).map(WorkoutTemplateEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [WorkoutTemplateEntity] {
        let context = SharedModelContainer.container.mainContext
        let templates = (try? context.fetch(WorkoutTemplate.all)) ?? []
        return templates.map(WorkoutTemplateEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [WorkoutTemplateEntity] {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let context = SharedModelContainer.container.mainContext
        let descriptor: FetchDescriptor<WorkoutTemplate>
        if trimmed.isEmpty {
            descriptor = WorkoutTemplate.all
        } else {
            let predicate = #Predicate<WorkoutTemplate> {
                $0.complete && $0.name.localizedStandardContains(trimmed)
            }
            descriptor = FetchDescriptor(predicate: predicate, sortBy: WorkoutTemplate.recentsSort)
        }
        return try context.fetch(descriptor).map(WorkoutTemplateEntity.init)
    }
}

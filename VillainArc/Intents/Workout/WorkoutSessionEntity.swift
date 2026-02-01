import AppIntents
import CoreTransferable
import SwiftData

struct WorkoutSessionEntity: AppEntity, IndexedEntity, Identifiable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Workout")
    static let defaultQuery = WorkoutSessionEntityQuery()

    let id: UUID
    let title: String
    let summary: String
    let exerciseNames: [String]
    let startedAt: Date

    var displayRepresentation: DisplayRepresentation {
        let subtitle = summary.isEmpty ? startedAt.formatted(date: .abbreviated, time: .omitted) : summary
        return DisplayRepresentation(title: "\(title)", subtitle: "\(subtitle)")
    }

}

extension WorkoutSessionEntity {
    init(workoutSession: WorkoutSession) {
        id = workoutSession.id
        title = workoutSession.title
        summary = workoutSession.spotlightSummary
        exerciseNames = workoutSession.sortedExercises.map(\.name)
        startedAt = workoutSession.startedAt
    }
}

extension WorkoutSessionEntity: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation { entity in
            "\(entity.title) — \(entity.startedAt.formatted(date: .abbreviated, time: .omitted))\n\(entity.summary)"
        }
    }
}

struct WorkoutSessionEntityQuery: EntityQuery, EntityStringQuery {
    @MainActor
    func entities(for identifiers: [WorkoutSessionEntity.ID]) async throws -> [WorkoutSessionEntity] {
        guard !identifiers.isEmpty else { return [] }
        let context = SharedModelContainer.container.mainContext
        let ids = identifiers
        let predicate = #Predicate<WorkoutSession> { ids.contains($0.id) && $0.completed }
        let descriptor = FetchDescriptor(predicate: predicate)
        let sessions = (try? context.fetch(descriptor)) ?? []
        let byID = Dictionary(sessions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return ids.compactMap { byID[$0] }.map(WorkoutSessionEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [WorkoutSessionEntity] {
        let context = SharedModelContainer.container.mainContext
        var descriptor = WorkoutSession.completedSessions(limit: 30)
        descriptor.sortBy = [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)]
        let sessions = (try? context.fetch(descriptor)) ?? []
        return sessions.map(WorkoutSessionEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [WorkoutSessionEntity] {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let context = SharedModelContainer.container.mainContext
        let descriptor: FetchDescriptor<WorkoutSession>
        if trimmed.isEmpty {
            var base = WorkoutSession.completedSessions(limit: 30)
            base.sortBy = [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)]
            descriptor = base
        } else {
            let predicate = #Predicate<WorkoutSession> {
                $0.completed && $0.title.localizedStandardContains(trimmed)
            }
            descriptor = FetchDescriptor(
                predicate: predicate,
                sortBy: [
                    SortDescriptor(\WorkoutSession.startedAt, order: .reverse),
                    SortDescriptor(\WorkoutSession.title)
                ]
            )
        }
        let sessions = (try? context.fetch(descriptor)) ?? []
        return sessions.map(WorkoutSessionEntity.init)
    }
}

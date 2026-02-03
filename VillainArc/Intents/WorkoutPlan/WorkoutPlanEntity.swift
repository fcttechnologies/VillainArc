import AppIntents
import CoreTransferable
import SwiftData
import UniformTypeIdentifiers

struct WorkoutPlanFullContent: Codable {
    struct Exercise: Codable {
        struct SetEntry: Codable {
            let index: Int
            let type: String
            let targetReps: Int
            let targetWeight: Double
            let targetRestSeconds: Int
        }

        let index: Int
        let name: String
        let notes: String?
        let muscles: [String]
        let sets: [SetEntry]
    }

    let id: UUID
    let title: String
    let summary: String
    let notes: String?
    let exercises: [Exercise]
}

struct WorkoutPlanEntity: AppEntity, IndexedEntity, Identifiable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Workout Plan")
    static let defaultQuery = WorkoutPlanEntityQuery()

    let id: UUID
    let title: String
    let summary: String
    let exerciseNames: [String]
    let fullContent: WorkoutPlanFullContent

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
        let exercises = workoutPlan.sortedExercises
        exerciseNames = exercises.map(\.name)
        fullContent = WorkoutPlanFullContent(
            id: workoutPlan.id,
            title: workoutPlan.title,
            summary: workoutPlan.spotlightSummary,
            notes: workoutPlan.notes.isEmpty ? nil : workoutPlan.notes,
            exercises: exercises.map { exercise in
                WorkoutPlanFullContent.Exercise(
                    index: exercise.index,
                    name: exercise.name,
                    notes: exercise.notes.isEmpty ? nil : exercise.notes,
                    muscles: exercise.musclesTargeted.map(\.rawValue),
                    sets: exercise.sortedSets.map { set in
                        WorkoutPlanFullContent.Exercise.SetEntry(
                            index: set.index,
                            type: set.type.rawValue,
                            targetReps: set.targetReps,
                            targetWeight: set.targetWeight,
                            targetRestSeconds: set.targetRest
                        )
                    }
                )
            }
        )
    }
}

extension WorkoutPlanEntity: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { entity in
            try await MainActor.run {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                return try encoder.encode(entity.fullContent)
            }
        }

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

import AppIntents
import CoreTransferable
import SwiftData
import UniformTypeIdentifiers

struct WorkoutSessionFullContent: Codable {
    struct PreWorkoutMood: Codable {
        let feeling: String
        let notes: String?
    }

    struct PostWorkoutEffort: Codable {
        let rpe: Int
        let notes: String?
    }

    struct Exercise: Codable {
        struct SetEntry: Codable {
            let index: Int
            let type: String
            let reps: Int
            let weight: Double
            let restSeconds: Int
            let complete: Bool
            let completedAt: Date?
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
    let startedAt: Date
    let endedAt: Date?
    let origin: String
    let preWorkoutMood: PreWorkoutMood?
    let postWorkoutEffort: PostWorkoutEffort?
    let exercises: [Exercise]
}

struct WorkoutSessionEntity: AppEntity, IndexedEntity, Identifiable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Workout")
    static let defaultQuery = WorkoutSessionEntityQuery()

    let id: UUID
    let title: String
    let summary: String
    let exerciseNames: [String]
    let startedAt: Date
    let fullContent: WorkoutSessionFullContent

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
        startedAt = workoutSession.startedAt
        let exercises = workoutSession.sortedExercises
        exerciseNames = exercises.map(\.name)
        let preMood = workoutSession.preMood.map { mood in
            WorkoutSessionFullContent.PreWorkoutMood(
                feeling: mood.feeling.rawValue,
                notes: mood.notes.isEmpty ? nil : mood.notes
            )
        }
        let postEffort = workoutSession.postEffort.map { effort in
            WorkoutSessionFullContent.PostWorkoutEffort(
                rpe: effort.rpe,
                notes: effort.notes?.isEmpty == false ? effort.notes : nil
            )
        }
        fullContent = WorkoutSessionFullContent(
            id: workoutSession.id,
            title: workoutSession.title,
            summary: workoutSession.spotlightSummary,
            notes: workoutSession.notes.isEmpty ? nil : workoutSession.notes,
            startedAt: workoutSession.startedAt,
            endedAt: workoutSession.endedAt,
            origin: workoutSession.origin.rawValue,
            preWorkoutMood: preMood,
            postWorkoutEffort: postEffort,
            exercises: exercises.map { exercise in
                WorkoutSessionFullContent.Exercise(
                    index: exercise.index,
                    name: exercise.name,
                    notes: exercise.notes.isEmpty ? nil : exercise.notes,
                    muscles: exercise.musclesTargeted.map(\.rawValue),
                    sets: exercise.sortedSets.map { set in
                        WorkoutSessionFullContent.Exercise.SetEntry(
                            index: set.index,
                            type: set.type.rawValue,
                            reps: set.reps,
                            weight: set.weight,
                            restSeconds: set.restSeconds,
                            complete: set.complete,
                            completedAt: set.completedAt
                        )
                    }
                )
            }
        )
    }
}

extension WorkoutSessionEntity: Transferable {
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
        let predicate = #Predicate<WorkoutSession> { ids.contains($0.id) }
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
            let done = SessionStatus.done
            let predicate = #Predicate<WorkoutSession> {
                $0.status == done && $0.title.localizedStandardContains(trimmed)
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

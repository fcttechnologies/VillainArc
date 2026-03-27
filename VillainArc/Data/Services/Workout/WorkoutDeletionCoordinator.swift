import Foundation
import SwiftData

@MainActor enum WorkoutDeletionCoordinator {
    static func deleteCompletedWorkouts(_ workouts: [WorkoutSession], context: ModelContext, settings: AppSettings? = nil, save: Bool = true) {
        guard !workouts.isEmpty else { return }

        let shouldRetainSnapshots = settings?.retainPerformancesForLearning ?? currentRetentionSetting(context: context)
        let affectedCatalogIDs = Set(workouts.flatMap { ($0.exercises ?? []).map(\.catalogID) })

        SpotlightIndexer.deleteWorkoutSessions(ids: workouts.map(\.id))

        if shouldRetainSnapshots {
            for workout in workouts { workout.isHidden = true }
        } else {
            for workout in workouts {
                deleteSuggestionLearningArtifactsLinked(to: workout, context: context)
                context.delete(workout)
            }
        }

        ExerciseHistoryUpdater.updateHistoriesForDeletedCatalogIDs(affectedCatalogIDs, context: context, save: save)
    }

    static func applyRetentionSetting(context: ModelContext, settings: AppSettings? = nil) {
        let shouldRetainSnapshots = settings?.retainPerformancesForLearning ?? currentRetentionSetting(context: context)
        guard !shouldRetainSnapshots else { return }

        do {
            let hiddenWorkouts = try context.fetch(WorkoutSession.hiddenSessions)
            guard !hiddenWorkouts.isEmpty else { return }

            deleteCompletedWorkouts(hiddenWorkouts, context: context, settings: settings)
            print("Removed \(hiddenWorkouts.count) retained hidden workouts after disabling performance snapshot retention.")
        } catch { print("Failed to apply performance snapshot retention setting: \(error)") }
    }

    private static func currentRetentionSetting(context: ModelContext) -> Bool { (try? context.fetch(AppSettings.single).first?.retainPerformancesForLearning) ?? true }

    private static func deleteSuggestionLearningArtifactsLinked(to workout: WorkoutSession, context: ModelContext) {
        let workoutID = workout.id
        var seenEventIDs = Set<UUID>()
        let sessionLinkedEvents = Array(workout.createdSuggestionEvents ?? [])
        let performanceLinkedEvents = workout.sortedExercises.flatMap { Array($0.triggeredSuggestions ?? []) }
        let linkedEvents = (sessionLinkedEvents + performanceLinkedEvents).filter { seenEventIDs.insert($0.id).inserted }
        var finalizedExternalEvents: [SuggestionEvent] = []
        let relatedEvaluations = (try? context.fetch(SuggestionEvaluation.forSourceWorkoutSession(workoutID))) ?? []

        for evaluation in relatedEvaluations {
            guard let event = evaluation.event else {
                context.delete(evaluation)
                continue
            }

            guard !seenEventIDs.contains(event.id) else { continue }

            if isFinalized(event) {
                if seenEventIDs.insert(event.id).inserted { finalizedExternalEvents.append(event) }
            } else {
                context.delete(evaluation)
            }
        }

        for event in linkedEvents + finalizedExternalEvents { context.delete(event) }
    }

    private static func isFinalized(_ event: SuggestionEvent) -> Bool { event.outcome != .pending || event.evaluatedAt != nil }
}

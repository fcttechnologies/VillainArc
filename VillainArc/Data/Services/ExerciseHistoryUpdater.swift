import Foundation
import SwiftData

/// Updates ExerciseHistory models when workout sessions complete or are deleted.
///
/// **Update Triggers:**
/// - Workout completed (WorkoutSummaryView.finishSummary)
/// - Workout deleted (affects exercises in that session)
/// - Manual rebuild (migration, data fixes)
///
/// **How It Works:**
/// - Completion path: Full recalculation from scratch, including the just-finished session
/// - Deletion path: Full recalculation from the remaining completed performances
/// - Creates history if it doesn't exist, updates it if it does
/// - Deletes history if no performances remain
/// - Keeps all cached aggregates in sync, including progression points and cumulative totals
@MainActor
struct ExerciseHistoryUpdater {
    
    /// Updates or creates ExerciseHistory for all exercises in the completed workout session.
    ///
    /// Uses batch fetching for histories, performances, and exercise rows.
    /// Each exercise gets a full recalculate so all fields are exact, including
    /// the just-finished session before it is marked `.done`.
    static func updateHistoriesForCompletedWorkout(_ session: WorkoutSession, context: ModelContext) {
        let exercises = session.exercises ?? []
        let catalogIDs = Set(exercises.map { $0.catalogID })
        let performancesByCatalogID = batchFetchPerformances(for: catalogIDs, includingSessionID: session.id, context: context)
        rebuildHistories(for: catalogIDs, using: performancesByCatalogID, context: context, save: false)
    }
    
    /// Updates histories for all exercises affected by a deleted workout session.
    /// Call this AFTER deleting the workout session from context.
    static func updateHistoriesForDeletedWorkout(_ session: WorkoutSession, context: ModelContext) {
        updateHistoriesForDeletedCatalogIDs(Set((session.exercises ?? []).map(\.catalogID)), context: context)
    }

    /// Updates histories for a set of affected catalog IDs after workout deletion.
    /// Call this AFTER the workout session(s) are deleted from context.
    static func updateHistoriesForDeletedCatalogIDs(_ catalogIDs: Set<String>, context: ModelContext, save: Bool = true) {
        let performancesByCatalogID = batchFetchCompletedPerformances(for: catalogIDs, context: context)
        rebuildHistories(for: catalogIDs, using: performancesByCatalogID, context: context, save: save)
    }
    
    /// Updates or creates ExerciseHistory for a specific exercise.
    /// Recalculates ALL statistics from scratch.
    ///
    /// **Behavior:**
    /// - If no performances exist: Deletes history (if exists)
    /// - If performances exist but no history: Creates new history
    /// - If both exist: Updates existing history
    static func updateHistory(for catalogID: String, context: ModelContext, save: Bool = true) {
        updateHistoriesForDeletedCatalogIDs(Set([catalogID]), context: context, save: save)
    }
    
    /// Fetches all ExerciseHistory records for the given catalog IDs in a single query.
    /// Returns a dictionary keyed by catalogID for O(1) lookup.
    static func batchFetchHistories(for catalogIDs: Set<String>, context: ModelContext) -> [String: ExerciseHistory] {
        guard !catalogIDs.isEmpty else { return [:] }
        let ids = Array(catalogIDs)
        let descriptor = ExerciseHistory.forCatalogIDs(ids)
        let results = (try? context.fetch(descriptor)) ?? []
        return Dictionary(uniqueKeysWithValues: results.map { ($0.catalogID, $0) })
    }

    static func batchFetchCompletedPerformances(for catalogIDs: Set<String>, context: ModelContext) -> [String: [ExercisePerformance]] {
        batchFetchPerformances(for: catalogIDs, context: context)
    }

    private static func batchFetchPerformances(for catalogIDs: Set<String>, context: ModelContext) -> [String: [ExercisePerformance]] {
        guard !catalogIDs.isEmpty else { return [:] }
        let ids = Array(catalogIDs)
        let descriptor = ExercisePerformance.matching(catalogIDs: ids)
        let performances = (try? context.fetch(descriptor)) ?? []
        return Dictionary(grouping: performances, by: \.catalogID)
    }

    private static func batchFetchPerformances(for catalogIDs: Set<String>, includingSessionID sessionID: UUID, context: ModelContext) -> [String: [ExercisePerformance]] {
        guard !catalogIDs.isEmpty else { return [:] }
        let ids = Array(catalogIDs)

        // Fetch completed non-hidden performances
        let completed = (try? context.fetch(ExercisePerformance.matching(catalogIDs: ids))) ?? []

        // Fetch current session's performances (not yet marked done)
        let current = (try? context.fetch(ExercisePerformance.forSession(sessionID, catalogIDs: ids))) ?? []

        // Merge, deduplicating by identity
        let completedIDs = Set(completed.map(\.id))
        let merged = completed + current.filter { !completedIDs.contains($0.id) }
        return Dictionary(grouping: merged, by: \.catalogID)
    }

    private static func batchFetchExercises(for catalogIDs: Set<String>, context: ModelContext) -> [String: Exercise] {
        guard !catalogIDs.isEmpty else { return [:] }
        let ids = Array(catalogIDs)
        let exercises = (try? context.fetch(Exercise.withCatalogIDs(ids))) ?? []
        return Dictionary(uniqueKeysWithValues: exercises.map { ($0.catalogID, $0) })
    }

    private static func batchFetchHistoriesForRebuild(for catalogIDs: Set<String>, context: ModelContext) -> [String: ExerciseHistory] {
        guard !catalogIDs.isEmpty else { return [:] }
        let ids = Array(catalogIDs)
        var descriptor = ExerciseHistory.forCatalogIDs(ids)
        descriptor.relationshipKeyPathsForPrefetching = [\.progressionPoints]
        let results = (try? context.fetch(descriptor)) ?? []
        return Dictionary(uniqueKeysWithValues: results.map { ($0.catalogID, $0) })
    }

    private static func rebuildHistories(for catalogIDs: Set<String>, using performancesByCatalogID: [String: [ExercisePerformance]], context: ModelContext, save: Bool) {
        guard !catalogIDs.isEmpty else {
            if save {
                saveContext(context: context)
            }
            return
        }

        var historyMap = batchFetchHistoriesForRebuild(for: catalogIDs, context: context)
        let exercisesByCatalogID = batchFetchExercises(for: catalogIDs, context: context)

        for catalogID in catalogIDs {
            let performances = performancesByCatalogID[catalogID] ?? []

            guard !performances.isEmpty else {
                if let history = historyMap[catalogID] {
                    context.delete(history)
                    print("🗑️ ExerciseHistoryUpdater: Deleted history for \(catalogID) (no performances)")
                }
                SpotlightIndexer.deleteExercise(catalogID: catalogID)
                continue
            }

            let history = historyMap[catalogID] ?? {
                let created = ExerciseHistory(catalogID: catalogID)
                context.insert(created)
                historyMap[catalogID] = created
                return created
            }()

            history.recalculate(using: performances)

            if let exercise = exercisesByCatalogID[catalogID] {
                SpotlightIndexer.index(exercise: exercise)
            }

            print("✅ ExerciseHistoryUpdater: Updated history for \(catalogID) - \(history.totalSessions) sessions")
        }

        if save {
            saveContext(context: context)
        }
    }

}

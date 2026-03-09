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
/// - Completion path: Incremental PR updates + limited fetch (last 10) for recent stats
/// - Deletion path: Full recalculation from scratch (PRs might be lost)
/// - Creates history if doesn't exist, updates if it does
/// - Deletes history if no performances remain
@MainActor
struct ExerciseHistoryUpdater {
    
    /// Updates or creates ExerciseHistory for all exercises in the completed workout session.
    ///
    /// Uses batch fetching (1 query for all histories instead of N) and a single save
    /// at the end. Each exercise gets a full recalculate so all fields are exact,
    /// including the just-finished session before it is marked `.done`.
    static func updateHistoriesForCompletedWorkout(_ session: WorkoutSession, context: ModelContext) {
        let exercises = session.exercises ?? []
        let catalogIDs = Set(exercises.map { $0.catalogID })

        // Batch fetch all histories in one query
        var historyMap = batchFetchHistories(for: catalogIDs, context: context)

        // Create any missing histories (rare — typically first time doing an exercise)
        batchCreateIfNeeded(for: catalogIDs, existingHistories: &historyMap, context: context)

        for catalogID in catalogIDs {
            guard let history = historyMap[catalogID] else { continue }

            // Full recalculate for data accuracy — include this session even before `.done`.
            let performances = (try? context.fetch(ExercisePerformance.matching(catalogID: catalogID, includingSessionID: session.id))) ?? []
            history.recalculate(using: performances)

            // Index exercise in Spotlight
            if let exercise = (try? context.fetch(Exercise.withCatalogID(catalogID)))?.first {
                SpotlightIndexer.index(exercise: exercise)
            }
        }
    }
    
    /// Updates histories for all exercises affected by a deleted workout session.
    /// Call this AFTER deleting the workout session from context.
    static func updateHistoriesForDeletedWorkout(_ session: WorkoutSession, context: ModelContext) {
        let catalogIDs = Set((session.exercises ?? []).map { $0.catalogID })
        
        // Update must happen after the session is deleted so the fetch
        // won't include the deleted performances.
        for catalogID in catalogIDs {
            updateHistory(for: catalogID, context: context, save: false)
        }
        saveContext(context: context)
    }
    
    /// Updates or creates ExerciseHistory for a specific exercise.
    /// Recalculates ALL statistics from scratch.
    ///
    /// **Behavior:**
    /// - If no performances exist: Deletes history (if exists)
    /// - If performances exist but no history: Creates new history
    /// - If both exist: Updates existing history
    static func updateHistory(for catalogID: String, context: ModelContext, save: Bool = true) {
        // Fetch all completed performances for this exercise
        let performances = (try? context.fetch(ExercisePerformance.matching(catalogID: catalogID))) ?? []
        
        // Find existing history
        let descriptor = ExerciseHistory.forCatalogID(catalogID)
        let existing = (try? context.fetch(descriptor)) ?? []
        
        if performances.isEmpty {
            // No performances left - delete history if it exists
            if let history = existing.first {
                context.delete(history)
                if save { saveContext(context: context) }
                print("🗑️ ExerciseHistoryUpdater: Deleted history for \(catalogID) (no performances)")
            }
            SpotlightIndexer.deleteExercise(catalogID: catalogID)
            return
        }

        // Performances exist - create or update history
        let history: ExerciseHistory
        if let found = existing.first {
            history = found
        } else {
            // Create new history
            history = ExerciseHistory(catalogID: catalogID)
            context.insert(history)
        }

        // Recalculate all statistics from scratch
        history.recalculate(using: performances)

        if save { saveContext(context: context) }

        // Index exercise in Spotlight now that it has confirmed history
        if let exercise = (try? context.fetch(Exercise.withCatalogID(catalogID)))?.first {
            SpotlightIndexer.index(exercise: exercise)
        }

        print("✅ ExerciseHistoryUpdater: Updated history for \(catalogID) - \(history.totalSessions) sessions")
    }
    
    /// Fetches all ExerciseHistory records for the given catalog IDs in a single query.
    /// Returns a dictionary keyed by catalogID for O(1) lookup.
    static func batchFetchHistories(for catalogIDs: Set<String>, context: ModelContext) -> [String: ExerciseHistory] {
        let ids = Array(catalogIDs)
        let descriptor = ExerciseHistory.forCatalogIDs(ids)
        let results = (try? context.fetch(descriptor)) ?? []
        return Dictionary(uniqueKeysWithValues: results.map { ($0.catalogID, $0) })
    }

    /// Creates ExerciseHistory for any catalog IDs that don't already have one.
    /// Saves once at the end instead of per-exercise.
    static func batchCreateIfNeeded(for catalogIDs: Set<String>, existingHistories: inout [String: ExerciseHistory], context: ModelContext) {
        let missing = catalogIDs.filter { existingHistories[$0] == nil }
        guard !missing.isEmpty else { return }

        for catalogID in missing {
            let history = ExerciseHistory(catalogID: catalogID)
            context.insert(history)

            // If prior performances exist, populate with historical stats
            let performances = (try? context.fetch(ExercisePerformance.matching(catalogID: catalogID))) ?? []
            if !performances.isEmpty {
                history.recalculate(using: performances)
            }

            existingHistories[catalogID] = history
        }
        saveContext(context: context)
    }

    /// Creates an ExerciseHistory for a catalogID if one doesn't already exist.
    /// Call this when an exercise is added to a workout so history is ready
    /// for PR detection and suggestion generation later.
    ///
    /// If prior performances exist, the history is populated with stats.
    /// If no performances exist, an empty history is created (all zeros)
    /// so that any new performance will correctly register as a PR.
    static func createIfNeeded(for catalogID: String, context: ModelContext) {
        let descriptor = ExerciseHistory.forCatalogID(catalogID)
        if (try? context.fetch(descriptor).first) != nil {
            return
        }
        
        let history = ExerciseHistory(catalogID: catalogID)
        context.insert(history)
        
        let performances = (try? context.fetch(ExercisePerformance.matching(catalogID: catalogID))) ?? []
        if !performances.isEmpty {
            history.recalculate(using: performances)
        }
        
        saveContext(context: context)
    }
    
    /// Fetches the ExerciseHistory for a catalogID.
    /// Returns nil if no history exists.
    static func fetchHistory(for catalogID: String, context: ModelContext) -> ExerciseHistory? {
        let descriptor = ExerciseHistory.forCatalogID(catalogID)
        return try? context.fetch(descriptor).first
    }
}

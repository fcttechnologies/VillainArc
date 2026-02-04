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
/// - Fetches ALL completed ExercisePerformance records for catalogID
/// - Recalculates ALL statistics from scratch (no incremental updates)
/// - Creates history if doesn't exist, updates if it does
/// - Deletes history if no performances remain
@MainActor
struct ExerciseHistoryUpdater {
    
    /// Updates or creates ExerciseHistory for all exercises in the completed workout session.
    /// Call this after marking a workout as complete.
    static func updateHistoriesForCompletedWorkout(_ session: WorkoutSession, context: ModelContext) {
        guard session.status == SessionStatus.done.rawValue else {
            print("⚠️ ExerciseHistoryUpdater: Session not marked as done")
            return
        }
        
        let catalogIDs = Set(session.exercises.map { $0.catalogID })
        
        for catalogID in catalogIDs {
            updateHistory(for: catalogID, context: context)
        }
    }
    
    /// Updates histories for all exercises affected by a deleted workout session.
    /// Call this BEFORE deleting the workout session from context.
    static func updateHistoriesForDeletedWorkout(_ session: WorkoutSession, context: ModelContext) {
        let catalogIDs = Set(session.exercises.map { $0.catalogID })
        
        // Note: Update must happen AFTER the session is deleted from context
        // so the fetch won't include the deleted performances
        for catalogID in catalogIDs {
            updateHistory(for: catalogID, context: context)
        }
    }
    
    /// Updates or creates ExerciseHistory for a specific exercise.
    /// Recalculates ALL statistics from scratch.
    ///
    /// **Behavior:**
    /// - If no performances exist: Deletes history (if exists)
    /// - If performances exist but no history: Creates new history
    /// - If both exist: Updates existing history
    static func updateHistory(for catalogID: String, context: ModelContext) {
        // Fetch all completed performances for this exercise
        let performances = (try? context.fetch(ExercisePerformance.matching(catalogID: catalogID))) ?? []
        
        // Find existing history
        let descriptor = ExerciseHistory.forCatalogID(catalogID)
        let existing = (try? context.fetch(descriptor)) ?? []
        
        if performances.isEmpty {
            // No performances left - delete history if it exists
            if let history = existing.first {
                context.delete(history)
                saveContext(context: context)
                print("🗑️ ExerciseHistoryUpdater: Deleted history for \(catalogID) (no performances)")
            }
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
        
        // Save
        saveContext(context: context)
        
        print("✅ ExerciseHistoryUpdater: Updated history for \(catalogID) - \(history.totalSessions) sessions")
    }
    
    /// Recalculates ALL exercise histories (useful for migration or data fixes)
    static func rebuildAllHistories(context: ModelContext) async {
        // Get all unique catalogIDs from completed performances
        let allPerformances = (try? context.fetch(ExercisePerformance.completedAll)) ?? []
        let catalogIDs = Set(allPerformances.map { $0.catalogID })
        
        print("🔄 ExerciseHistoryUpdater: Rebuilding histories for \(catalogIDs.count) exercises...")
        
        for catalogID in catalogIDs {
            updateHistory(for: catalogID, context: context)
        }
        
        print("✅ ExerciseHistoryUpdater: Rebuild complete")
    }
    
    /// Fetches or creates an ExerciseHistory for a given catalogID.
    /// If history doesn't exist, creates and calculates it on the spot.
    ///
    /// **Use Case:**
    /// - WorkoutSummaryView PR detection
    /// - Context gathering for suggestions
    /// - Any place that needs cached stats but may be first access
    ///
    /// **Returns:**
    /// - Existing history if found
    /// - Newly created history if performances exist but history doesn't
    /// - nil if no completed performances exist for this exercise
    static func fetchOrCreateHistory(for catalogID: String, context: ModelContext) -> ExerciseHistory? {
        // Try to fetch existing
        let descriptor = ExerciseHistory.forCatalogID(catalogID)
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        
        // Doesn't exist - create it
        let performances = (try? context.fetch(ExercisePerformance.matching(catalogID: catalogID))) ?? []
        
        guard !performances.isEmpty else {
            return nil  // No data to create history from
        }
        
        let history = ExerciseHistory(catalogID: catalogID)
        context.insert(history)
        history.recalculate(using: performances)
        saveContext(context: context)
        
        return history
    }
}

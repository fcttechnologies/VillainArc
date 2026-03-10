import Foundation
import SwiftData

/// Cached aggregate statistics for an exercise across all completed workout sessions.
/// 
/// **When Computed:**
/// - After a workout is marked as complete (WorkoutSummaryView -> finishSummary)
/// - When a workout session is deleted (if it affects this exercise)
/// - Manual rebuild via ExerciseHistoryUpdater.rebuildAllHistories()
///
/// **What Gets Recomputed:**
/// - ALL statistics are recalculated from scratch each time
/// - Fetches all completed ExercisePerformance records for the catalogID
/// - Ensures statistics always reflect current state of data
///
/// **Reset Conditions:**
/// - When no completed performances exist for the catalogID
/// - When history.recalculate([]) is called with empty array
/// - All stats return to zero/default values
///
/// One ExerciseHistory per unique catalogID.
@Model
final class ExerciseHistory {
    #Index<ExerciseHistory>([\.catalogID])

    var catalogID: String = ""

    // Session counts
    var totalSessions: Int = 0
    var totalCompletedSets: Int = 0
    var totalCompletedReps: Int = 0
    var cumulativeVolume: Double = 0
    var latestEstimated1RM: Double = 0
    
    // Personal Records
    var bestEstimated1RM: Double = 0
    var bestWeight: Double = 0
    var bestVolume: Double = 0
    var bestReps: Int = 0
    
    // Progression points (last 10 sessions for charting)
    @Relationship(deleteRule: .cascade, inverse: \ProgressionPoint.exerciseHistory)
    var progressionPoints: [ProgressionPoint]? = [ProgressionPoint]()
    
    var sortedProgressionPoints: [ProgressionPoint] {
        (progressionPoints ?? []).sorted { $0.date > $1.date }
    }
    
    init(catalogID: String) {
        self.catalogID = catalogID
    }
    
    /// Recalculates ALL statistics from scratch using completed exercise performances.
    /// 
    /// **Full Recomputation Strategy:**
    /// - Safer than incremental updates (avoids drift/corruption)
    /// - Ensures statistics always match actual data
    /// - Performance acceptable since this runs after workout (not during)
    /// - Typical performance: 50-200ms for 50 sessions
    ///
    /// **Called When:**
    /// - Workout completed (WorkoutSummaryView)
    /// - Workout deleted (if catalogID affected)
    /// - Manual rebuild (migration, data fix)
    @MainActor
    func recalculate(using performances: [ExercisePerformance]) {
        guard !performances.isEmpty else {
            reset()
            return
        }

        totalSessions = performances.count
        totalCompletedSets = performances.reduce(0) { $0 + $1.sortedSets.count }
        totalCompletedReps = performances.reduce(0) { $0 + $1.totalCompletedReps }
        cumulativeVolume = performances.reduce(0) { $0 + $1.totalVolume }
        latestEstimated1RM = performances.first?.bestEstimated1RM ?? 0
        
        // Calculate PRs
        calculatePRs(from: performances)

        // Store progression data for charting (last 10 sessions)
        storeProgressionData(from: performances)
    }

    /// Resets all statistics to default/zero values.
    /// 
    /// **Called When:**
    /// - recalculate([]) is called with empty performances array
    /// - All completed workouts for this exercise have been deleted
    /// - No valid data exists to calculate from
    private func reset() {
        totalSessions = 0
        totalCompletedSets = 0
        totalCompletedReps = 0
        cumulativeVolume = 0
        latestEstimated1RM = 0
        bestEstimated1RM = 0
        bestWeight = 0
        bestVolume = 0
        bestReps = 0
        progressionPoints?.removeAll()
    }
    
    private func calculatePRs(from performances: [ExercisePerformance]) {
        // Best estimated 1RM
        var best1RM: Double = 0
        for perf in performances {
            if let perf1RM = perf.bestEstimated1RM, perf1RM > best1RM {
                best1RM = perf1RM
            }
        }
        bestEstimated1RM = best1RM
        
        // Best weight
        var maxWeight: Double = 0
        for perf in performances {
            if let perfWeight = perf.bestWeight, perfWeight > maxWeight {
                maxWeight = perfWeight
            }
        }
        bestWeight = maxWeight
        
        // Best volume
        var maxVolume: Double = 0
        for perf in performances {
            let vol = perf.totalVolume
            if vol > maxVolume {
                maxVolume = vol
            }
        }
        bestVolume = maxVolume
        bestReps = performances.compactMap(\.bestReps).max() ?? 0
    }
    
    private func storeProgressionData(from performances: [ExercisePerformance]) {
        // Clear existing progression points
        progressionPoints?.removeAll()
        
        let last10 = Array(performances.prefix(10))
        
        for perf in last10 {
            let topWeight = perf.sortedSets.map(\.weight).max() ?? 0
            let point = ProgressionPoint(date: perf.date, weight: topWeight, totalReps: perf.totalCompletedReps, volume: perf.totalVolume, estimated1RM: perf.bestEstimated1RM ?? 0)
            progressionPoints?.append(point)
        }
    }
    
    // MARK: - Fetch Descriptors
    
    static func forCatalogID(_ catalogID: String) -> FetchDescriptor<ExerciseHistory> {
        let predicate = #Predicate<ExerciseHistory> { $0.catalogID == catalogID }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        return descriptor
    }

    static func forCatalogIDs(_ catalogIDs: [String]) -> FetchDescriptor<ExerciseHistory> {
        let predicate = #Predicate<ExerciseHistory> { history in
            catalogIDs.contains(history.catalogID)
        }
        return FetchDescriptor(predicate: predicate)
    }
}

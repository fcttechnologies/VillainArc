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
    #Index<ExerciseHistory>([\.catalogID], [\.lastCompletedAt])

    var catalogID: String = ""
    var lastCompletedAt: Date? = nil

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

        let sessionSummaries = summarizedSessions(from: performances)

        lastCompletedAt = sessionSummaries.first?.date
        totalSessions = sessionSummaries.count
        totalCompletedSets = sessionSummaries.reduce(0) { $0 + $1.totalCompletedSets }
        totalCompletedReps = sessionSummaries.reduce(0) { $0 + $1.totalCompletedReps }
        cumulativeVolume = sessionSummaries.reduce(0) { $0 + $1.totalVolume }
        latestEstimated1RM = sessionSummaries.first?.bestEstimated1RM ?? 0
        
        // Calculate PRs
        calculatePRs(from: sessionSummaries)

        // Store progression data for charting (last 10 sessions)
        storeProgressionData(from: sessionSummaries)
    }

    /// Resets all statistics to default/zero values.
    /// 
    /// **Called When:**
    /// - recalculate([]) is called with empty performances array
    /// - All completed workouts for this exercise have been deleted
    /// - No valid data exists to calculate from
    private func reset() {
        lastCompletedAt = nil
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
    
    private func calculatePRs(from sessions: [ExerciseHistorySessionSummary]) {
        // Best estimated 1RM
        var best1RM: Double = 0
        for session in sessions {
            if let session1RM = session.bestEstimated1RM, session1RM > best1RM {
                best1RM = session1RM
            }
        }
        bestEstimated1RM = best1RM
        
        // Best weight
        var maxWeight: Double = 0
        for session in sessions {
            if let sessionWeight = session.bestWeight, sessionWeight > maxWeight {
                maxWeight = sessionWeight
            }
        }
        bestWeight = maxWeight
        
        // Best volume
        var maxVolume: Double = 0
        for session in sessions {
            let vol = session.totalVolume
            if vol > maxVolume {
                maxVolume = vol
            }
        }
        bestVolume = maxVolume
        bestReps = sessions.compactMap(\.bestReps).max() ?? 0
    }
    
    private func storeProgressionData(from sessions: [ExerciseHistorySessionSummary]) {
        // Clear existing progression points
        progressionPoints?.removeAll()
        
        let last10 = Array(sessions.prefix(10))
        
        for session in last10 {
            let point = ProgressionPoint(date: session.date, weight: session.bestWeight ?? 0, totalReps: session.totalCompletedReps, volume: session.totalVolume, estimated1RM: session.bestEstimated1RM ?? 0)
            progressionPoints?.append(point)
        }
    }

    @MainActor
    private func summarizedSessions(from performances: [ExercisePerformance]) -> [ExerciseHistorySessionSummary] {
        let groupedBySession = Dictionary(grouping: performances) { performance in
            performance.workoutSession?.id ?? performance.id
        }

        var summaries: [ExerciseHistorySessionSummary] = []
        summaries.reserveCapacity(groupedBySession.count)

        for performances in groupedBySession.values {
            if let summary = ExerciseHistorySessionSummary(performances: performances) {
                summaries.append(summary)
            }
        }

        return summaries.sorted { left, right in
            if left.date != right.date {
                return left.date > right.date
            }
            return left.id.uuidString < right.id.uuidString
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

    static var recentsSort: [SortDescriptor<ExerciseHistory>] {
        [
            SortDescriptor(\ExerciseHistory.lastCompletedAt, order: .reverse),
            SortDescriptor(\ExerciseHistory.catalogID)
        ]
    }

    static func recentCompleted(limit: Int? = nil) -> FetchDescriptor<ExerciseHistory> {
        let predicate = #Predicate<ExerciseHistory> { $0.lastCompletedAt != nil }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: recentsSort)
        if let limit {
            descriptor.fetchLimit = limit
        }
        return descriptor
    }
}

private struct ExerciseHistorySessionSummary {
    let id: UUID
    let date: Date
    let totalCompletedSets: Int
    let totalCompletedReps: Int
    let totalVolume: Double
    let bestEstimated1RM: Double?
    let bestWeight: Double?
    let bestReps: Int?

    @MainActor
    init?(performances: [ExercisePerformance]) {
        guard let first = performances.first else { return nil }

        id = first.workoutSession?.id ?? first.id
        date = performances.map(\.date).max() ?? first.date
        totalCompletedSets = performances.reduce(0) { $0 + $1.sortedSets.count }
        totalCompletedReps = performances.reduce(0) { $0 + $1.totalCompletedReps }
        totalVolume = performances.reduce(0) { $0 + $1.totalVolume }
        bestEstimated1RM = performances.compactMap(\.bestEstimated1RM).max()
        bestWeight = performances.compactMap(\.bestWeight).max()
        bestReps = performances.compactMap(\.bestReps).max()
    }
}

struct ExerciseHistoryOrdering {
    let historyByCatalogID: [String: ExerciseHistory]

    init(histories: [ExerciseHistory]) {
        historyByCatalogID = Dictionary(uniqueKeysWithValues: histories.map { ($0.catalogID, $0) })
    }

    func history(for exercise: Exercise) -> ExerciseHistory? {
        historyByCatalogID[exercise.catalogID]
    }

    func ordered(_ exercises: [Exercise]) -> [Exercise] {
        exercises.sorted(by: isOrderedBefore)
    }

    func recentExercises(from exercises: [Exercise], orderedBy histories: [ExerciseHistory]) -> [Exercise] {
        let exerciseByCatalogID = Dictionary(uniqueKeysWithValues: exercises.map { ($0.catalogID, $0) })
        return histories.compactMap { exerciseByCatalogID[$0.catalogID] }
    }

    func isOrderedBefore(_ left: Exercise, _ right: Exercise) -> Bool {
        let leftDate = historyByCatalogID[left.catalogID]?.lastCompletedAt ?? .distantPast
        let rightDate = historyByCatalogID[right.catalogID]?.lastCompletedAt ?? .distantPast

        if leftDate != rightDate {
            return leftDate > rightDate
        }

        return left.name.localizedStandardCompare(right.name) == .orderedAscending
    }
}

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
class ExerciseHistory {
    var catalogID: String = ""
    
    // Last updated tracking
    var lastUpdated: Date = Date()
    var lastWorkoutDate: Date?
    
    // Session counts
    var totalSessions: Int = 0
    var last30DaySessions: Int = 0
    
    // Personal Records
    var bestEstimated1RM: Double = 0
    var bestEstimated1RMDate: Date?
    var bestWeight: Double = 0
    var bestWeightDate: Date?
    var bestVolume: Double = 0
    var bestVolumeDate: Date?
    
    // Best reps at specific weights (for tracking rep PRs)
    /// Format: [weight: maxReps] - e.g., [135: 12, 185: 8, 225: 3]
    var bestRepsAtWeight: [Double: Int] = [:]
    
    // Recent averages (last 3 sessions)
    var last3AvgWeight: Double = 0
    var last3AvgVolume: Double = 0
    var last3AvgSetCount: Int = 0
    var last3AvgRestSeconds: Int = 0
    
    // Typical patterns (across all history)
    var typicalSetCount: Int = 0
    var typicalRepRangeLower: Int = 0
    var typicalRepRangeUpper: Int = 0
    var typicalRestSeconds: Int = 0
    
    // Progression trend (SwiftData stores enum directly, String raw value for AI readability)
    var progressionTrend: ProgressionTrend = ProgressionTrend.insufficient
    
    // Weight progression points (last 10 sessions for charting)
    @Relationship(deleteRule: .cascade, inverse: \ProgressionPoint.exerciseHistory)
    var progressionPoints: [ProgressionPoint] = []
    
    var sortedProgressionPoints: [ProgressionPoint] {
        progressionPoints.sorted { $0.date > $1.date }
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
        
        lastUpdated = Date()
        totalSessions = performances.count
        
        // Track most recent workout date
        if let latest = performances.first {
            lastWorkoutDate = latest.date
        }
        
        // Calculate last 30 days
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        last30DaySessions = performances.filter { $0.date >= thirtyDaysAgo }.count
        
        // Calculate PRs
        calculatePRs(from: performances)
        
        // Calculate recent averages (last 3 sessions)
        calculateRecentAverages(from: performances)
        
        // Calculate typical patterns (all time)
        calculateTypicalPatterns(from: performances)
        
        // Calculate progression trend
        calculateProgressionTrend(from: performances)
        
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
        last30DaySessions = 0
        lastWorkoutDate = nil
        bestEstimated1RM = 0
        bestEstimated1RMDate = nil
        bestWeight = 0
        bestWeightDate = nil
        bestVolume = 0
        bestVolumeDate = nil
        bestRepsAtWeight = [:]
        last3AvgWeight = 0
        last3AvgVolume = 0
        last3AvgSetCount = 0
        last3AvgRestSeconds = 0
        typicalSetCount = 0
        typicalRepRangeLower = 0
        typicalRepRangeUpper = 0
        typicalRestSeconds = 0
        progressionTrend = .insufficient
        progressionPoints.removeAll()
    }
    
    private func calculatePRs(from performances: [ExercisePerformance]) {
        // Best estimated 1RM
        var best1RM: Double = 0
        var best1RMDate: Date?
        for perf in performances {
            if let perf1RM = perf.bestEstimated1RM, perf1RM > best1RM {
                best1RM = perf1RM
                best1RMDate = perf.date
            }
        }
        bestEstimated1RM = best1RM
        bestEstimated1RMDate = best1RMDate
        
        // Best weight
        var maxWeight: Double = 0
        var maxWeightDate: Date?
        for perf in performances {
            if let perfWeight = perf.bestWeight, perfWeight > maxWeight {
                maxWeight = perfWeight
                maxWeightDate = perf.date
            }
        }
        bestWeight = maxWeight
        bestWeightDate = maxWeightDate
        
        // Best volume
        var maxVolume: Double = 0
        var maxVolumeDate: Date?
        for perf in performances {
            let vol = perf.totalVolume
            if vol > maxVolume {
                maxVolume = vol
                maxVolumeDate = perf.date
            }
        }
        bestVolume = maxVolume
        bestVolumeDate = maxVolumeDate
        
        // Best reps at each weight
        var repsMap: [Double: Int] = [:]
        for perf in performances {
            for set in perf.sets where set.complete {
                let weight = set.weight
                let reps = set.reps
                if reps > (repsMap[weight] ?? 0) {
                    repsMap[weight] = reps
                }
            }
        }
        bestRepsAtWeight = repsMap
    }
    
    private func calculateRecentAverages(from performances: [ExercisePerformance]) {
        let recent = Array(performances.prefix(3))
        guard !recent.isEmpty else { return }
        
        // Average weight (top set weight per session)
        let weights = recent.compactMap { topWorkingWeight(in: $0) }
        last3AvgWeight = average(weights)
        
        // Average volume
        let volumes = recent.map { $0.totalVolume }
        last3AvgVolume = volumes.reduce(0, +) / Double(volumes.count)
        
        // Average set count
        let setCounts = recent.map { $0.sortedSets.count }
        last3AvgSetCount = setCounts.reduce(0, +) / setCounts.count
        
        // Average rest time (working sets only)
        var totalRest = 0
        var restCount = 0
        for perf in recent {
            let regularSets = perf.sortedSets.filter { $0.type == .working }
            for set in regularSets {
                totalRest += set.restSeconds
                restCount += 1
            }
        }
        last3AvgRestSeconds = restCount > 0 ? totalRest / restCount : 0
    }
    
    private func calculateTypicalPatterns(from performances: [ExercisePerformance]) {
        // Typical set count (median)
        let setCounts = performances.map { $0.sortedSets.count }
        typicalSetCount = median(of: setCounts)
        
        // Typical rep range (25th and 75th percentile of all working set reps)
        let allReps = performances.flatMap { perf in
            perf.sortedSets.filter { $0.type == .working }.map { $0.reps }
        }
        if !allReps.isEmpty {
            let sorted = allReps.sorted()
            let p25Index = Int(Double(sorted.count) * 0.25)
            let p75Index = Int(Double(sorted.count) * 0.75)
            typicalRepRangeLower = sorted[max(0, p25Index)]
            typicalRepRangeUpper = sorted[min(sorted.count - 1, p75Index)]
        }
        
        // Typical rest time (median of working sets)
        let restTimes = performances.flatMap { perf in
            perf.sortedSets.filter { $0.complete && $0.type == .working }.map { $0.restSeconds }
        }
        typicalRestSeconds = median(of: restTimes)
    }
    
    private func calculateProgressionTrend(from performances: [ExercisePerformance]) {
        guard performances.count >= 3 else {
            progressionTrend = .insufficient
            return
        }
        
        // Compare last 3 vs previous 3 sessions (if available)
        let recent3 = Array(performances.prefix(3))
        
        guard performances.count >= 6 else {
            // Not enough data for comparison, default to stable
            progressionTrend = .stable
            return
        }
        
        let previous3 = Array(performances.dropFirst(3).prefix(3))
        
        // Compare average weight
        let recentAvgWeight = averageTopWorkingWeight(in: recent3, divisor: 3.0)
        let previousAvgWeight = averageTopWorkingWeight(in: previous3, divisor: 3.0)
        
        let weightChange = recentAvgWeight - previousAvgWeight
        let changePercent = previousAvgWeight > 0 ? (weightChange / previousAvgWeight) * 100 : 0
        
        // Thresholds
        if changePercent > 2.5 {
            progressionTrend = .improving
        } else if changePercent < -2.5 {
            progressionTrend = .declining
        } else {
            progressionTrend = .stable
        }
    }
    
    private func storeProgressionData(from performances: [ExercisePerformance]) {
        // Clear existing progression points
        progressionPoints.removeAll()
        
        let last10 = Array(performances.prefix(10))
        
        for perf in last10 {
            let topWeight = perf.sortedSets.filter { $0.type == .working }
                .map { $0.weight }
                .max() ?? 0
            
            let point = ProgressionPoint(date: perf.date, weight: topWeight, volume: perf.totalVolume)
            progressionPoints.append(point)
        }
    }
    
    private func median(of values: [Int]) -> Int {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted[mid]
    }

    private func topWorkingWeight(in performance: ExercisePerformance) -> Double? {
        performance.sortedSets
            .filter { $0.type == .working }
            .map { $0.weight }
            .max()
    }

    private func average(_ values: [Double]) -> Double {
        values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }

    private func averageTopWorkingWeight(in performances: [ExercisePerformance], divisor: Double) -> Double {
        let weights = performances.compactMap { topWorkingWeight(in: $0) }
        return weights.reduce(0, +) / divisor
    }
    
    // MARK: - Fetch Descriptors
    
    static func forCatalogID(_ catalogID: String) -> FetchDescriptor<ExerciseHistory> {
        let predicate = #Predicate<ExerciseHistory> { history in
            history.catalogID == catalogID
        }
        return FetchDescriptor(predicate: predicate)
    }
}

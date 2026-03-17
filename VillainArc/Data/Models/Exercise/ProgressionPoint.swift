import Foundation
import SwiftData

/// A single data point in an exercise's weight progression history.
///
/// **Purpose:**
/// - Tracks weight, volume, total reps, and estimated 1RM for charting progression over time
/// - Stored as SwiftData model (not JSON) for proper relationships
/// - Last 10 sessions are stored per exercise
///
/// **Usage:**
/// - Automatically created/updated by ExerciseHistory.recalculate()
/// - Cascade deleted when parent ExerciseHistory is deleted
/// - Sorted by date via ExerciseHistory.chronologicalProgressionPoints
///
/// **Example:**
/// ```swift
/// let history = ExerciseHistory(catalogID: "bench-press")
/// for point in history.chronologicalProgressionPoints {
///     print("\(point.date): \(point.weight) lbs, \(point.totalReps) reps, \(point.volume) total volume, \(point.estimated1RM) est. 1RM")
/// }
/// ```
@Model
final class ProgressionPoint {
    var date: Date = Date()
    var weight: Double = 0  // Top set weight for this session
    var totalReps: Int = 0  // Total completed reps for this session
    var volume: Double = 0  // Total volume (weight × reps) for this session
    var estimated1RM: Double = 0  // Best estimated 1RM for this session
    
    // Back-reference to parent history (cascade delete)
    var exerciseHistory: ExerciseHistory?
    
    init(date: Date, weight: Double, totalReps: Int, volume: Double, estimated1RM: Double) {
        self.date = date
        self.weight = weight
        self.totalReps = totalReps
        self.volume = volume
        self.estimated1RM = estimated1RM
    }
}

import Foundation
import SwiftData

/// A single data point in an exercise's weight progression history.
///
/// **Purpose:**
/// - Tracks weight and volume for charting progression over time
/// - Stored as SwiftData model (not JSON) for proper relationships
/// - Last 10 sessions are stored per exercise
///
/// **Usage:**
/// - Automatically created/updated by ExerciseHistory.recalculate()
/// - Cascade deleted when parent ExerciseHistory is deleted
/// - Sorted by date via ExerciseHistory.sortedProgressionPoints
///
/// **Example:**
/// ```swift
/// let history = ExerciseHistory(catalogID: "bench-press")
/// for point in history.sortedProgressionPoints {
///     print("\(point.date): \(point.weight) lbs, \(point.volume) total volume")
/// }
/// ```
@Model
class ProgressionPoint {
    var date: Date = Date()
    var weight: Double = 0  // Top set weight for this session
    var volume: Double = 0  // Total volume (weight × reps) for this session
    
    // Back-reference to parent history (cascade delete)
    var exerciseHistory: ExerciseHistory?
    
    init(date: Date, weight: Double, volume: Double) {
        self.date = date
        self.weight = weight
        self.volume = volume
    }
}

import FCTMetrics
import Foundation
import SwiftData

/// Making one split the active one, from wherever it is asked for — the splits list, the split
/// screen, or `ActivateWorkoutSplitIntent`.
///
/// Activation is exclusive: a split becomes active by every other split becoming inactive in the
/// same write, and a rotation restarts at its first day so `SplitScheduleResolver` reads today
/// rather than wherever the rotation was left.
@MainActor
enum WorkoutSplitActivation {
    /// - Parameter splits: every split the activation applies across, the one being activated
    ///   included — they are what gets deactivated and what gets re-indexed.
    static func activate(_ split: WorkoutSplit, among splits: [WorkoutSplit], context: ModelContext) {
        Diag.breadcrumb(VACrumb.splitActivated)
        for item in splits where item !== split { item.isActive = false }
        split.isActive = true
        if split.mode == .rotation {
            split.rotationCurrentIndex = 0
            split.rotationLastUpdatedDate = Calendar.current.startOfDay(for: .now)
        }
        saveContext(context: context)
        SpotlightIndexer.index(workoutSplits: splits)
    }
}

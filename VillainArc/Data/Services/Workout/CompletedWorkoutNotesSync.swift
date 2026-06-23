import Foundation

/// Plan-notes drift detection for a **completed** workout.
///
/// While a workout is live, drift is detected through the live `ExercisePerformance.prescription`
/// link. `finishSummary`/`finish` call `clearPrescriptionLinksForHistoricalUse()`, which nils that
/// link on every performance, so a completed workout can't use it. The workout's `workoutPlan`
/// relationship persists (`.nullify`), so this helper looks the plan up and matches each exercise's
/// prescription by `catalogID` instead — the same comparison the live logger does, against the
/// link-free source.
enum CompletedWorkoutNotesSync {
    /// The linked plan's notes when they differ from the workout's notes; otherwise nil.
    /// Returns nil when the workout isn't plan-linked (nothing to sync against).
    static func driftedPlanNotes(for workout: WorkoutSession) -> String? {
        guard let plan = workout.workoutPlan else { return nil }
        return drifted(current: workout.notes, source: plan.notes)
    }

    /// The matching prescription's notes when they differ from this exercise's notes; otherwise nil.
    /// Matches by `catalogID` against the workout's linked plan.
    static func driftedPrescriptionNotes(for exercise: ExercisePerformance, in workout: WorkoutSession) -> String? {
        guard let plan = workout.workoutPlan else { return nil }
        guard let prescription = plan.sortedExercises.first(where: { $0.catalogID == exercise.catalogID }) else { return nil }
        return drifted(current: exercise.notes, source: prescription.notes)
    }

    /// True when the workout or any of its exercises has plan-notes drift — the cue to surface the
    /// editor entry points.
    static func hasAnyDrift(in workout: WorkoutSession) -> Bool {
        if driftedPlanNotes(for: workout) != nil { return true }
        return workout.sortedExercises.contains { driftedPrescriptionNotes(for: $0, in: workout) != nil }
    }

    /// Returns `source` when it differs from `current` (trim-insensitive), else nil. The source value
    /// is returned untrimmed so the editor shows the plan's notes exactly as authored.
    private static func drifted(current: String, source: String) -> String? {
        let normalizedCurrent = current.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedCurrent != normalizedSource else { return nil }
        return source
    }
}

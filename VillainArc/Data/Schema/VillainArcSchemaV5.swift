import Foundation
import SwiftData
import HealthKit

// V5 adds HealthHeart, HealthRespiratoryRate, HealthWristTemperature, HydrationDay, HydrationEntry,
// HydrationGoal, HealthSyncState synced-range fields for the new read types,
// AppSettings.temperatureUnit, AppSettings.previousSetReferenceSource,
// AppSettings.hydrationUnit, and AppSettings.hydrationNotificationMode.
enum VillainArcSchemaV5: VersionedSchema {
    // Public App Store schema for Villain Arc 1.3, and the current live head: this references the
    // live models. There is no separate frozen V5 snapshot or a V6 yet — only freeze V5 (copy the
    // live models into a nested snapshot) and add a real V6 with a real migration when the data model
    // actually changes.
    static let versionIdentifier = Schema.Version(5, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            WorkoutSession.self,
            HealthWorkout.self,
            WeightEntry.self,
            HealthStepsDistance.self,
            HealthEnergy.self,
            TrainingConditionPeriod.self,
            HealthSleepNight.self,
            HealthSleepBlock.self,
            HealthSyncState.self,
            WeightGoal.self,
            StepsGoal.self,
            PreWorkoutContext.self,
            ExercisePerformance.self,
            SetPerformance.self,
            Exercise.self,
            AppSettings.self,
            UserProfile.self,
            ExerciseHistory.self,
            ProgressionPoint.self,
            RepRangePolicy.self,
            RestTimeHistory.self,
            WorkoutPlan.self,
            ExercisePrescription.self,
            SetPrescription.self,
            WorkoutSplit.self,
            WorkoutSplitDay.self,
            SuggestionEvent.self,
            PrescriptionChange.self,
            SuggestionEvaluation.self,
            TrainingGoal.self,
            SleepGoal.self,
            HealthHeart.self,
            HealthRespiratoryRate.self,
            HealthWristTemperature.self,
            HydrationDay.self,
            HydrationEntry.self,
            HydrationGoal.self,
            CardioSession.self,
            CardioRoutePoint.self,
            CardioMachineInterval.self
        ]
    }
}

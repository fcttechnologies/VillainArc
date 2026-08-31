import Foundation
import SwiftData

/// The clean V1 of the platform-era store: a local-first SwiftData store in the App Group with no
/// CloudKit mirror. Cross-device continuity is the FCT platform's job (`FCTServerSync` over the
/// shared backend), never a second sync engine on the store.
///
/// The live model classes ARE the schema: editing a live `@Model` edits V1. This schema is
/// unpublished; while that holds, shape changes are made in place and dev devices rebuild from a
/// clean store. The first public release freezes it, and any later shape change then adds a real
/// V2 with a migration.
///
/// Every `@Model` in the app must be listed here — a missing one is a runtime crash class, pinned
/// by the `SchemaContract` test.
enum VillainArcSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

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
            ExercisePreference.self,
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

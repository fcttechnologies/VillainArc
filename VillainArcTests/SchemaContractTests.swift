import FCTSync
import Foundation
import SwiftData
import Testing

@testable import VillainArc

/// Schema-membership tripwires for the clean platform-era V1. There is no migration plan to test:
/// V1 is unpublished, shape changes are made in place, and the first public release is what
/// freezes it (per the schema header). What must never drift silently is the `models` array —
/// a new `@Model` missing from it is a runtime crash class, not a compile error.
struct SchemaContractTests {
    /// Update this count deliberately whenever an `@Model` is added or removed.
    @Test @MainActor
    func v1SchemaIncludesEveryActiveModel() {
        #expect(VillainArcSchemaV1.models.count == 41)
    }

    /// The by-name half of the schema-membership tripwire, via `FCTSync.SchemaContract`: pins the
    /// exact model set so a dropped/renamed model fails loudly *with its name*, not just as a
    /// count drift. Kept ALONGSIDE the count pin above, not instead of it — the count catches
    /// additions, this catches which specific model went missing.
    @Test @MainActor
    func v1SchemaContainsEveryExpectedModelByName() {
        let expected: [any PersistentModel.Type] = [
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
        #expect(expected.count == 41)
        let missing = SchemaContract.missingModelNames(in: VillainArcSchemaV1.self, requiring: expected)
        #expect(missing.isEmpty, "Models missing from VillainArcSchemaV1.models: \(missing)")
    }
}

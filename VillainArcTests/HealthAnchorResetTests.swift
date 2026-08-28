import HealthKit
import Testing

@testable import VillainArc

/// The Apple Health import anchors, as a set.
///
/// Weight, hydration and the whole `Health*` mirror family are deliberately not synced to the FCT
/// account — Apple Health is their canon, and a signed-out device gets them back by re-importing.
/// That promise rests entirely on the anchors: an anchored query resumes from its anchor and
/// returns only what changed since it, so a clear that removes the mirror rows and leaves the
/// anchors standing makes the history unreachable while every sample is still in Apple Health.
@Suite("Health import anchors", .serialized)
struct HealthAnchorResetTests {
    /// Set on every anchor, so a key missing from the reset fails here rather than in the field.
    private func setEveryAnchor(_ anchor: HKQueryAnchor?) {
        HealthSyncPreferences.workoutAnchor = anchor
        HealthSyncPreferences.weightEntryAnchor = anchor
        HealthSyncPreferences.stepCountAnchor = anchor
        HealthSyncPreferences.walkingRunningDistanceAnchor = anchor
        HealthSyncPreferences.activeEnergyBurnedAnchor = anchor
        HealthSyncPreferences.restingEnergyBurnedAnchor = anchor
        HealthSyncPreferences.sleepAnalysisAnchor = anchor
        HealthSyncPreferences.heartRateAnchor = anchor
        HealthSyncPreferences.restingHeartRateAnchor = anchor
        HealthSyncPreferences.walkingHeartRateAnchor = anchor
        HealthSyncPreferences.heartRateVariabilityAnchor = anchor
        HealthSyncPreferences.respiratoryRateAnchor = anchor
        HealthSyncPreferences.wristTemperatureAnchor = anchor
        HealthSyncPreferences.dietaryWaterAnchor = anchor
    }

    private var everyAnchor: [HKQueryAnchor?] {
        [
            HealthSyncPreferences.workoutAnchor,
            HealthSyncPreferences.weightEntryAnchor,
            HealthSyncPreferences.stepCountAnchor,
            HealthSyncPreferences.walkingRunningDistanceAnchor,
            HealthSyncPreferences.activeEnergyBurnedAnchor,
            HealthSyncPreferences.restingEnergyBurnedAnchor,
            HealthSyncPreferences.sleepAnalysisAnchor,
            HealthSyncPreferences.heartRateAnchor,
            HealthSyncPreferences.restingHeartRateAnchor,
            HealthSyncPreferences.walkingHeartRateAnchor,
            HealthSyncPreferences.heartRateVariabilityAnchor,
            HealthSyncPreferences.respiratoryRateAnchor,
            HealthSyncPreferences.wristTemperatureAnchor,
            HealthSyncPreferences.dietaryWaterAnchor,
        ]
    }

    /// A nil anchor is what makes an anchored query return the user's whole history rather than
    /// nothing, so "reset" has to mean every one of them.
    @Test func resettingClearsEveryAnchor() throws {
        let stored = everyAnchor
        defer {
            HealthSyncPreferences.resetAllAnchors()
            for (anchor, restore) in zip(stored, restorers) where anchor != nil { restore(anchor) }
        }

        setEveryAnchor(HKQueryAnchor(fromValue: 42))
        #expect(everyAnchor.allSatisfy { $0 != nil }, "the fixture must set every anchor it checks")

        HealthSyncPreferences.resetAllAnchors()

        #expect(everyAnchor.allSatisfy { $0 == nil })
    }

    private var restorers: [(HKQueryAnchor?) -> Void] {
        [
            { HealthSyncPreferences.workoutAnchor = $0 },
            { HealthSyncPreferences.weightEntryAnchor = $0 },
            { HealthSyncPreferences.stepCountAnchor = $0 },
            { HealthSyncPreferences.walkingRunningDistanceAnchor = $0 },
            { HealthSyncPreferences.activeEnergyBurnedAnchor = $0 },
            { HealthSyncPreferences.restingEnergyBurnedAnchor = $0 },
            { HealthSyncPreferences.sleepAnalysisAnchor = $0 },
            { HealthSyncPreferences.heartRateAnchor = $0 },
            { HealthSyncPreferences.restingHeartRateAnchor = $0 },
            { HealthSyncPreferences.walkingHeartRateAnchor = $0 },
            { HealthSyncPreferences.heartRateVariabilityAnchor = $0 },
            { HealthSyncPreferences.respiratoryRateAnchor = $0 },
            { HealthSyncPreferences.wristTemperatureAnchor = $0 },
            { HealthSyncPreferences.dietaryWaterAnchor = $0 },
        ]
    }
}

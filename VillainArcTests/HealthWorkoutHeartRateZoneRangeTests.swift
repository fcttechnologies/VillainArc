import Testing

@testable import VillainArc

struct HealthWorkoutHeartRateZoneRangeTests {
    @Test
    func closedLowerOpenUpperBoundsMatchWorkoutZoneThresholds() {
        let range = HealthWorkoutHeartRateZoneRange(zone: 3, lowerBoundBPM: 140, upperBoundBPM: 160)

        #expect(range.contains(139.9) == false)
        #expect(range.contains(140))
        #expect(range.contains(159.9))
        #expect(range.contains(160) == false)
    }

    @Test
    func openEndedRangesCoverLowestAndHighestZones() {
        let lowest = HealthWorkoutHeartRateZoneRange(zone: 1, lowerBoundBPM: nil, upperBoundBPM: 120)
        let highest = HealthWorkoutHeartRateZoneRange(zone: 5, lowerBoundBPM: 180, upperBoundBPM: nil)

        #expect(lowest.contains(80))
        #expect(lowest.contains(120) == false)
        #expect(highest.contains(180))
        #expect(highest.contains(205))
    }
}

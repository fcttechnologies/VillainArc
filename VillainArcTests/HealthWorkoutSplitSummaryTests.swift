import Foundation
import Testing

@testable import VillainArc

struct HealthWorkoutSplitSummaryTests {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func sample(_ from: TimeInterval, _ to: TimeInterval, meters: Double) -> HealthWorkoutDistanceSample {
        HealthWorkoutDistanceSample(startDate: start.addingTimeInterval(from), endDate: start.addingTimeInterval(to), distanceMeters: meters)
    }

    private func heartRate(_ from: TimeInterval, _ to: TimeInterval, bpm: Double) -> HealthWorkoutHeartRateSample {
        HealthWorkoutHeartRateSample(startDate: start.addingTimeInterval(from), endDate: start.addingTimeInterval(to), bpm: bpm)
    }

    @Test
    func overlappingDistanceSamplesNeverTrapAndStillSplit() {
        // Two writers (a watch and a phone) each covering the same stretch: the second sample
        // starts before the first one ended, so a split's carried-over start can sit after the
        // chunk that closes it. On device this was a SIGTRAP inside the split's DateInterval.
        let samples = [
            sample(0, 600, meters: 900),
            sample(300, 700, meters: 300),
            sample(700, 1_300, meters: 1_000),
        ]
        let heartRates = [heartRate(0, 650, bpm: 150), heartRate(650, 1_300, bpm: 160)]

        let splits = HealthWorkoutDetailLoader.makeSplitSummaries(
            from: samples, heartRateSamples: heartRates,
            workoutStart: start, workoutEnd: start.addingTimeInterval(1_300), distanceUnit: .km)

        #expect(splits.count == 3)
        #expect(splits.map(\.markerDistanceMeters) == [1_000, 2_000, 2_200])
        for split in splits { #expect(split.duration >= 0) }
    }

    @Test
    func orderedSamplesSplitAtEachUnitWithAnAverageHeartRate() {
        let samples = [sample(0, 300, meters: 1_000), sample(300, 660, meters: 1_000)]
        let heartRates = [heartRate(0, 300, bpm: 140), heartRate(300, 660, bpm: 160)]

        let splits = HealthWorkoutDetailLoader.makeSplitSummaries(
            from: samples, heartRateSamples: heartRates,
            workoutStart: start, workoutEnd: start.addingTimeInterval(660), distanceUnit: .km)

        // Heart-rate intervals span the midpoints between samples' representative dates, so the
        // second sample's 160 bpm reaches back to 480 s: the first split is all 140, the second is
        // 180 s of 140 and 180 s of 160.
        #expect(splits.count == 2)
        #expect(splits[0].averageHeartRate.map { abs($0 - 140) < 0.5 } == true)
        #expect(splits[1].averageHeartRate.map { abs($0 - 150) < 0.5 } == true)
    }
}

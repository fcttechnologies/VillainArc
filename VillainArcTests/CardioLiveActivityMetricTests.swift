import Foundation
import Testing

@testable import VillainArc

struct CardioLiveActivityMetricConfigTests {
    @Test func defaultIsHeartAndCurrentPace() {
        #expect(CardioLiveActivityMetricConfig.default.metrics == [.heartRate, .currentPace])
    }

    @Test func emptySelectionFallsBackToDefault() {
        #expect(CardioLiveActivityMetricConfig(metrics: []).metrics == [.heartRate, .currentPace])
    }

    @Test func normalizeDedupesPreservingOrder() {
        let config = CardioLiveActivityMetricConfig(metrics: [.distance, .distance, .time])
        #expect(config.metrics == [.distance, .time])
    }

    @Test func normalizeCapsAtMax() {
        let config = CardioLiveActivityMetricConfig(metrics: [.heartRate, .activeEnergy, .distance, .time])
        #expect(config.metrics.count == CardioLiveActivityMetricConfig.maxMetrics)
        #expect(config.metrics == [.heartRate, .activeEnergy])
    }

    @Test func togglingAddsWhenAbsent() {
        let config = CardioLiveActivityMetricConfig(metrics: [.heartRate])
        #expect(config.toggling(.distance).metrics == [.heartRate, .distance])
    }

    @Test func togglingRemovesWhenPresent() {
        let config = CardioLiveActivityMetricConfig(metrics: [.heartRate, .distance])
        #expect(config.toggling(.heartRate).metrics == [.distance])
    }

    @Test func togglingPastCapDropsOldest() {
        let config = CardioLiveActivityMetricConfig(metrics: [.heartRate, .currentPace])
        // Selecting a third drops the oldest so the newest pick lands.
        #expect(config.toggling(.distance).metrics == [.currentPace, .distance])
    }

    @Test func containsReflectsSelection() {
        let config = CardioLiveActivityMetricConfig(metrics: [.time])
        #expect(config.contains(.time))
        #expect(config.contains(.heartRate) == false)
    }

    @Test func codableRoundTripPreservesSelection() throws {
        let config = CardioLiveActivityMetricConfig(metrics: [.activeEnergy, .overallPace])
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(CardioLiveActivityMetricConfig.self, from: data)
        #expect(decoded == config)
        #expect(decoded.metrics == [.activeEnergy, .overallPace])
    }

    @Test func storeSaveLoadRoundTrips() {
        let original = CardioLiveActivityMetricStore.load()
        defer { CardioLiveActivityMetricStore.save(original) }

        CardioLiveActivityMetricStore.save(CardioLiveActivityMetricConfig(metrics: [.distance, .time]))
        #expect(CardioLiveActivityMetricStore.load().metrics == [.distance, .time])
    }

    @Test func allMetricsHaveDistinctDisplayNamesAndIcons() {
        let names = Set(CardioLiveActivityMetric.allCases.map(\.displayName))
        let icons = Set(CardioLiveActivityMetric.allCases.map(\.systemImage))
        #expect(names.count == CardioLiveActivityMetric.allCases.count)
        #expect(icons.count == CardioLiveActivityMetric.allCases.count)
    }
}

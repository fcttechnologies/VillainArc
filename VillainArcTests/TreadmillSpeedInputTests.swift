import Foundation
import Testing

@testable import VillainArc

struct TreadmillSpeedInputTests {
    @Test func capIsCanonicalAcrossUnits() {
        // 25 km/h regardless of display unit — the old cap of 15 *display* units limited
        // metric users to 15 km/h (~9.3 mph) while US users could enter 15 mph (~24 km/h).
        #expect(SpeedUnit.kmh.clampedTreadmillInput(999) == 25.0)
        let mphCap = SpeedUnit.mph.clampedTreadmillInput(999)
        #expect(abs(SpeedUnit.mph.toKPH(mphCap) - SpeedUnit.maxTreadmillSpeedKPH) < 0.1)
    }

    @Test func metricSprintSpeedsAreNoLongerClamped() {
        // 18 km/h is a normal fast run; the old display-unit cap forced it down to 15.
        #expect(SpeedUnit.kmh.clampedTreadmillInput(18.0) == 18.0)
        #expect(SpeedUnit.kmh.clampedTreadmillInput(24.9) == 24.9)
    }

    @Test func lowerBoundAndRoundingUnchanged() {
        #expect(SpeedUnit.kmh.clampedTreadmillInput(0.01) == 0.1)
        #expect(SpeedUnit.kmh.clampedTreadmillInput(8.04) == 8.0)
        #expect(SpeedUnit.kmh.clampedTreadmillInput(8.06) == 8.1)
        #expect(SpeedUnit.mph.clampedTreadmillInput(5.0) == 5.0)
    }
}

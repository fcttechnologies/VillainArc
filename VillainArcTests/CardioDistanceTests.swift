import Foundation
import Testing

@testable import VillainArc

struct CardioDistanceTests {
    @Test func zeroDistanceForIdenticalPoints() {
        let distance = CardioSession.distanceMeters(fromLatitude: 41.0, longitude: -88.0, toLatitude: 41.0, longitude: -88.0)
        #expect(distance == 0)
    }

    @Test func oneDegreeOfLatitudeMatchesGreatCircle() {
        // One degree of latitude is ~111.195 km (πR/180 with R = 6,371,000 m).
        let distance = CardioSession.distanceMeters(fromLatitude: 0, longitude: 0, toLatitude: 1, longitude: 0)
        #expect(abs(distance - 111_195) < 200)
    }

    @Test func distanceIsSymmetric() {
        let forward = CardioSession.distanceMeters(fromLatitude: 41.0, longitude: -88.0, toLatitude: 41.5, longitude: -87.5)
        let backward = CardioSession.distanceMeters(fromLatitude: 41.5, longitude: -87.5, toLatitude: 41.0, longitude: -88.0)
        #expect(abs(forward - backward) < 0.001)
    }
}

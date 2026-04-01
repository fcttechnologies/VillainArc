import Foundation
import SwiftData

@Model final class HealthSleepBlock {
    var startDate: Date = Date()
    var endDate: Date = Date()
    var isPrimary: Bool = false
    var timeAsleep: TimeInterval = 0
    var timeInBed: TimeInterval = 0
    var awakeDuration: TimeInterval = 0
    var remDuration: TimeInterval = 0
    var coreDuration: TimeInterval = 0
    var deepDuration: TimeInterval = 0
    var asleepUnspecifiedDuration: TimeInterval = 0
    var night: HealthSleepNight?

    init(startDate: Date, endDate: Date, isPrimary: Bool = false, timeAsleep: TimeInterval = 0, timeInBed: TimeInterval = 0, awakeDuration: TimeInterval = 0, remDuration: TimeInterval = 0, coreDuration: TimeInterval = 0, deepDuration: TimeInterval = 0, asleepUnspecifiedDuration: TimeInterval = 0, night: HealthSleepNight? = nil) {
        self.startDate = startDate
        self.endDate = endDate
        self.isPrimary = isPrimary
        self.timeAsleep = timeAsleep
        self.timeInBed = timeInBed
        self.awakeDuration = awakeDuration
        self.remDuration = remDuration
        self.coreDuration = coreDuration
        self.deepDuration = deepDuration
        self.asleepUnspecifiedDuration = asleepUnspecifiedDuration
        self.night = night
    }

    var hasStageBreakdown: Bool { awakeDuration > 0 || remDuration > 0 || coreDuration > 0 || deepDuration > 0 || asleepUnspecifiedDuration > 0 }
}

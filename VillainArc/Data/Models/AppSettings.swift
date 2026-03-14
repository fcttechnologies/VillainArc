import Foundation
import SwiftData

@Model
final class AppSettings {
    var autoStartRestTimer: Bool = true
    var autoCompleteSetAfterRPE: Bool = false
    var liveActivitiesEnabled: Bool = true
    var restTimerNotificationsEnabled: Bool = true
    var weightUnit: WeightUnit = WeightUnit.systemDefault
    var heightUnit: HeightUnit = HeightUnit.systemDefault
    
    init() {}
}

extension AppSettings {
    static var single: FetchDescriptor<AppSettings> {
        var descriptor = FetchDescriptor<AppSettings>()
        descriptor.fetchLimit = 1
        return descriptor
    }
}

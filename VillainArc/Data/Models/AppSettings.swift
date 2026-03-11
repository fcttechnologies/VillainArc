import Foundation
import SwiftData

@Model
final class AppSettings {
    var autoStartRestTimer: Bool = true
    var autoCompleteSetAfterRPE: Bool = false
    var liveActivitiesEnabled: Bool = true
    var restTimerNotificationsEnabled: Bool = true

    init() {}
}

extension AppSettings {
    static var single: FetchDescriptor<AppSettings> {
        var descriptor = FetchDescriptor<AppSettings>()
        descriptor.fetchLimit = 1
        return descriptor
    }
}

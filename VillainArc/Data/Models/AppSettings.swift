import Foundation
import SwiftData

@Model
final class AppSettings {
    var autoStartRestTimer: Bool = true
    var autoCompleteSetAfterRPE: Bool = false
    var promptForPreWorkoutContext: Bool = true
    var promptForPostWorkoutEffort: Bool = true
    var liveActivitiesEnabled: Bool = true
    var restTimerNotificationsEnabled: Bool = true
    var weightUnit: WeightUnit = WeightUnit.systemDefault
    var heightUnit: HeightUnit = HeightUnit.systemDefault
    
    init() {}
}

struct AppSettingsSnapshot {
    let autoStartRestTimer: Bool
    let autoCompleteSetAfterRPE: Bool
    let promptForPreWorkoutContext: Bool
    let promptForPostWorkoutEffort: Bool
    let liveActivitiesEnabled: Bool
    let restTimerNotificationsEnabled: Bool
    let weightUnit: WeightUnit
    let heightUnit: HeightUnit

    init(settings: AppSettings?) {
        autoStartRestTimer = settings?.autoStartRestTimer ?? true
        autoCompleteSetAfterRPE = settings?.autoCompleteSetAfterRPE ?? false
        promptForPreWorkoutContext = settings?.promptForPreWorkoutContext ?? true
        promptForPostWorkoutEffort = settings?.promptForPostWorkoutEffort ?? true
        liveActivitiesEnabled = settings?.liveActivitiesEnabled ?? true
        restTimerNotificationsEnabled = settings?.restTimerNotificationsEnabled ?? true
        weightUnit = settings?.weightUnit ?? .lbs
        heightUnit = settings?.heightUnit ?? .systemDefault
    }
}

extension AppSettings {
    static var single: FetchDescriptor<AppSettings> {
        var descriptor = FetchDescriptor<AppSettings>()
        descriptor.fetchLimit = 1
        return descriptor
    }
}

import Foundation
import SwiftData

@Model final class AppSettings {
    var autoStartRestTimer: Bool = true
    var autoCompleteSetAfterRPE: Bool = false
    var promptForPreWorkoutContext: Bool = true
    var promptForPostWorkoutEffort: Bool = true
    var retainPerformancesForLearning: Bool = true
    var keepRemovedHealthData: Bool = true
    var liveActivitiesEnabled: Bool = true
    var restTimerNotificationsEnabled: Bool = true
    var stepsNotificationMode: StepsEventNotificationMode = StepsEventNotificationMode.goalOnly
    var weightUnit: WeightUnit = WeightUnit.systemDefault
    var heightUnit: HeightUnit = HeightUnit.systemDefault
    var distanceUnit: DistanceUnit = DistanceUnit.systemDefault
    var energyUnit: EnergyUnit = EnergyUnit.systemDefault

    init() {}
}

struct AppSettingsSnapshot {
    let autoStartRestTimer: Bool
    let autoCompleteSetAfterRPE: Bool
    let promptForPreWorkoutContext: Bool
    let promptForPostWorkoutEffort: Bool
    let retainPerformancesForLearning: Bool
    let keepRemovedHealthData: Bool
    let liveActivitiesEnabled: Bool
    let restTimerNotificationsEnabled: Bool
    let stepsNotificationMode: StepsEventNotificationMode
    let weightUnit: WeightUnit
    let heightUnit: HeightUnit
    let distanceUnit: DistanceUnit
    let energyUnit: EnergyUnit

    nonisolated init(settings: AppSettings?) {
        autoStartRestTimer = settings?.autoStartRestTimer ?? true
        autoCompleteSetAfterRPE = settings?.autoCompleteSetAfterRPE ?? false
        promptForPreWorkoutContext = settings?.promptForPreWorkoutContext ?? true
        promptForPostWorkoutEffort = settings?.promptForPostWorkoutEffort ?? true
        retainPerformancesForLearning = settings?.retainPerformancesForLearning ?? true
        keepRemovedHealthData = settings?.keepRemovedHealthData ?? true
        liveActivitiesEnabled = settings?.liveActivitiesEnabled ?? true
        restTimerNotificationsEnabled = settings?.restTimerNotificationsEnabled ?? true
        stepsNotificationMode = settings?.stepsNotificationMode ?? .goalOnly
        weightUnit = settings?.weightUnit ?? .systemDefault
        heightUnit = settings?.heightUnit ?? .systemDefault
        distanceUnit = settings?.distanceUnit ?? .systemDefault
        energyUnit = settings?.energyUnit ?? .systemDefault
    }
}

extension AppSettings {
    static var single: FetchDescriptor<AppSettings> {
        var descriptor = FetchDescriptor<AppSettings>()
        descriptor.fetchLimit = 1
        return descriptor
    }
}

import Foundation
import SwiftData

@Model final class AppSettings {
    var autoStartRestTimer: Bool = true
    var autoCompleteSetAfterRPE: Bool = false
    var autoFillPlanTargets: Bool = true
    var promptForPreWorkoutContext: Bool = false
    var promptForPostWorkoutEffort: Bool = true
    var retainPerformancesForLearning: Bool = true
    var keepRemovedHealthData: Bool = true
    var liveActivitiesEnabled: Bool = true
    var stepsNotificationMode: StepsEventNotificationMode = StepsEventNotificationMode.coaching
    var sleepNotificationMode: SleepNotificationMode = SleepNotificationMode.goalOnly
    var appearanceMode: AppAppearanceMode = AppAppearanceMode.system
    var weightUnit: WeightUnit = WeightUnit.systemDefault
    var heightUnit: HeightUnit = HeightUnit.systemDefault
    var distanceUnit: DistanceUnit = DistanceUnit.systemDefault
    var energyUnit: EnergyUnit = EnergyUnit.systemDefault

    init() {}
}

struct AppSettingsSnapshot {
    let autoStartRestTimer: Bool
    let autoCompleteSetAfterRPE: Bool
    let autoFillPlanTargets: Bool
    let promptForPreWorkoutContext: Bool
    let promptForPostWorkoutEffort: Bool
    let retainPerformancesForLearning: Bool
    let keepRemovedHealthData: Bool
    let liveActivitiesEnabled: Bool
    let stepsNotificationMode: StepsEventNotificationMode
    let sleepNotificationMode: SleepNotificationMode
    let appearanceMode: AppAppearanceMode
    let weightUnit: WeightUnit
    let heightUnit: HeightUnit
    let distanceUnit: DistanceUnit
    let energyUnit: EnergyUnit

    nonisolated init(settings: AppSettings?) {
        autoStartRestTimer = settings?.autoStartRestTimer ?? true
        autoCompleteSetAfterRPE = settings?.autoCompleteSetAfterRPE ?? false
        autoFillPlanTargets = settings?.autoFillPlanTargets ?? true
        promptForPreWorkoutContext = settings?.promptForPreWorkoutContext ?? false
        promptForPostWorkoutEffort = settings?.promptForPostWorkoutEffort ?? true
        retainPerformancesForLearning = settings?.retainPerformancesForLearning ?? true
        keepRemovedHealthData = settings?.keepRemovedHealthData ?? true
        liveActivitiesEnabled = settings?.liveActivitiesEnabled ?? true
        stepsNotificationMode = settings?.stepsNotificationMode ?? .coaching
        sleepNotificationMode = settings?.sleepNotificationMode ?? .goalOnly
        appearanceMode = settings?.appearanceMode ?? .system
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

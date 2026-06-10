import Foundation
import SwiftData

enum PreviousSetReferenceSource: String, Codable, CaseIterable, Identifiable {
    case anyWorkout
    case lastPlanUse

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .anyWorkout: "Any Workout"
        case .lastPlanUse: "Last Plan Use"
        }
    }
}

@Model final class AppSettings {
    var autoStartRestTimer: Bool = true
    var autoCompleteSetAfterRPE: Bool = false
    var autoFillPlanTargets: Bool = true
    var assumeTargetRPEOnComplete: Bool = true
    var prefersTargetReferenceWhenPlanned: Bool = true
    var previousSetReferenceSource: PreviousSetReferenceSource = PreviousSetReferenceSource.anyWorkout
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
    var temperatureUnit: TemperatureUnit = TemperatureUnit.systemDefault
    var hydrationUnit: HydrationUnit = HydrationUnit.systemDefault
    var hydrationNotificationMode: HydrationEventNotificationMode = HydrationEventNotificationMode.goalOnly
    var speedUnit: SpeedUnit = SpeedUnit.systemDefault
    var favoriteCardioKindRawValue: String?

    init() {}

    var favoriteCardioType: CardioSessionType? {
        get { favoriteCardioKindRawValue.flatMap { CardioSessionType(rawValue: $0) } }
        set { favoriteCardioKindRawValue = newValue?.rawValue }
    }
}

struct AppSettingsSnapshot {
    let autoStartRestTimer: Bool
    let autoCompleteSetAfterRPE: Bool
    let autoFillPlanTargets: Bool
    let assumeTargetRPEOnComplete: Bool
    let prefersTargetReferenceWhenPlanned: Bool
    let previousSetReferenceSource: PreviousSetReferenceSource
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
    let temperatureUnit: TemperatureUnit
    let hydrationUnit: HydrationUnit
    let hydrationNotificationMode: HydrationEventNotificationMode
    let speedUnit: SpeedUnit

    nonisolated init(settings: AppSettings?) {
        autoStartRestTimer = settings?.autoStartRestTimer ?? true
        autoCompleteSetAfterRPE = settings?.autoCompleteSetAfterRPE ?? false
        autoFillPlanTargets = settings?.autoFillPlanTargets ?? true
        assumeTargetRPEOnComplete = settings?.assumeTargetRPEOnComplete ?? true
        prefersTargetReferenceWhenPlanned = settings?.prefersTargetReferenceWhenPlanned ?? true
        previousSetReferenceSource = settings?.previousSetReferenceSource ?? .anyWorkout
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
        temperatureUnit = settings?.temperatureUnit ?? .systemDefault
        hydrationUnit = settings?.hydrationUnit ?? .systemDefault
        hydrationNotificationMode = settings?.hydrationNotificationMode ?? .goalOnly
        speedUnit = settings?.speedUnit ?? .systemDefault
    }
}

extension AppSettings {
    static var single: FetchDescriptor<AppSettings> {
        var descriptor = FetchDescriptor<AppSettings>()
        descriptor.fetchLimit = 1
        return descriptor
    }
}

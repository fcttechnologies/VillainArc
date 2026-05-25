import SwiftUI
import WidgetKit

@main struct VillainArcWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        HealthWeightWidget()
        HealthSleepWidget()
        HealthStepsWidget()
        HealthEnergyWidget()
        HealthHydrationWidget()
        HealthHeartRateWidget()
        HealthRestingHeartRateWidget()
        HealthWalkingHeartRateWidget()
        HealthHeartRateVariabilityWidget()
        HealthRespiratoryRateWidget()
        HealthWristTemperatureWidget()
        WorkoutLiveActivity()
    }
}

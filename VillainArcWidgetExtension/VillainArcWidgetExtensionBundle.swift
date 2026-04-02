import SwiftUI
import WidgetKit

@main struct VillainArcWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        HealthWeightWidget()
        HealthSleepWidget()
        HealthStepsWidget()
        HealthEnergyWidget()
        WorkoutLiveActivity()
    }
}

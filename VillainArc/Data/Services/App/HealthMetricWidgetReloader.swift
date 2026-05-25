import WidgetKit

nonisolated enum HealthMetricWidgetReloader {
    private static let weightKind = "HealthWeightWidget"
    private static let sleepKind = "HealthSleepWidget"
    private static let stepsKind = "HealthStepsWidget"
    private static let energyKind = "HealthEnergyWidget"
    private static let hydrationKind = "HealthHydrationWidget"
    private static let heartRateKind = "HealthHeartRateWidget"
    private static let restingHeartRateKind = "HealthRestingHeartRateWidget"
    private static let walkingHeartRateKind = "HealthWalkingHeartRateWidget"
    private static let heartRateVariabilityKind = "HealthHeartRateVariabilityWidget"
    private static let respiratoryRateKind = "HealthRespiratoryRateWidget"
    private static let wristTemperatureKind = "HealthWristTemperatureWidget"

    static func reloadWeight() {
        Task { @MainActor in
            WidgetCenter.shared.reloadTimelines(ofKind: weightKind)
        }
    }

    static func reloadSleep() {
        Task { @MainActor in
            WidgetCenter.shared.reloadTimelines(ofKind: sleepKind)
        }
    }

    static func reloadSteps() {
        Task { @MainActor in
            WidgetCenter.shared.reloadTimelines(ofKind: stepsKind)
        }
    }

    static func reloadEnergy() {
        Task { @MainActor in
            WidgetCenter.shared.reloadTimelines(ofKind: energyKind)
        }
    }

    static func reloadHydration() {
        Task { @MainActor in
            WidgetCenter.shared.reloadTimelines(ofKind: hydrationKind)
        }
    }

    static func reloadHeart() {
        Task { @MainActor in
            WidgetCenter.shared.reloadTimelines(ofKind: heartRateKind)
            WidgetCenter.shared.reloadTimelines(ofKind: restingHeartRateKind)
            WidgetCenter.shared.reloadTimelines(ofKind: walkingHeartRateKind)
            WidgetCenter.shared.reloadTimelines(ofKind: heartRateVariabilityKind)
        }
    }

    static func reloadRespiratoryRate() {
        Task { @MainActor in
            WidgetCenter.shared.reloadTimelines(ofKind: respiratoryRateKind)
        }
    }

    static func reloadWristTemperature() {
        Task { @MainActor in
            WidgetCenter.shared.reloadTimelines(ofKind: wristTemperatureKind)
        }
    }

    static func reloadAllHealthMetrics() {
        reloadWeight()
        reloadSleep()
        reloadSteps()
        reloadEnergy()
        reloadHydration()
        reloadHeart()
        reloadRespiratoryRate()
        reloadWristTemperature()
    }
}

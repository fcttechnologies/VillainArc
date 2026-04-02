import WidgetKit

nonisolated enum HealthMetricWidgetReloader {
    private static let weightKind = "HealthWeightWidget"
    private static let sleepKind = "HealthSleepWidget"
    private static let stepsKind = "HealthStepsWidget"
    private static let energyKind = "HealthEnergyWidget"

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

    static func reloadAllHealthMetrics() {
        reloadWeight()
        reloadSleep()
        reloadSteps()
        reloadEnergy()
    }
}

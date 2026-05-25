import Charts
import SwiftData
import SwiftUI
import WidgetKit

private enum HealthMetricWidgetKind {
    case weight
    case sleep
    case steps
    case energy
    case hydration
    case heartRate
    case restingHeartRate
    case walkingHeartRate
    case heartRateVariability
    case respiratoryRate
    case wristTemperature

    var widgetKind: String {
        switch self {
        case .weight: "HealthWeightWidget"
        case .sleep: "HealthSleepWidget"
        case .steps: "HealthStepsWidget"
        case .energy: "HealthEnergyWidget"
        case .hydration: "HealthHydrationWidget"
        case .heartRate: "HealthHeartRateWidget"
        case .restingHeartRate: "HealthRestingHeartRateWidget"
        case .walkingHeartRate: "HealthWalkingHeartRateWidget"
        case .heartRateVariability: "HealthHeartRateVariabilityWidget"
        case .respiratoryRate: "HealthRespiratoryRateWidget"
        case .wristTemperature: "HealthWristTemperatureWidget"
        }
    }

    var title: String {
        switch self {
        case .weight: String(localized: "Weight")
        case .sleep: String(localized: "Sleep")
        case .steps: String(localized: "Steps")
        case .energy: String(localized: "Energy")
        case .hydration: String(localized: "Hydration")
        case .heartRate: String(localized: "Heart Rate")
        case .restingHeartRate: String(localized: "Resting HR")
        case .walkingHeartRate: String(localized: "Walking HR")
        case .heartRateVariability: String(localized: "HRV")
        case .respiratoryRate: String(localized: "Respiratory Rate")
        case .wristTemperature: String(localized: "Wrist Temp")
        }
    }

    var symbolName: String {
        switch self {
        case .weight: "scalemass.fill"
        case .sleep: "bed.double.fill"
        case .steps: "figure.walk"
        case .energy: "flame.fill"
        case .hydration: "drop.fill"
        case .heartRate: "heart.fill"
        case .restingHeartRate: "heart.text.square.fill"
        case .walkingHeartRate: "figure.walk"
        case .heartRateVariability: "waveform.path.ecg"
        case .respiratoryRate: "lungs.fill"
        case .wristTemperature: "thermometer.medium"
        }
    }

    var tint: Color {
        switch self {
        case .weight: .blue
        case .sleep: .indigo
        case .steps: .red
        case .energy: .orange
        case .hydration: .blue
        case .heartRate: .red
        case .restingHeartRate: .pink
        case .walkingHeartRate: .orange
        case .heartRateVariability: .purple
        case .respiratoryRate: .teal
        case .wristTemperature: .cyan
        }
    }

    var displayName: String {
        switch self {
        case .weight: String(localized: "Weight")
        case .sleep: String(localized: "Sleep")
        case .steps: String(localized: "Steps")
        case .energy: String(localized: "Energy")
        case .hydration: String(localized: "Hydration")
        case .heartRate: String(localized: "Heart Rate")
        case .restingHeartRate: String(localized: "Resting HR")
        case .walkingHeartRate: String(localized: "Walking HR")
        case .heartRateVariability: String(localized: "HRV")
        case .respiratoryRate: String(localized: "Respiratory Rate")
        case .wristTemperature: String(localized: "Wrist Temp")
        }
    }

    var description: String {
        switch self {
        case .weight: String(localized: "Shows your latest weight and current goal.")
        case .sleep: String(localized: "Shows your latest sleep duration and current goal.")
        case .steps: String(localized: "Shows your latest steps entry and current goal.")
        case .energy: String(localized: "Shows your latest active and total energy.")
        case .hydration: String(localized: "Shows today's water intake and daily goal.")
        case .heartRate: String(localized: "Shows your latest daily heart rate range.")
        case .restingHeartRate: String(localized: "Shows your latest resting heart rate.")
        case .walkingHeartRate: String(localized: "Shows your latest walking heart rate average.")
        case .heartRateVariability: String(localized: "Shows your latest heart rate variability.")
        case .respiratoryRate: String(localized: "Shows your latest respiratory rate range.")
        case .wristTemperature: String(localized: "Shows your latest sleeping wrist temperature.")
        }
    }

    var emptyMessage: String {
        switch self {
        case .weight: String(localized: "Add or sync a weight entry to see it here.")
        case .sleep: String(localized: "Sleep data will appear here after your next sync.")
        case .steps: String(localized: "Steps data will appear here after your next sync.")
        case .energy: String(localized: "Energy data will appear here after your next sync.")
        case .hydration: String(localized: "Water entries will appear here after you add or sync them.")
        case .heartRate: String(localized: "Heart rate ranges will appear here after your next sync.")
        case .restingHeartRate: String(localized: "Resting heart rate will appear here after your next sync.")
        case .walkingHeartRate: String(localized: "Walking heart rate will appear here after your next sync.")
        case .heartRateVariability: String(localized: "HRV will appear here after your next sync.")
        case .respiratoryRate: String(localized: "Respiratory rate will appear here after your next sync.")
        case .wristTemperature: String(localized: "Wrist temperature will appear here after your next sync.")
        }
    }

    var isVitalMetric: Bool {
        switch self {
        case .heartRate, .restingHeartRate, .walkingHeartRate, .heartRateVariability, .respiratoryRate, .wristTemperature:
            return true
        default:
            return false
        }
    }

    var omitsDateDisplay: Bool {
        isVitalMetric || self == .hydration
    }

    var widgetURL: URL {
        switch self {
        case .weight:
            URL(string: "villainarc://health/weight-history")!
        case .sleep:
            URL(string: "villainarc://health/sleep-history")!
        case .steps:
            URL(string: "villainarc://health/steps-history")!
        case .energy:
            URL(string: "villainarc://health/energy-history")!
        case .hydration:
            URL(string: "villainarc://health/hydration-history")!
        case .heartRate:
            URL(string: "villainarc://health/heart-rate-history")!
        case .restingHeartRate:
            URL(string: "villainarc://health/resting-heart-rate-history")!
        case .walkingHeartRate:
            URL(string: "villainarc://health/walking-heart-rate-history")!
        case .heartRateVariability:
            URL(string: "villainarc://health/heart-rate-variability-history")!
        case .respiratoryRate:
            URL(string: "villainarc://health/respiratory-rate-history")!
        case .wristTemperature:
            URL(string: "villainarc://health/wrist-temperature-history")!
        }
    }
}

private enum HealthMetricWidgetContent {
    case weight(goalLabelText: String?, goalValueText: String?, valueText: String, unitText: String)
    case sleep(goalLabelText: String?, goalValueText: String?, duration: TimeInterval)
    case steps(goalLabelText: String?, goalValueText: String?, stepCount: Int)
    case energy(activeText: String, totalText: String)
    case hydration(goalText: String?, totalText: String, unitText: String)
    case vital(valueText: String, unitText: String)
    case empty(message: String)
}

private enum HealthMetricWidgetChartContent {
    case weight([HealthMetricWidgetValuePoint])
    case sleep([HealthMetricWidgetValuePoint])
    case steps([HealthMetricWidgetValuePoint])
    case energy([HealthMetricWidgetEnergyPoint])
    case hydration([HealthMetricWidgetHydrationPoint])
    case line([HealthMetricWidgetValuePoint])
    case range([HealthMetricWidgetRangePoint])
    case none
}

private struct HealthMetricWidgetValuePoint: Identifiable, Hashable {
    let date: Date
    let value: Double

    var id: Date { date }
}

private struct HealthMetricWidgetEnergyPoint: Identifiable, Hashable {
    enum Kind: String, Hashable {
        case resting
        case active
    }

    let id: String
    let date: Date
    let kind: Kind
    let value: Double
}

private struct HealthMetricWidgetHydrationPoint: Identifiable, Hashable {
    enum Kind: String, Hashable {
        case logged
        case remaining
        case overGoal
    }

    let id: String
    let date: Date
    let kind: Kind
    let value: Double
}

private struct HealthMetricWidgetRangePoint: Identifiable, Hashable {
    let date: Date
    let low: Double
    let high: Double

    var id: Date { date }
}

private struct HealthMetricWidgetEntry: TimelineEntry {
    let date: Date
    let metric: HealthMetricWidgetKind
    let latestDateText: String?
    let content: HealthMetricWidgetContent
    let chartContent: HealthMetricWidgetChartContent
}

private struct HealthMetricWidgetProvider: TimelineProvider {
    private static let refreshInterval: TimeInterval = 30 * 60

    private enum LoadStyle {
        case compact
        case expanded

        init(family: WidgetFamily) {
            switch family {
            case .systemMedium:
                self = .expanded
            default:
                self = .compact
            }
        }
    }

    let metric: HealthMetricWidgetKind

    func placeholder(in context: Context) -> HealthMetricWidgetEntry {
        sampleEntry(for: metric)
    }

    func getSnapshot(in context: Context, completion: @escaping (HealthMetricWidgetEntry) -> Void) {
        completion(loadEntry(for: context.family))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HealthMetricWidgetEntry>) -> Void) {
        let entry = loadEntry(for: context.family)
        let nextRefresh = Date().addingTimeInterval(Self.refreshInterval)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func loadEntry(for family: WidgetFamily) -> HealthMetricWidgetEntry {
        let context = ModelContext(SharedModelContainer.container)
        let settings = AppSettingsSnapshot(settings: try? context.fetch(AppSettings.single).first)
        let loadStyle = LoadStyle(family: family)

        switch metric {
        case .weight:
            let latestEntry = try? context.fetch(WeightEntry.latest).first
            let activeGoal = try? context.fetch(WeightGoal.active).first
            guard let latestEntry else {
                return .init(date: .now, metric: .weight, latestDateText: nil, content: .empty(message: metric.emptyMessage), chartContent: .none)
            }

            let goalLabelText: String?
            let goalValueText: String?
            if let activeGoal {
                if activeGoal.type == .maintain {
                    goalLabelText = nil
                    goalValueText = String(localized: "Maintain")
                } else {
                    goalLabelText = String(localized: "Goal:")
                    goalValueText = formattedWeightText(activeGoal.targetWeight, unit: settings.weightUnit)
                }
            } else {
                goalLabelText = nil
                goalValueText = nil
            }

            return .init(
                date: .now,
                metric: .weight,
                latestDateText: formattedRecentDay(latestEntry.date),
                content: .weight(
                    goalLabelText: goalLabelText,
                    goalValueText: goalValueText,
                    valueText: formattedWeightValue(latestEntry.weight, unit: settings.weightUnit, fractionDigits: 0...1),
                    unitText: settings.weightUnit.rawValue
                ),
                chartContent: loadWeightChartContent(context: context, settings: settings, loadStyle: loadStyle)
            )

        case .sleep:
            let latestEntry = try? context.fetch(HealthSleepNight.latest).first
            let activeGoal = try? context.fetch(SleepGoal.active).first
            guard let latestEntry else {
                return .init(date: .now, metric: .sleep, latestDateText: nil, content: .empty(message: metric.emptyMessage), chartContent: .none)
            }

            let goalLabelText: String?
            let goalValueText: String?
            if let activeGoal {
                goalLabelText = String(localized: "Goal:")
                goalValueText = widgetFormattedSleepGoalDuration(activeGoal.targetSleepDuration)
            } else {
                goalLabelText = nil
                goalValueText = nil
            }

            return .init(
                date: .now,
                metric: .sleep,
                latestDateText: widgetFormattedSleepWakeDay(latestEntry.wakeDay),
                content: .sleep(goalLabelText: goalLabelText, goalValueText: goalValueText, duration: latestEntry.timeAsleep),
                chartContent: loadSleepChartContent(context: context, loadStyle: loadStyle)
            )

        case .steps:
            let latestEntry = try? context.fetch(HealthStepsDistance.latest).first
            let activeGoal = try? context.fetch(StepsGoal.active).first
            guard let latestEntry else {
                return .init(date: .now, metric: .steps, latestDateText: nil, content: .empty(message: metric.emptyMessage), chartContent: .none)
            }

            let goalLabelText: String?
            let goalValueText: String?
            if let activeGoal {
                goalLabelText = String(localized: "Goal:")
                goalValueText = widgetCompactStepsText(activeGoal.targetSteps)
            } else {
                goalLabelText = nil
                goalValueText = nil
            }

            return .init(
                date: .now,
                metric: .steps,
                latestDateText: formattedRecentDay(latestEntry.date),
                content: .steps(goalLabelText: goalLabelText, goalValueText: goalValueText, stepCount: latestEntry.stepCount),
                chartContent: loadStepsChartContent(context: context, loadStyle: loadStyle)
            )

        case .energy:
            let latestEntry = try? context.fetch(HealthEnergy.latest).first
            guard let latestEntry else {
                return .init(date: .now, metric: .energy, latestDateText: nil, content: .empty(message: metric.emptyMessage), chartContent: .none)
            }

            let activeText = Int(settings.energyUnit.fromKilocalories(latestEntry.activeEnergyBurned).rounded()).formatted(.number)
            let totalText = Int(settings.energyUnit.fromKilocalories(latestEntry.totalEnergyBurned).rounded()).formatted(.number)

            return .init(
                date: .now,
                metric: .energy,
                latestDateText: formattedRecentDay(latestEntry.date),
                content: .energy(activeText: activeText, totalText: totalText),
                chartContent: loadEnergyChartContent(context: context, settings: settings, loadStyle: loadStyle)
            )
        case .hydration:
            let entries = (try? context.fetch(HydrationEntry.history)) ?? []
            let activeGoal = try? context.fetch(HydrationGoal.active).first
            let todayGoalML = activeGoal?.targetML ?? 3000
            let todayTotal = HydrationEntry.todayTotal(from: entries, goalML: todayGoalML)
            guard !entries.isEmpty || todayTotal.totalVolume > 0 else {
                return .init(date: .now, metric: .hydration, latestDateText: nil, content: .empty(message: metric.emptyMessage), chartContent: .none)
            }

            let hydrationUnit = settings.hydrationUnit
            let goalText: String? = activeGoal.map { widgetFormattedHydration($0.targetML, unit: hydrationUnit) }
            let totalText = widgetFormattedHydration(todayTotal.totalVolume, unit: hydrationUnit)

            return .init(
                date: .now,
                metric: .hydration,
                latestDateText: String(localized: "Today"),
                content: .hydration(goalText: goalText, totalText: totalText, unitText: hydrationUnit.unitLabel),
                chartContent: loadHydrationChartContent(entries: entries, activeGoal: activeGoal, settings: settings, loadStyle: loadStyle)
            )
        case .heartRate:
            let entries = (try? context.fetch(HealthHeart.history)) ?? []
            guard let latestEntry = entries.first(where: { $0.minHeartRate != nil && $0.maxHeartRate != nil }),
                  let low = latestEntry.minHeartRate,
                  let high = latestEntry.maxHeartRate else {
                return .init(date: .now, metric: .heartRate, latestDateText: nil, content: .empty(message: metric.emptyMessage), chartContent: .none)
            }

            return .init(
                date: .now,
                metric: .heartRate,
                latestDateText: formattedRecentDay(latestEntry.date),
                content: .vital(valueText: "\(Int(low.rounded()))-\(Int(high.rounded()))", unitText: "bpm"),
                chartContent: loadHeartRateRangeChartContent(context: context, loadStyle: loadStyle)
            )
        case .restingHeartRate:
            let entries = (try? context.fetch(HealthHeart.history)) ?? []
            guard let latestEntry = entries.first(where: { $0.restingHeartRate != nil }),
                  let value = latestEntry.restingHeartRate else {
                return .init(date: .now, metric: .restingHeartRate, latestDateText: nil, content: .empty(message: metric.emptyMessage), chartContent: .none)
            }

            return .init(
                date: .now,
                metric: .restingHeartRate,
                latestDateText: formattedRecentDay(latestEntry.date),
                content: .vital(valueText: "\(Int(value.rounded()))", unitText: "bpm"),
                chartContent: loadHeartLineChartContent(context: context, loadStyle: loadStyle) { $0.restingHeartRate }
            )
        case .walkingHeartRate:
            let entries = (try? context.fetch(HealthHeart.history)) ?? []
            guard let latestEntry = entries.first(where: { $0.walkingHeartRateAverage != nil }),
                  let value = latestEntry.walkingHeartRateAverage else {
                return .init(date: .now, metric: .walkingHeartRate, latestDateText: nil, content: .empty(message: metric.emptyMessage), chartContent: .none)
            }

            return .init(
                date: .now,
                metric: .walkingHeartRate,
                latestDateText: formattedRecentDay(latestEntry.date),
                content: .vital(valueText: "\(Int(value.rounded()))", unitText: "bpm"),
                chartContent: loadHeartLineChartContent(context: context, loadStyle: loadStyle) { $0.walkingHeartRateAverage }
            )
        case .heartRateVariability:
            let entries = (try? context.fetch(HealthHeart.history)) ?? []
            guard let latestEntry = entries.first(where: { $0.heartRateVariabilitySDNN != nil }),
                  let value = latestEntry.heartRateVariabilitySDNN else {
                return .init(date: .now, metric: .heartRateVariability, latestDateText: nil, content: .empty(message: metric.emptyMessage), chartContent: .none)
            }

            return .init(
                date: .now,
                metric: .heartRateVariability,
                latestDateText: formattedRecentDay(latestEntry.date),
                content: .vital(valueText: "\(Int(value.rounded()))", unitText: "ms"),
                chartContent: loadHeartLineChartContent(context: context, loadStyle: loadStyle) { $0.heartRateVariabilitySDNN }
            )
        case .respiratoryRate:
            let entries = (try? context.fetch(HealthRespiratoryRate.history)) ?? []
            guard let latestEntry = entries.first(where: { $0.minRate != nil && $0.maxRate != nil }),
                  let low = latestEntry.minRate,
                  let high = latestEntry.maxRate else {
                return .init(date: .now, metric: .respiratoryRate, latestDateText: nil, content: .empty(message: metric.emptyMessage), chartContent: .none)
            }

            return .init(
                date: .now,
                metric: .respiratoryRate,
                latestDateText: formattedRecentDay(latestEntry.date),
                content: .vital(
                    valueText: "\(low.formatted(.number.precision(.fractionLength(0...1))))-\(high.formatted(.number.precision(.fractionLength(0...1))))",
                    unitText: "br/min"
                ),
                chartContent: loadRespiratoryRangeChartContent(context: context, loadStyle: loadStyle)
            )
        case .wristTemperature:
            let latestEntry = try? context.fetch(HealthWristTemperature.latest).first
            guard let latestEntry else {
                return .init(date: .now, metric: .wristTemperature, latestDateText: nil, content: .empty(message: metric.emptyMessage), chartContent: .none)
            }

            return .init(
                date: .now,
                metric: .wristTemperature,
                latestDateText: formattedRecentDay(latestEntry.date),
                content: .vital(
                    valueText: settings.temperatureUnit.fromCelsius(latestEntry.temperature).formatted(.number.precision(.fractionLength(0...1))),
                    unitText: settings.temperatureUnit.unitLabel
                ),
                chartContent: loadWristTemperatureChartContent(context: context, settings: settings, loadStyle: loadStyle)
            )
        }
    }

    private func loadWeightChartContent(context: ModelContext, settings: AppSettingsSnapshot, loadStyle: LoadStyle) -> HealthMetricWidgetChartContent {
        guard loadStyle == .expanded else { return .none }
        let summaryEntries = (try? context.fetch(WeightEntry.summary)) ?? []
        return .weight(summaryEntries
            .map { HealthMetricWidgetValuePoint(date: $0.date, value: settings.weightUnit.fromKg($0.weight)) }
            .sorted { $0.date < $1.date })
    }

    private func loadSleepChartContent(context: ModelContext, loadStyle: LoadStyle) -> HealthMetricWidgetChartContent {
        guard loadStyle == .expanded else { return .none }
        let summaryEntries = (try? context.fetch(HealthSleepNight.summary)) ?? []
        return .sleep(summaryEntries
            .map { HealthMetricWidgetValuePoint(date: HealthSleepNight.displayDate(forWakeDay: $0.wakeDay), value: $0.timeAsleep) }
            .sorted { $0.date < $1.date })
    }

    private func loadStepsChartContent(context: ModelContext, loadStyle: LoadStyle) -> HealthMetricWidgetChartContent {
        guard loadStyle == .expanded else { return .none }
        let summaryEntries = (try? context.fetch(HealthStepsDistance.summary)) ?? []
        return .steps(summaryEntries
            .map { HealthMetricWidgetValuePoint(date: $0.date, value: Double($0.stepCount)) }
            .sorted { $0.date < $1.date })
    }

    private func loadEnergyChartContent(context: ModelContext, settings: AppSettingsSnapshot, loadStyle: LoadStyle) -> HealthMetricWidgetChartContent {
        guard loadStyle == .expanded else { return .none }
        let summaryEntries = (try? context.fetch(HealthEnergy.summary)) ?? []
        return .energy(summaryEntries
            .flatMap { entry in
                let activeEnergy = settings.energyUnit.fromKilocalories(entry.activeEnergyBurned)
                let restingEnergy = settings.energyUnit.fromKilocalories(entry.restingEnergyBurned)
                var points: [HealthMetricWidgetEnergyPoint] = []
                if activeEnergy > 0 {
                    points.append(.init(id: "\(entry.date.timeIntervalSinceReferenceDate)-active", date: entry.date, kind: .active, value: activeEnergy))
                }
                if restingEnergy > 0 {
                    points.append(.init(id: "\(entry.date.timeIntervalSinceReferenceDate)-resting", date: entry.date, kind: .resting, value: restingEnergy))
                }
                return points
            })
    }

    private func loadHydrationChartContent(entries: [HydrationEntry], activeGoal: HydrationGoal?, settings: AppSettingsSnapshot, loadStyle: LoadStyle) -> HealthMetricWidgetChartContent {
        guard loadStyle == .expanded else { return .none }
        let dailyTotals = Array(HydrationEntry.dailyTotals(from: entries, goalML: activeGoal?.targetML ?? 3000).prefix(7))
        return .hydration(dailyTotals.flatMap { total in
            let logged = min(total.totalVolume, total.goalVolume)
            var points: [HealthMetricWidgetHydrationPoint] = []
            if logged > 0 {
                points.append(.init(id: "\(total.date.timeIntervalSinceReferenceDate)-logged", date: total.date, kind: .logged, value: logged))
            }
            if total.remainingVolume > 0 {
                points.append(.init(id: "\(total.date.timeIntervalSinceReferenceDate)-remaining", date: total.date, kind: .remaining, value: total.remainingVolume))
            }
            if total.overGoalVolume > 0 {
                points.append(.init(id: "\(total.date.timeIntervalSinceReferenceDate)-over-goal", date: total.date, kind: .overGoal, value: total.overGoalVolume))
            }
            return points
        })
    }

    private func loadHeartRateRangeChartContent(context: ModelContext, loadStyle: LoadStyle) -> HealthMetricWidgetChartContent {
        let summaryEntries = (try? context.fetch(HealthHeart.summary)) ?? []
        return rangeChartContent(
            summaryEntries.compactMap { entry in
                guard let low = entry.minHeartRate, let high = entry.maxHeartRate else { return nil }
                return HealthMetricWidgetRangePoint(date: entry.date, low: low, high: high)
            },
            loadStyle: loadStyle
        )
    }

    private func loadRespiratoryRangeChartContent(context: ModelContext, loadStyle: LoadStyle) -> HealthMetricWidgetChartContent {
        let summaryEntries = (try? context.fetch(HealthRespiratoryRate.summary)) ?? []
        return rangeChartContent(
            summaryEntries.compactMap { entry in
                guard let low = entry.minRate, let high = entry.maxRate else { return nil }
                return HealthMetricWidgetRangePoint(date: entry.date, low: low, high: high)
            },
            loadStyle: loadStyle
        )
    }

    private func loadHeartLineChartContent(context: ModelContext, loadStyle: LoadStyle, value: (HealthHeart) -> Double?) -> HealthMetricWidgetChartContent {
        let summaryEntries = (try? context.fetch(HealthHeart.summary)) ?? []
        return lineChartContent(
            summaryEntries.compactMap { entry in
                value(entry).map { HealthMetricWidgetValuePoint(date: entry.date, value: $0) }
            },
            loadStyle: loadStyle
        )
    }

    private func loadWristTemperatureChartContent(context: ModelContext, settings: AppSettingsSnapshot, loadStyle: LoadStyle) -> HealthMetricWidgetChartContent {
        let summaryEntries = (try? context.fetch(HealthWristTemperature.summary)) ?? []
        return lineChartContent(
            summaryEntries.map { HealthMetricWidgetValuePoint(date: $0.date, value: settings.temperatureUnit.fromCelsius($0.temperature)) },
            loadStyle: loadStyle
        )
    }

    private func lineChartContent(_ points: [HealthMetricWidgetValuePoint], loadStyle: LoadStyle) -> HealthMetricWidgetChartContent {
        return .line(points.sorted { $0.date < $1.date })
    }

    private func rangeChartContent(_ points: [HealthMetricWidgetRangePoint], loadStyle: LoadStyle) -> HealthMetricWidgetChartContent {
        return .range(points.sorted { $0.date < $1.date })
    }

    private func sampleEntry(for metric: HealthMetricWidgetKind) -> HealthMetricWidgetEntry {
        switch metric {
        case .weight:
            return .init(
                date: .now,
                metric: .weight,
                latestDateText: String(localized: "Today"),
                content: .weight(goalLabelText: String(localized: "Goal:"), goalValueText: "180 lb", valueText: "182.4", unitText: "lb"),
                chartContent: .weight(sampleValuePoints([180.6, 180.3, 181.1, 180.7, 181.4, 182.0, 182.4]))
            )
        case .sleep:
            return .init(
                date: .now,
                metric: .sleep,
                latestDateText: String(localized: "Today"),
                content: .sleep(goalLabelText: String(localized: "Goal:"), goalValueText: "8h", duration: 7 * 3_600 + 22 * 60),
                chartContent: .sleep(sampleValuePoints([6.8 * 3_600, 7.1 * 3_600, 6.4 * 3_600, 7.6 * 3_600, 7.0 * 3_600, 6.9 * 3_600, 7.37 * 3_600]))
            )
        case .steps:
            return .init(
                date: .now,
                metric: .steps,
                latestDateText: String(localized: "Today"),
                content: .steps(goalLabelText: String(localized: "Goal:"), goalValueText: "10k", stepCount: 8421),
                chartContent: .steps(sampleValuePoints([6200, 9100, 10400, 7400, 11350, 9800, 8421]))
            )
        case .energy:
            return .init(
                date: .now,
                metric: .energy,
                latestDateText: String(localized: "Today"),
                content: .energy(activeText: "620", totalText: "2,380"),
                chartContent: .energy(sampleEnergyPoints(active: [540, 610, 720, 450, 810, 690, 620], resting: [1680, 1710, 1695, 1705, 1720, 1715, 1760]))
            )
        case .hydration:
            return .init(
                date: .now,
                metric: .hydration,
                latestDateText: String(localized: "Today"),
                content: .hydration(goalText: "3,000", totalText: "2,450", unitText: "mL"),
                chartContent: .hydration(sampleHydrationPoints(totals: [1800, 2600, 3200, 2100, 2900, 3400, 2450], goal: 3000))
            )
        case .heartRate:
            return .init(date: .now, metric: .heartRate, latestDateText: String(localized: "Today"), content: .vital(valueText: "58-142", unitText: "bpm"), chartContent: .range(sampleRangePoints(low: [54, 56, 52, 58, 55, 57, 58], high: [136, 148, 131, 142, 139, 150, 142])))
        case .restingHeartRate:
            return .init(date: .now, metric: .restingHeartRate, latestDateText: String(localized: "Today"), content: .vital(valueText: "58", unitText: "bpm"), chartContent: .line(sampleValuePoints([61, 60, 59, 60, 58, 57, 58])))
        case .walkingHeartRate:
            return .init(date: .now, metric: .walkingHeartRate, latestDateText: String(localized: "Today"), content: .vital(valueText: "92", unitText: "bpm"), chartContent: .line(sampleValuePoints([88, 91, 89, 94, 90, 93, 92])))
        case .heartRateVariability:
            return .init(date: .now, metric: .heartRateVariability, latestDateText: String(localized: "Today"), content: .vital(valueText: "47", unitText: "ms"), chartContent: .line(sampleValuePoints([42, 45, 39, 48, 44, 46, 47])))
        case .respiratoryRate:
            return .init(date: .now, metric: .respiratoryRate, latestDateText: String(localized: "Today"), content: .vital(valueText: "13.4-17.2", unitText: "br/min"), chartContent: .range(sampleRangePoints(low: [12.8, 13.1, 12.9, 13.5, 13.0, 13.2, 13.4], high: [16.8, 17.1, 16.7, 17.4, 16.9, 17.0, 17.2])))
        case .wristTemperature:
            return .init(date: .now, metric: .wristTemperature, latestDateText: String(localized: "Today"), content: .vital(valueText: "97.6", unitText: "F"), chartContent: .line(sampleValuePoints([97.2, 97.5, 97.4, 97.8, 97.3, 97.7, 97.6])))
        }
    }

    private func sampleValuePoints(_ values: [Double]) -> [HealthMetricWidgetValuePoint] {
        let calendar = Calendar.autoupdatingCurrent
        return values.enumerated().map { index, value in
            let dayOffset = index - (values.count - 1)
            let date = calendar.date(byAdding: .day, value: dayOffset, to: .now) ?? .now
            return HealthMetricWidgetValuePoint(date: date, value: value)
        }
    }

    private func sampleEnergyPoints(active: [Double], resting: [Double]) -> [HealthMetricWidgetEnergyPoint] {
        let calendar = Calendar.autoupdatingCurrent
        return zip(active, resting).enumerated().flatMap { index, pair in
            let dayOffset = index - (active.count - 1)
            let date = calendar.date(byAdding: .day, value: dayOffset, to: .now) ?? .now
            return [
                HealthMetricWidgetEnergyPoint(id: "\(date.timeIntervalSinceReferenceDate)-active", date: date, kind: .active, value: pair.0),
                HealthMetricWidgetEnergyPoint(id: "\(date.timeIntervalSinceReferenceDate)-resting", date: date, kind: .resting, value: pair.1)
            ]
        }
    }

    private func sampleHydrationPoints(totals: [Double], goal: Double) -> [HealthMetricWidgetHydrationPoint] {
        let calendar = Calendar.autoupdatingCurrent
        return totals.enumerated().flatMap { index, total in
            let dayOffset = index - (totals.count - 1)
            let date = calendar.date(byAdding: .day, value: dayOffset, to: .now) ?? .now
            let logged = min(total, goal)
            var points: [HealthMetricWidgetHydrationPoint] = []
            if logged > 0 {
                points.append(.init(id: "\(date.timeIntervalSinceReferenceDate)-logged", date: date, kind: .logged, value: logged))
            }
            if total < goal {
                points.append(.init(id: "\(date.timeIntervalSinceReferenceDate)-remaining", date: date, kind: .remaining, value: goal - total))
            }
            if total > goal {
                points.append(.init(id: "\(date.timeIntervalSinceReferenceDate)-over-goal", date: date, kind: .overGoal, value: total - goal))
            }
            return points
        }
    }

    private func sampleRangePoints(low: [Double], high: [Double]) -> [HealthMetricWidgetRangePoint] {
        let calendar = Calendar.autoupdatingCurrent
        return zip(low, high).enumerated().map { index, pair in
            let dayOffset = index - (low.count - 1)
            let date = calendar.date(byAdding: .day, value: dayOffset, to: .now) ?? .now
            return HealthMetricWidgetRangePoint(date: date, low: pair.0, high: pair.1)
        }
    }
}

struct HealthWeightWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: HealthMetricWidgetKind.weight.widgetKind, provider: HealthMetricWidgetProvider(metric: .weight)) { entry in
            HealthMetricWidgetView(entry: entry)
        }
        .configurationDisplayName(HealthMetricWidgetKind.weight.displayName)
        .description(HealthMetricWidgetKind.weight.description)
        .supportedFamilies([.systemSmall, .systemMedium])
        .containerBackgroundRemovable()
    }
}

struct HealthSleepWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: HealthMetricWidgetKind.sleep.widgetKind, provider: HealthMetricWidgetProvider(metric: .sleep)) { entry in
            HealthMetricWidgetView(entry: entry)
        }
        .configurationDisplayName(HealthMetricWidgetKind.sleep.displayName)
        .description(HealthMetricWidgetKind.sleep.description)
        .supportedFamilies([.systemSmall, .systemMedium])
        .containerBackgroundRemovable()
    }
}

struct HealthStepsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: HealthMetricWidgetKind.steps.widgetKind, provider: HealthMetricWidgetProvider(metric: .steps)) { entry in
            HealthMetricWidgetView(entry: entry)
        }
        .configurationDisplayName(HealthMetricWidgetKind.steps.displayName)
        .description(HealthMetricWidgetKind.steps.description)
        .supportedFamilies([.systemSmall, .systemMedium])
        .containerBackgroundRemovable()
    }
}

struct HealthEnergyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: HealthMetricWidgetKind.energy.widgetKind, provider: HealthMetricWidgetProvider(metric: .energy)) { entry in
            HealthMetricWidgetView(entry: entry)
        }
        .configurationDisplayName(HealthMetricWidgetKind.energy.displayName)
        .description(HealthMetricWidgetKind.energy.description)
        .supportedFamilies([.systemSmall, .systemMedium])
        .containerBackgroundRemovable()
    }
}

struct HealthHydrationWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: HealthMetricWidgetKind.hydration.widgetKind, provider: HealthMetricWidgetProvider(metric: .hydration)) { entry in
            HealthMetricWidgetView(entry: entry)
        }
        .configurationDisplayName(HealthMetricWidgetKind.hydration.displayName)
        .description(HealthMetricWidgetKind.hydration.description)
        .supportedFamilies([.systemSmall, .systemMedium])
        .containerBackgroundRemovable()
    }
}

struct HealthHeartRateWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: HealthMetricWidgetKind.heartRate.widgetKind, provider: HealthMetricWidgetProvider(metric: .heartRate)) { entry in
            HealthMetricWidgetView(entry: entry)
        }
        .configurationDisplayName(HealthMetricWidgetKind.heartRate.displayName)
        .description(HealthMetricWidgetKind.heartRate.description)
        .supportedFamilies([.systemSmall, .systemMedium])
        .containerBackgroundRemovable()
    }
}

struct HealthRestingHeartRateWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: HealthMetricWidgetKind.restingHeartRate.widgetKind, provider: HealthMetricWidgetProvider(metric: .restingHeartRate)) { entry in
            HealthMetricWidgetView(entry: entry)
        }
        .configurationDisplayName(HealthMetricWidgetKind.restingHeartRate.displayName)
        .description(HealthMetricWidgetKind.restingHeartRate.description)
        .supportedFamilies([.systemSmall, .systemMedium])
        .containerBackgroundRemovable()
    }
}

struct HealthWalkingHeartRateWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: HealthMetricWidgetKind.walkingHeartRate.widgetKind, provider: HealthMetricWidgetProvider(metric: .walkingHeartRate)) { entry in
            HealthMetricWidgetView(entry: entry)
        }
        .configurationDisplayName(HealthMetricWidgetKind.walkingHeartRate.displayName)
        .description(HealthMetricWidgetKind.walkingHeartRate.description)
        .supportedFamilies([.systemSmall, .systemMedium])
        .containerBackgroundRemovable()
    }
}

struct HealthHeartRateVariabilityWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: HealthMetricWidgetKind.heartRateVariability.widgetKind, provider: HealthMetricWidgetProvider(metric: .heartRateVariability)) { entry in
            HealthMetricWidgetView(entry: entry)
        }
        .configurationDisplayName(HealthMetricWidgetKind.heartRateVariability.displayName)
        .description(HealthMetricWidgetKind.heartRateVariability.description)
        .supportedFamilies([.systemSmall, .systemMedium])
        .containerBackgroundRemovable()
    }
}

struct HealthRespiratoryRateWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: HealthMetricWidgetKind.respiratoryRate.widgetKind, provider: HealthMetricWidgetProvider(metric: .respiratoryRate)) { entry in
            HealthMetricWidgetView(entry: entry)
        }
        .configurationDisplayName(HealthMetricWidgetKind.respiratoryRate.displayName)
        .description(HealthMetricWidgetKind.respiratoryRate.description)
        .supportedFamilies([.systemSmall, .systemMedium])
        .containerBackgroundRemovable()
    }
}

struct HealthWristTemperatureWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: HealthMetricWidgetKind.wristTemperature.widgetKind, provider: HealthMetricWidgetProvider(metric: .wristTemperature)) { entry in
            HealthMetricWidgetView(entry: entry)
        }
        .configurationDisplayName(HealthMetricWidgetKind.wristTemperature.displayName)
        .description(HealthMetricWidgetKind.wristTemperature.description)
        .supportedFamilies([.systemSmall, .systemMedium])
        .containerBackgroundRemovable()
    }
}

private struct HealthMetricWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: HealthMetricWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                mediumView
            default:
                smallView
            }
        }
        .containerBackground(.background, for: .widget)
        .widgetURL(entry.metric.widgetURL)
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: entry.metric.isVitalMetric ? 8 : 0) {
            header(showsDate: false)

            Spacer()
            metricContent

            if entry.metric.isVitalMetric {
                Spacer(minLength: 4)
                mediumChart
                    .frame(height: 44)
                    .accessibilityHidden(true)
            }
        }
    }

    private var mediumView: some View {
        VStack(spacing: 0) {
            header(showsDate: !entry.metric.omitsDateDisplay)
            Spacer()
            HStack(alignment: .bottom, spacing: 0) {
                metricContent

                Spacer()

                mediumChart
                    .frame(width: 140, height: 100)
            }
        }
    }

    @ViewBuilder
    private var metricContent: some View {
        switch entry.content {
        case let .weight(goalLabelText, goalValueText, valueText, unitText):
            weightContent(goalLabelText: goalLabelText, goalValueText: goalValueText, valueText: valueText, unitText: unitText)
        case let .sleep(goalLabelText, goalValueText, duration):
            HealthMetricWidgetSleepDurationView(goalLabelText: goalLabelText, goalValueText: goalValueText, duration: duration)
        case let .steps(goalLabelText, goalValueText, stepCount):
            stepsContent(goalLabelText: goalLabelText, goalValueText: goalValueText, stepCount: stepCount)
        case let .energy(activeText, totalText):
            energyContent(activeText: activeText, totalText: totalText)
        case let .hydration(goalText, totalText, unitText):
            hydrationContent(goalText: goalText, totalText: totalText, unitText: unitText)
        case let .vital(valueText, unitText):
            vitalContent(valueText: valueText, unitText: unitText)
        case let .empty(message):
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .fontWeight(.semibold)
        }
    }

    @ViewBuilder
    private var mediumChart: some View {
        switch entry.chartContent {
        case let .weight(points):
            if points.count > 1 {
                HealthMetricWidgetWeightChart(points: points, tint: entry.metric.tint)
            }
        case let .sleep(points):
            if points.count > 1 {
                HealthMetricWidgetSleepChart(points: points, tint: entry.metric.tint)
            }
        case let .steps(points):
            HealthMetricWidgetStepsChart(points: points, tint: entry.metric.tint)
        case let .energy(points):
            HealthMetricWidgetEnergyChart(points: points, tint: entry.metric.tint)
        case let .hydration(points):
            HealthMetricWidgetHydrationChart(points: points, tint: entry.metric.tint)
        case let .line(points):
            if points.count > 1 {
                HealthMetricWidgetLineChart(points: points, tint: entry.metric.tint)
            }
        case let .range(points):
            HealthMetricWidgetRangeChart(points: points, tint: entry.metric.tint)
        case .none:
            EmptyView()
        }
    }

    private func header(showsDate: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            HStack(spacing: 3) {
                Image(systemName: entry.metric.symbolName)
                    .font(.subheadline)
                    .foregroundStyle(entry.metric.tint.gradient)
                    .accessibilityHidden(true)
            Text(entry.metric.title)
                .fontWeight(.semibold)
                .foregroundStyle(entry.metric.tint.gradient)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            }

            Spacer()

            if showsDate, let latestDateText = entry.latestDateText {
                Text(latestDateText)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func weightContent(goalLabelText: String?, goalValueText: String?, valueText: String, unitText: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let goalValueText {
                goalLine(labelText: goalLabelText, valueText: goalValueText)
            }

            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(valueText)
                    .font(.largeTitle)
                    .bold()
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.8)

                Text(unitText)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .minimumScaleFactor(0.5)
            }
            .lineLimit(1)
            .fontDesign(.rounded)
        }
    }

    @ViewBuilder
    private func stepsContent(goalLabelText: String?, goalValueText: String?, stepCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let goalValueText {
                goalLine(labelText: goalLabelText, valueText: goalValueText)
            }

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(stepCount, format: .number)
                    .font(.largeTitle)
                    .fontDesign(.rounded)
                    .bold()
                    .minimumScaleFactor(0.8)

                if shouldShowStepsUnit(for: stepCount) {
                    Text(stepCount == 1 ? String(localized: "Step") : String(localized: "Steps"))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .minimumScaleFactor(0.5)
                }
            }
            .lineLimit(1)
        }
    }

    @ViewBuilder
    private func goalLine(labelText: String?, valueText: String) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 3) {
            if let labelText {
                Text(labelText)
                    .foregroundStyle(.secondary)
            }

            Text(valueText)
        }
        .font(.subheadline)
        .fontWeight(.semibold)
        .minimumScaleFactor(0.5)
        .lineLimit(1)
    }

    @ViewBuilder
    private func energyContent(activeText: String, totalText: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(activeText)
                    .font(.title3)
                    .bold()
                    .minimumScaleFactor(0.8)

                Text(String(localized: "Active"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .minimumScaleFactor(0.5)
            }
            .lineLimit(1)

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(totalText)
                    .font(.largeTitle)
                    .bold()
                    .minimumScaleFactor(0.7)

                Text(String(localized: "Total"))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .minimumScaleFactor(0.4)
            }
            .lineLimit(1)
        }
        .fontDesign(.rounded)
    }

    @ViewBuilder
    private func hydrationContent(goalText: String?, totalText: String, unitText: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            if let goalText {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(goalText)
                        .font(.title3)
                        .bold()
                        .minimumScaleFactor(0.8)

                    Text(String(localized: "Goal"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .minimumScaleFactor(0.5)
                }
                .lineLimit(1)
            }

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(totalText)
                    .font(.largeTitle)
                    .bold()
                    .minimumScaleFactor(0.7)

                Text(unitText)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .minimumScaleFactor(0.4)
            }
            .lineLimit(1)
        }
        .fontDesign(.rounded)
    }

    private func shouldShowStepsUnit(for stepCount: Int) -> Bool {
        switch family {
        case .systemSmall:
            return stepCount < 1_000
        case .systemMedium:
            return stepCount < 10_000
        default:
            return true
        }
    }

    private func vitalContent(valueText: String, unitText: String) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 3) {
            Text(valueText)
                .font(family == .systemSmall ? .title2 : .largeTitle)
                .bold()
                .fontDesign(.rounded)
                .minimumScaleFactor(0.7)

            Text(unitText)
                .font(family == .systemSmall ? .subheadline : .title2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .minimumScaleFactor(0.5)
        }
        .lineLimit(1)
    }
}

private struct HealthMetricWidgetSleepDurationView: View {
    let goalLabelText: String?
    let goalValueText: String?
    let duration: TimeInterval

    private var hours: Int { Int((duration / 3_600).rounded(.down)) }
    private var minutes: Int { max(0, Int((duration / 60).rounded()) - (hours * 60)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let goalValueText {
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    if let goalLabelText {
                        Text(goalLabelText)
                            .foregroundStyle(.secondary)
                    }

                    Text(goalValueText)
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            }

            HStack(alignment: .lastTextBaseline, spacing: 0) {
                if hours > 0 {
                    HStack(alignment: .lastTextBaseline, spacing: 0) {
                        Text(hours, format: .number)
                            .font(.largeTitle)
                            .minimumScaleFactor(0.7)
                        Text(String(localized: "hr"))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .minimumScaleFactor(0.4)
                    }
                    .padding(.trailing, 2)
                }

                HStack(alignment: .lastTextBaseline, spacing: 0) {
                    Text(minutes, format: .number)
                        .font(.largeTitle)
                        .minimumScaleFactor(0.7)
                    Text(String(localized: "min"))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .minimumScaleFactor(0.4)
                }
            }
            .lineLimit(1)
            .bold()
            .fontDesign(.rounded)
        }
    }
}

private func widgetFormattedSleepWakeDay(_ wakeDay: Date) -> String {
    formattedRecentDay(HealthSleepNight.displayDate(forWakeDay: wakeDay))
}

private func widgetFormattedSleepGoalDuration(_ duration: TimeInterval) -> String {
    let totalMinutes = Int((duration / 60).rounded())
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60

    if hours > 0 && minutes > 0 {
        return "\(hours)h \(minutes)m"
    }

    if hours > 0 {
        return "\(hours)h"
    }

    return "\(minutes)m"
}

private func widgetFormattedHydration(_ ml: Double, unit: HydrationUnit) -> String {
    let converted = unit.fromML(ml)
    return Int(converted.rounded()).formatted(.number)
}

private func widgetCompactStepsText(_ steps: Int) -> String {
    steps.formatted(.number.notation(.compactName).precision(.fractionLength(0...1))).lowercased()
}

private struct HealthMetricWidgetWeightChart: View {
    let points: [HealthMetricWidgetValuePoint]
    let tint: Color

    private var latestDate: Date? { points.last?.date }

    private var yDomain: ClosedRange<Double> {
        widgetYDomain(for: points.map(\.value), minimumPadding: 0.5)
    }

    var body: some View {
        Chart {
            ForEach(points) { point in
                LineMark(x: .value(String(localized: "Date"), point.date), y: .value(String(localized: "Weight"), point.value))
                    .foregroundStyle(tint)
                    .lineStyle(.init(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
            }

            if let latestDate, let latestPoint = points.last {
                PointMark(x: .value(String(localized: "Latest Date"), latestDate), y: .value(String(localized: "Latest Weight"), latestPoint.value))
                    .foregroundStyle(tint.opacity(0.2))
                    .symbolSize(280)

                PointMark(x: .value(String(localized: "Latest Date"), latestDate), y: .value(String(localized: "Latest Weight"), latestPoint.value))
                    .foregroundStyle(.white)
                    .symbolSize(120)

                PointMark(x: .value(String(localized: "Latest Date"), latestDate), y: .value(String(localized: "Latest Weight"), latestPoint.value))
                    .foregroundStyle(tint)
                    .symbolSize(64)
            }
        }
        .chartYScale(domain: yDomain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }
}

private struct HealthMetricWidgetLineChart: View {
    let points: [HealthMetricWidgetValuePoint]
    let tint: Color

    private var latestPoint: HealthMetricWidgetValuePoint? { points.last }

    private var yDomain: ClosedRange<Double> {
        widgetYDomain(for: points.map(\.value), minimumPadding: 1)
    }

    var body: some View {
        Chart {
            ForEach(points) { point in
                LineMark(x: .value(String(localized: "Date"), point.date), y: .value(String(localized: "Value"), point.value))
                    .foregroundStyle(tint)
                    .lineStyle(.init(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
            }

            if let latestPoint {
                PointMark(x: .value(String(localized: "Latest Date"), latestPoint.date), y: .value(String(localized: "Latest Value"), latestPoint.value))
                    .foregroundStyle(tint.opacity(0.2))
                    .symbolSize(180)

                PointMark(x: .value(String(localized: "Latest Date"), latestPoint.date), y: .value(String(localized: "Latest Value"), latestPoint.value))
                    .foregroundStyle(.white)
                    .symbolSize(84)

                PointMark(x: .value(String(localized: "Latest Date"), latestPoint.date), y: .value(String(localized: "Latest Value"), latestPoint.value))
                    .foregroundStyle(tint)
                    .symbolSize(44)
            }
        }
        .chartYScale(domain: yDomain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
    }
}

private struct HealthMetricWidgetRangeChart: View {
    let points: [HealthMetricWidgetRangePoint]
    let tint: Color

    private var latestDate: Date? { points.last?.date }

    private var yDomain: ClosedRange<Double> {
        widgetYDomain(for: points.flatMap { [$0.low, $0.high] }, minimumPadding: 1)
    }

    var body: some View {
        Chart(points) { point in
            BarMark(
                x: .value(String(localized: "Date"), point.date, unit: .day),
                yStart: .value(String(localized: "Low"), point.low),
                yEnd: .value(String(localized: "High"), point.high),
                width: .ratio(0.45)
            )
            .foregroundStyle(point.date == latestDate ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(tint.opacity(0.3).gradient))
            .clipShape(Capsule())
        }
        .chartYScale(domain: yDomain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
    }
}

private struct HealthMetricWidgetSleepChart: View {
    let points: [HealthMetricWidgetValuePoint]
    let tint: Color

    private var latestDate: Date? { points.last?.date }

    private var yDomain: ClosedRange<Double> {
        0...max(points.map(\.value).max() ?? 0, 1) * 1.15
    }

    var body: some View {
        Chart(points) { point in
            BarMark(x: .value(String(localized: "Wake Day"), point.date, unit: .day), y: .value(String(localized: "Time Asleep"), point.value), width: .ratio(0.92))
                .foregroundStyle(point.date == latestDate ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(tint.opacity(0.3).gradient))
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4))
        }
        .chartYScale(domain: yDomain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
    }
}

private struct HealthMetricWidgetStepsChart: View {
    let points: [HealthMetricWidgetValuePoint]
    let tint: Color

    private var latestDate: Date? { points.last?.date }

    private var yDomain: ClosedRange<Double> {
        0...max(points.map(\.value).max() ?? 0, 1) * 1.15
    }

    var body: some View {
        Chart(points) { point in
            BarMark(x: .value(String(localized: "Date"), point.date, unit: .day), y: .value(String(localized: "Steps"), point.value), width: .ratio(0.92))
                .foregroundStyle(point.date == latestDate ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(tint.opacity(0.3).gradient))
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4))
        }
        .chartYScale(domain: yDomain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
    }
}

private struct HealthMetricWidgetEnergyChart: View {
    let points: [HealthMetricWidgetEnergyPoint]
    let tint: Color

    private var latestDate: Date? {
        points.map(\.date).max()
    }

    private var yDomain: ClosedRange<Double> {
        let totalsByDate = Dictionary(grouping: points, by: \.date)
            .mapValues { $0.reduce(0) { $0 + $1.value } }
        return 0...(max(totalsByDate.values.max() ?? 0, 1) * 1.15)
    }

    var body: some View {
        Chart(points) { point in
            BarMark(x: .value(String(localized: "Date"), point.date, unit: .day), y: .value(energyKindLabel(point.kind), point.value), width: .ratio(0.92))
                .foregroundStyle(barStyle(for: point))
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: point.kind == .active ? 1 : 4, topTrailingRadius: point.kind == .active ? 1 : 4))
        }
        .chartYScale(domain: yDomain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
    }

    private func barStyle(for point: HealthMetricWidgetEnergyPoint) -> AnyShapeStyle {
        let isLatest = point.date == latestDate
        switch point.kind {
        case .active:
            return isLatest ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(tint.opacity(0.35).gradient)
        case .resting:
            return isLatest ? AnyShapeStyle(tint.opacity(0.22).gradient) : AnyShapeStyle(tint.opacity(0.1).gradient)
        }
    }

    private func energyKindLabel(_ kind: HealthMetricWidgetEnergyPoint.Kind) -> String {
        switch kind {
        case .active:
            return String(localized: "Active")
        case .resting:
            return String(localized: "Resting")
        }
    }
}

private struct HealthMetricWidgetHydrationChart: View {
    let points: [HealthMetricWidgetHydrationPoint]
    let tint: Color

    private var latestDate: Date? {
        points.map(\.date).max()
    }

    private var yDomain: ClosedRange<Double> {
        let totalsByDate = Dictionary(grouping: points, by: \.date)
            .mapValues { $0.reduce(0) { $0 + $1.value } }
        return 0...(max(totalsByDate.values.max() ?? 0, 1) * 1.15)
    }

    var body: some View {
        Chart(points) { point in
            BarMark(x: .value(String(localized: "Date"), point.date, unit: .day), y: .value(hydrationKindLabel(point.kind), point.value), width: .ratio(0.92))
                .foregroundStyle(barStyle(for: point))
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: point.kind == .remaining || point.kind == .overGoal ? 4 : 1, topTrailingRadius: point.kind == .remaining || point.kind == .overGoal ? 4 : 1))
        }
        .chartYScale(domain: yDomain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
    }

    private func barStyle(for point: HealthMetricWidgetHydrationPoint) -> AnyShapeStyle {
        let isLatest = point.date == latestDate
        switch point.kind {
        case .logged:
            return isLatest ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(tint.opacity(0.35).gradient)
        case .remaining:
            return isLatest ? AnyShapeStyle(tint.opacity(0.18).gradient) : AnyShapeStyle(tint.opacity(0.08).gradient)
        case .overGoal:
            return isLatest ? AnyShapeStyle(Color.cyan.gradient) : AnyShapeStyle(Color.cyan.opacity(0.35).gradient)
        }
    }

    private func hydrationKindLabel(_ kind: HealthMetricWidgetHydrationPoint.Kind) -> String {
        switch kind {
        case .logged:
            return String(localized: "Water")
        case .remaining:
            return String(localized: "Remaining")
        case .overGoal:
            return String(localized: "Over Goal")
        }
    }
}

private func widgetYDomain(for values: [Double], minimumPadding: Double) -> ClosedRange<Double> {
    guard let minimum = values.min(), let maximum = values.max() else {
        return 0...1
    }

    if minimum == maximum {
        let padding = max(abs(minimum) * 0.05, minimumPadding)
        return (minimum - padding)...(maximum + padding)
    }

    let range = maximum - minimum
    let padding = max(range * 0.15, minimumPadding)
    return (minimum - padding)...(maximum + padding)
}

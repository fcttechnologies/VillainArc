import Charts
import SwiftData
import SwiftUI
import WidgetKit

private enum HealthMetricWidgetKind {
    case weight
    case sleep
    case steps
    case energy

    var widgetKind: String {
        switch self {
        case .weight: "HealthWeightWidget"
        case .sleep: "HealthSleepWidget"
        case .steps: "HealthStepsWidget"
        case .energy: "HealthEnergyWidget"
        }
    }

    var title: String {
        switch self {
        case .weight: "Weight"
        case .sleep: "Sleep"
        case .steps: "Steps"
        case .energy: "Energy"
        }
    }

    var symbolName: String {
        switch self {
        case .weight: "scalemass.fill"
        case .sleep: "bed.double.fill"
        case .steps: "figure.walk"
        case .energy: "flame.fill"
        }
    }

    var tint: Color {
        switch self {
        case .weight: .blue
        case .sleep: .indigo
        case .steps: .red
        case .energy: .orange
        }
    }

    var displayName: String {
        switch self {
        case .weight: "Weight"
        case .sleep: "Sleep"
        case .steps: "Steps"
        case .energy: "Energy"
        }
    }

    var description: String {
        switch self {
        case .weight: "Shows your latest weight and current goal."
        case .sleep: "Shows your latest sleep duration."
        case .steps: "Shows your latest steps entry and current goal."
        case .energy: "Shows your latest active and total energy."
        }
    }

    var emptyMessage: String {
        switch self {
        case .weight: "Add or sync a weight entry to see it here."
        case .sleep: "Sleep data will appear here after your next sync."
        case .steps: "Steps data will appear here after your next sync."
        case .energy: "Energy data will appear here after your next sync."
        }
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
        }
    }
}

private enum HealthMetricWidgetContent {
    case weight(goalLabelText: String?, goalValueText: String?, valueText: String, unitText: String)
    case sleep(duration: TimeInterval)
    case steps(goalLabelText: String?, goalValueText: String?, stepCount: Int)
    case energy(activeText: String, totalText: String)
    case empty(message: String)
}

private enum HealthMetricWidgetChartContent {
    case weight([HealthMetricWidgetValuePoint])
    case sleep([HealthMetricWidgetValuePoint])
    case steps([HealthMetricWidgetValuePoint])
    case energy([HealthMetricWidgetEnergyPoint])
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

private struct HealthMetricWidgetEntry: TimelineEntry {
    let date: Date
    let metric: HealthMetricWidgetKind
    let latestDateText: String?
    let content: HealthMetricWidgetContent
    let chartContent: HealthMetricWidgetChartContent
}

private struct HealthMetricWidgetProvider: TimelineProvider {
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
        completion(Timeline(entries: [entry], policy: .never))
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
                    goalValueText = "Maintain"
                } else {
                    goalLabelText = "Goal:"
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
            guard let latestEntry else {
                return .init(date: .now, metric: .sleep, latestDateText: nil, content: .empty(message: metric.emptyMessage), chartContent: .none)
            }

            return .init(
                date: .now,
                metric: .sleep,
                latestDateText: widgetFormattedSleepWakeDay(latestEntry.wakeDay),
                content: .sleep(duration: latestEntry.timeAsleep),
                chartContent: loadSleepChartContent(context: context, loadStyle: loadStyle)
            )

        case .steps:
            let latestEntry = try? context.fetch(HealthStepsDistance.latest).first
            let todayEntry = try? context.fetch(HealthStepsDistance.forDay(.now)).first
            let activeGoal = try? context.fetch(StepsGoal.active).first
            guard let latestEntry else {
                return .init(date: .now, metric: .steps, latestDateText: nil, content: .empty(message: metric.emptyMessage), chartContent: .none)
            }

            let goalLabelText: String?
            let goalValueText: String?
            if let activeGoal {
                if todayEntry?.goalCompleted == true {
                    goalLabelText = nil
                    goalValueText = "Goal achieved"
                } else {
                    goalLabelText = "Goal:"
                    goalValueText = widgetCompactStepsText(activeGoal.targetSteps)
                }
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

    private func sampleEntry(for metric: HealthMetricWidgetKind) -> HealthMetricWidgetEntry {
        switch metric {
        case .weight:
            return .init(
                date: .now,
                metric: .weight,
                latestDateText: "Today",
                content: .weight(goalLabelText: "Goal:", goalValueText: "180 lb", valueText: "182.4", unitText: "lb"),
                chartContent: .weight(sampleValuePoints([180.6, 180.3, 181.1, 180.7, 181.4, 182.0, 182.4]))
            )
        case .sleep:
            return .init(
                date: .now,
                metric: .sleep,
                latestDateText: "Today",
                content: .sleep(duration: 7 * 3_600 + 22 * 60),
                chartContent: .sleep(sampleValuePoints([6.8 * 3_600, 7.1 * 3_600, 6.4 * 3_600, 7.6 * 3_600, 7.0 * 3_600, 6.9 * 3_600, 7.37 * 3_600]))
            )
        case .steps:
            return .init(
                date: .now,
                metric: .steps,
                latestDateText: "Today",
                content: .steps(goalLabelText: "Goal:", goalValueText: "10k", stepCount: 8421),
                chartContent: .steps(sampleValuePoints([6200, 9100, 10400, 7400, 11350, 9800, 8421]))
            )
        case .energy:
            return .init(
                date: .now,
                metric: .energy,
                latestDateText: "Today",
                content: .energy(activeText: "620", totalText: "2,380"),
                chartContent: .energy(sampleEnergyPoints(active: [540, 610, 720, 450, 810, 690, 620], resting: [1680, 1710, 1695, 1705, 1720, 1715, 1760]))
            )
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
        VStack(alignment: .leading, spacing: 0) {
            header(showsDate: false)

            Spacer()
            metricContent
        }
    }

    private var mediumView: some View {
        VStack(spacing: 0) {
            header(showsDate: true)
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
        case let .sleep(duration):
            HealthMetricWidgetSleepDurationView(duration: duration)
        case let .steps(goalLabelText, goalValueText, stepCount):
            stepsContent(goalLabelText: goalLabelText, goalValueText: goalValueText, stepCount: stepCount)
        case let .energy(activeText, totalText):
            energyContent(activeText: activeText, totalText: totalText)
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
                    Text(stepCount == 1 ? "Step" : "Steps")
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

                Text("Active")
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

                Text("Total")
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
}

private struct HealthMetricWidgetSleepDurationView: View {
    let duration: TimeInterval

    private var hours: Int { Int((duration / 3_600).rounded(.down)) }
    private var minutes: Int { max(0, Int((duration / 60).rounded()) - (hours * 60)) }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            if hours > 0 {
                HStack(alignment: .lastTextBaseline, spacing: 0) {
                    Text(hours, format: .number)
                        .font(.largeTitle)
                        .minimumScaleFactor(0.7)
                    Text("hr")
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
                Text("min")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .minimumScaleFactor(0.4)
            }
        }
        .bold()
        .fontDesign(.rounded)
        .lineLimit(1)
    }
}

private func widgetFormattedSleepWakeDay(_ wakeDay: Date) -> String {
    formattedRecentDay(HealthSleepNight.displayDate(forWakeDay: wakeDay))
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
                LineMark(x: .value("Date", point.date), y: .value("Weight", point.value))
                    .foregroundStyle(tint)
                    .lineStyle(.init(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
            }

            if let latestDate, let latestPoint = points.last {
                PointMark(x: .value("Latest Date", latestDate), y: .value("Latest Weight", latestPoint.value))
                    .foregroundStyle(tint.opacity(0.2))
                    .symbolSize(280)

                PointMark(x: .value("Latest Date", latestDate), y: .value("Latest Weight", latestPoint.value))
                    .foregroundStyle(.white)
                    .symbolSize(120)

                PointMark(x: .value("Latest Date", latestDate), y: .value("Latest Weight", latestPoint.value))
                    .foregroundStyle(tint)
                    .symbolSize(64)
            }
        }
        .chartYScale(domain: yDomain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
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
            BarMark(x: .value("Wake Day", point.date, unit: .day), y: .value("Time Asleep", point.value), width: .ratio(0.92))
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
            BarMark(x: .value("Date", point.date, unit: .day), y: .value("Steps", point.value), width: .ratio(0.92))
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
            BarMark(x: .value("Date", point.date, unit: .day), y: .value(point.kind.rawValue.capitalized, point.value), width: .ratio(0.92))
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

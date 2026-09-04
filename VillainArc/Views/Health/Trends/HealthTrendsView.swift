import FCTMetrics
import Charts
import SwiftData
import SwiftUI

enum HealthTrendRange: String, CaseIterable, Identifiable {
    case sevenDays
    case thirtyDays
    case ninetyDays
    case oneYear

    var id: String { rawValue }

    var days: Int {
        switch self {
        case .sevenDays: return 7
        case .thirtyDays: return 30
        case .ninetyDays: return 90
        case .oneYear: return 365
        }
    }

    var label: LocalizedStringResource {
        switch self {
        case .sevenDays: return "7D"
        case .thirtyDays: return "30D"
        case .ninetyDays: return "90D"
        case .oneYear: return "1Y"
        }
    }

    var fullLabel: LocalizedStringResource {
        switch self {
        case .sevenDays: return "Last 7 days"
        case .thirtyDays: return "Last 30 days"
        case .ninetyDays: return "Last 90 days"
        case .oneYear: return "Last year"
        }
    }
}

struct HealthTrendPoint: Identifiable, Equatable {
    var id: Date { date }
    let date: Date
    let value: Double
}

enum HealthTrendMetric: String, CaseIterable, Identifiable {
    case weight
    case sleep
    case restingHeartRate
    case energy
    case steps
    case workoutVolume

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .weight: return "Weight"
        case .sleep: return "Sleep"
        case .restingHeartRate: return "Resting HR"
        case .energy: return "Energy"
        case .steps: return "Steps"
        case .workoutVolume: return "Workout Volume"
        }
    }

    var systemImage: String {
        switch self {
        case .weight: return "scalemass.fill"
        case .sleep: return "bed.double.fill"
        case .restingHeartRate: return "heart.fill"
        case .energy: return "flame.fill"
        case .steps: return "figure.walk"
        case .workoutVolume: return "dumbbell.fill"
        }
    }

    var tint: Color {
        switch self {
        case .weight: return .blue
        case .sleep: return .indigo
        case .restingHeartRate: return .pink
        case .energy: return .orange
        case .steps: return .green
        case .workoutVolume: return .purple
        }
    }
}

struct HealthTrendsView: View {
    @State private var range: HealthTrendRange = .thirtyDays

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Range", selection: $range) {
                    ForEach(HealthTrendRange.allCases) { range in
                        Text(range.label).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier(AccessibilityIdentifiers.healthTrendsRangePicker)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    HealthTrendCard(metric: .weight, range: range)
                    HealthTrendCard(metric: .sleep, range: range)
                    HealthTrendCard(metric: .restingHeartRate, range: range)
                    HealthTrendCard(metric: .energy, range: range)
                    HealthTrendCard(metric: .steps, range: range)
                    HealthTrendCard(metric: .workoutVolume, range: range)
                }

                NavigationLink(value: AppRouter.Destination.correlationInsights) {
                    HStack(spacing: 8) {
                        Image(systemName: "chart.dots.scatter")
                            .foregroundStyle(.purple.gradient)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Performance Correlations")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            Text("How sleep & RPE shape session quality")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .appCardStyle()
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(AccessibilityIdentifiers.healthCorrelationLink)

                NavigationLink(value: AppRouter.Destination.sleepTimingInsights) {
                    HStack(spacing: 8) {
                        Image(systemName: "moon.stars.fill")
                            .foregroundStyle(.indigo.gradient)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sleep Timing Insights")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            Text("Bed & wake patterns, consistency score")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .appCardStyle()
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(AccessibilityIdentifiers.healthSleepTimingLink)
            }
            .padding()
        }
        .quickActionContentBottomInset()
        .appBackground()
        .navigationTitle("Trends")
        .toolbarTitleDisplayMode(.inline)
        .diagScreen(VACrumb.healthTrends)
        .onAppear { Diag.count(VACounter.healthTrendsViewed) }
    }
}

struct HealthTrendCard: View {
    let metric: HealthTrendMetric
    let range: HealthTrendRange

    @Query(WeightEntry.history) private var weightEntries: [WeightEntry]
    @Query(HealthSleepNight.history) private var sleepEntries: [HealthSleepNight]
    @Query(HealthHeart.history) private var heartEntries: [HealthHeart]
    @Query(HealthEnergy.history) private var energyEntries: [HealthEnergy]
    @Query(HealthStepsDistance.history) private var stepsEntries: [HealthStepsDistance]
    @Query(WorkoutSession.completedSession) private var workouts: [WorkoutSession]
    @Query(AppSettings.single) private var appSettings: [AppSettings]

    private var weightUnit: WeightUnit { appSettings.first?.weightUnit ?? .systemDefault }

    @State private var showDetail = false

    private var rangeStart: Date {
        Calendar.current.date(byAdding: .day, value: -range.days, to: Date()) ?? Date()
    }

    private var points: [HealthTrendPoint] {
        HealthTrendDataSource.points(for: metric, range: range, weightEntries: weightEntries, sleepEntries: sleepEntries, heartEntries: heartEntries, energyEntries: energyEntries, stepsEntries: stepsEntries, workouts: workouts, weightUnit: weightUnit)
    }

    private var currentValue: Double? { points.last?.value }
    private var sevenDayAverage: Double? {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recent = points.filter { $0.date >= cutoff }
        guard !recent.isEmpty else { return nil }
        return recent.map(\.value).reduce(0, +) / Double(recent.count)
    }

    private var oldestValue: Double? { points.first?.value }

    private var deltaText: String? {
        guard let current = currentValue, let oldest = oldestValue, points.count > 1 else { return nil }
        let delta = current - oldest
        let sign = delta >= 0 ? "+" : ""
        return "\(sign)\(formattedValue(delta, isDelta: true))"
    }

    var body: some View {
        Button {
            showDetail = true
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 3) {
                    Image(systemName: metric.systemImage)
                        .font(.caption)
                        .foregroundStyle(metric.tint.gradient)
                    Text(metric.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(metric.tint.gradient)
                }

                if let currentValue {
                    Text(formattedValue(currentValue))
                        .font(.title3)
                        .fontWeight(.bold)
                        .fontDesign(.rounded)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } else {
                    Text("—")
                        .font(.title3)
                        .fontWeight(.bold)
                        .fontDesign(.rounded)
                        .foregroundStyle(.secondary)
                }

                if points.count > 1 {
                    Chart(points) { point in
                        LineMark(x: .value("Date", point.date), y: .value("Value", point.value))
                            .foregroundStyle(metric.tint.gradient)
                            .lineStyle(.init(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                            .interpolationMethod(.catmullRom)
                    }
                    .frame(height: 40)
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .accessibilityHidden(true)
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 40)
                }

                if let deltaText {
                    Text(deltaText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(" ")
                        .font(.caption2)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .appCardStyle()
            .tint(.primary)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityIdentifiers.healthTrendCard(metric.rawValue))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(Text("Opens trend detail for \(String(localized: metric.title))"))
        .sheet(isPresented: $showDetail) {
            NavigationStack {
                HealthTrendDetailSheet(metric: metric, initialRange: range)
            }
        }
    }

    private var accessibilityLabel: Text {
        let title = String(localized: metric.title)
        guard let value = currentValue else {
            return Text("\(title). No data in selected range.")
        }
        let valueText = formattedValue(value)
        let avgPart: String
        if let avg = sevenDayAverage {
            avgPart = String(localized: "7-day average \(formattedValue(avg))")
        } else {
            avgPart = ""
        }
        return Text("\(title). Current \(valueText). \(avgPart)")
    }

    private func formattedValue(_ value: Double, isDelta: Bool = false) -> String {
        switch metric {
        case .weight:
            if isDelta {
                return formattedWeightValue(value, unit: weightUnit, fractionDigits: 0...1) + " \(weightUnit.rawValue)"
            }
            return formattedWeightText(value, unit: weightUnit, fractionDigits: 0...1)
        case .sleep:
            let totalMinutes = Int((value * 60).rounded())
            let h = totalMinutes / 60
            let m = totalMinutes % 60
            if h > 0 && m > 0 { return "\(h)h \(m)m" }
            if h > 0 { return "\(h)h" }
            return "\(m)m"
        case .restingHeartRate:
            return "\(Int(value.rounded())) bpm"
        case .energy:
            return "\(Int(value.rounded())) kcal"
        case .steps:
            return value.formatted(.number.notation(.compactName))
        case .workoutVolume:
            return formattedWeightText(value, unit: weightUnit, fractionDigits: 0...0)
        }
    }
}

enum HealthTrendDataSource {
    static func points(for metric: HealthTrendMetric, range: HealthTrendRange, weightEntries: [WeightEntry], sleepEntries: [HealthSleepNight], heartEntries: [HealthHeart], energyEntries: [HealthEnergy], stepsEntries: [HealthStepsDistance], workouts: [WorkoutSession], weightUnit: WeightUnit) -> [HealthTrendPoint] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -range.days, to: Date()) ?? Date()
        switch metric {
        case .weight:
            return weightEntries
                .filter { $0.date >= cutoff }
                .sorted { $0.date < $1.date }
                .map { HealthTrendPoint(date: $0.date, value: $0.weight) }
        case .sleep:
            return sleepEntries
                .filter { $0.wakeDay >= cutoff && $0.timeAsleep > 0 }
                .sorted { $0.wakeDay < $1.wakeDay }
                .map { HealthTrendPoint(date: HealthSleepNight.displayDate(forWakeDay: $0.wakeDay), value: $0.timeAsleep / 3600) }
        case .restingHeartRate:
            return heartEntries
                .filter { $0.date >= cutoff }
                .compactMap { entry -> HealthTrendPoint? in
                    guard let rhr = entry.restingHeartRate, rhr > 0 else { return nil }
                    return HealthTrendPoint(date: entry.date, value: rhr)
                }
                .sorted { $0.date < $1.date }
        case .energy:
            return energyEntries
                .filter { $0.date >= cutoff && $0.totalEnergyBurned > 0 }
                .sorted { $0.date < $1.date }
                .map { HealthTrendPoint(date: $0.date, value: $0.totalEnergyBurned) }
        case .steps:
            return stepsEntries
                .filter { $0.date >= cutoff && $0.stepCount > 0 }
                .sorted { $0.date < $1.date }
                .map { HealthTrendPoint(date: $0.date, value: Double($0.stepCount)) }
        case .workoutVolume:
            return workouts
                .filter { $0.startedAt >= cutoff }
                .sorted { $0.startedAt < $1.startedAt }
                .map { HealthTrendPoint(date: $0.startedAt, value: $0.totalVolume) }
        }
    }
}

private struct HealthTrendDetailSheet: View {
    let metric: HealthTrendMetric
    let initialRange: HealthTrendRange

    @Environment(\.dismiss) private var dismiss
    @State private var range: HealthTrendRange

    @Query(WeightEntry.history) private var weightEntries: [WeightEntry]
    @Query(HealthSleepNight.history) private var sleepEntries: [HealthSleepNight]
    @Query(HealthHeart.history) private var heartEntries: [HealthHeart]
    @Query(HealthEnergy.history) private var energyEntries: [HealthEnergy]
    @Query(HealthStepsDistance.history) private var stepsEntries: [HealthStepsDistance]
    @Query(WorkoutSession.completedSession) private var workouts: [WorkoutSession]
    @Query(AppSettings.single) private var appSettings: [AppSettings]

    init(metric: HealthTrendMetric, initialRange: HealthTrendRange) {
        self.metric = metric
        self.initialRange = initialRange
        _range = State(initialValue: initialRange)
    }

    private var weightUnit: WeightUnit { appSettings.first?.weightUnit ?? .systemDefault }

    private var points: [HealthTrendPoint] {
        HealthTrendDataSource.points(for: metric, range: range, weightEntries: weightEntries, sleepEntries: sleepEntries, heartEntries: heartEntries, energyEntries: energyEntries, stepsEntries: stepsEntries, workouts: workouts, weightUnit: weightUnit)
    }

    private var insight: String {
        guard points.count >= 2 else {
            return String(localized: "Not enough data in this range yet — keep logging to see your trend.")
        }
        let first = points.first!.value
        let last = points.last!.value
        let delta = last - first
        let pct = first != 0 ? (delta / first) * 100 : 0
        let direction: String
        switch metric {
        case .weight, .restingHeartRate:
            direction = delta < 0 ? String(localized: "down") : String(localized: "up")
        case .sleep, .energy, .steps, .workoutVolume:
            direction = delta >= 0 ? String(localized: "up") : String(localized: "down")
        }
        let metricName = String(localized: metric.title).lowercased()
        let pctText = Int(abs(pct).rounded())
        return String(localized: "Your \(metricName) is \(direction) about \(pctText)% over the selected range.")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Range", selection: $range) {
                    ForEach(HealthTrendRange.allCases) { range in
                        Text(range.label).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier(AccessibilityIdentifiers.healthTrendDetailRangePicker)

                if points.count > 1 {
                    Chart(points) { point in
                        LineMark(x: .value("Date", point.date), y: .value("Value", point.value))
                            .foregroundStyle(metric.tint.gradient)
                            .lineStyle(.init(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                            .interpolationMethod(.catmullRom)
                        AreaMark(x: .value("Date", point.date), y: .value("Value", point.value))
                            .foregroundStyle(LinearGradient(colors: [metric.tint.opacity(0.25), metric.tint.opacity(0.0)], startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.catmullRom)
                    }
                    .frame(height: 220)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4))
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .accessibilityLabel(Text("\(String(localized: metric.title)) trend chart"))
                } else {
                    ContentUnavailableView {
                        Label(LocalizedStringResource("Not Enough Data"), systemImage: "chart.line.uptrend.xyaxis")
                    } description: {
                        Text(LocalizedStringResource("Try a different time range or add more trend data."))
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Insight")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fontWeight(.semibold)
                    Text(insight)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .appCardStyle()
            }
            .padding()
        }
        .appBackground()
        .navigationTitle(Text(metric.title))
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
                    .accessibilityIdentifier(AccessibilityIdentifiers.healthTrendDetailDoneButton)
            }
        }
        .diagScreen(VACrumb.healthTrendDetail)
    }
}

#Preview(traits: .sampleData) {
    NavigationStack { HealthTrendsView() }
}

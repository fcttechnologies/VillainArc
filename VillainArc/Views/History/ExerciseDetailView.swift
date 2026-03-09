import SwiftUI
import SwiftData
import Charts

struct ExerciseDetailView: View {
    let catalogID: String

    @Query private var exercises: [Exercise]
    @Query private var histories: [ExerciseHistory]
    @Query private var performances: [ExercisePerformance]

    init(catalogID: String) {
        self.catalogID = catalogID
        _exercises = Query(Exercise.withCatalogID(catalogID))
        _histories = Query(ExerciseHistory.forCatalogID(catalogID))
        _performances = Query(ExercisePerformance.matching(catalogID: catalogID))
    }

    private var exercise: Exercise? {
        exercises.first
    }

    private var history: ExerciseHistory? {
        histories.first
    }

    private var displayName: String {
        exercise?.name ?? performances.first?.name ?? "Exercise"
    }

    private var subtitle: String {
        let muscles = majorMusclesText
        let equipment = exercise?.equipmentType.rawValue ?? performances.first?.equipmentType.rawValue ?? "Unknown Equipment"
        if muscles.isEmpty {
            return equipment
        }
        return "\(muscles) • \(equipment)"
    }

    private var majorMusclesText: String {
        let muscles = (exercise?.musclesTargeted ?? performances.first?.musclesTargeted ?? [])
            .filter(\.isMajor)
        return ListFormatter.localizedString(byJoining: muscles.map(\.rawValue))
    }

    private var recentPerformances: [ExercisePerformance] {
        Array(performances.prefix(3))
    }

    private var completedSessionCount: Int {
        history?.totalSessions ?? performances.count
    }

    private var last30DaySessionCount: Int {
        history?.last30DaySessions ?? performances.filter { performance in
            guard let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) else {
                return false
            }
            return performance.date >= cutoff
        }.count
    }

    private var bestEstimatedOneRepMax: Double? {
        let historyValue = history?.bestEstimated1RM ?? 0
        return historyValue > 0 ? historyValue : ExercisePerformance.historicalBestEstimated1RM(in: performances)
    }

    private var bestWeight: Double? {
        let historyValue = history?.bestWeight ?? 0
        return historyValue > 0 ? historyValue : ExercisePerformance.historicalBestWeight(in: performances)
    }

    private var bestVolume: Double? {
        let historyValue = history?.bestVolume ?? 0
        return historyValue > 0 ? historyValue : ExercisePerformance.historicalBestVolume(in: performances)
    }

    private var trend: ProgressionTrend {
        history?.progressionTrend ?? .insufficient
    }

    private var topWeightPoints: [ExerciseMetricPoint] {
        guard let history else { return [] }
        return history.sortedProgressionPoints
            .reversed()
            .map { ExerciseMetricPoint(date: $0.date, value: $0.weight) }
    }

    private var volumePoints: [ExerciseMetricPoint] {
        guard let history else { return [] }
        return history.sortedProgressionPoints
            .reversed()
            .map { ExerciseMetricPoint(date: $0.date, value: $0.volume) }
    }

    private var estimatedOneRepMaxPoints: [ExerciseMetricPoint] {
        performances
            .sorted { $0.date < $1.date }
            .compactMap { performance in
                guard let value = performance.bestEstimated1RM, value > 0 else { return nil }
                return ExerciseMetricPoint(date: performance.date, value: value)
            }
    }

    var body: some View {
        List {
            if completedSessionCount == 0 {
                ContentUnavailableView(
                    "No Exercise History",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("Complete this exercise in a workout to see progress, PRs, and recent sessions.")
                )
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("exerciseDetailEmptyState")
            } else {
                ExerciseSnapshotSection(
                    equipment: exercise?.equipmentType.rawValue ?? performances.first?.equipmentType.rawValue ?? "Unknown Equipment",
                    muscles: majorMusclesText,
                    trend: trend,
                    completedSessionCount: completedSessionCount,
                    last30DaySessionCount: last30DaySessionCount,
                    lastWorkoutDate: history?.lastWorkoutDate ?? performances.first?.date
                )

                if bestEstimatedOneRepMax != nil || bestWeight != nil || bestVolume != nil {
                    Section("Personal Records") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            if let bestEstimatedOneRepMax {
                                ExerciseStatCard(
                                    title: "Best Est. 1RM",
                                    value: bestEstimatedOneRepMax,
                                    format: .number.precision(.fractionLength(0)),
                                    unit: "lbs"
                                )
                            }

                            if let bestWeight {
                                ExerciseStatCard(
                                    title: "Best Weight",
                                    value: bestWeight,
                                    format: .number.precision(.fractionLength(0)),
                                    unit: "lbs"
                                )
                            }

                            if let bestVolume {
                                ExerciseStatCard(
                                    title: "Best Volume",
                                    value: bestVolume,
                                    format: .number.precision(.fractionLength(0)),
                                    unit: "lbs"
                                )
                            }

                            if let history {
                                ExerciseTextStatCard(
                                    title: "Typical Reps",
                                    value: history.typicalRepRangeLower > 0 && history.typicalRepRangeUpper > 0
                                        ? "\(history.typicalRepRangeLower)-\(history.typicalRepRangeUpper)"
                                        : "Not Set",
                                    subtitle: "Working-set range"
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Progress") {
                    if !estimatedOneRepMaxPoints.isEmpty {
                        ExerciseMetricChartCard(
                            title: "Estimated 1RM",
                            points: estimatedOneRepMaxPoints,
                            tint: .red,
                            yAxisTitle: "lbs"
                        )
                    }

                    if !topWeightPoints.isEmpty {
                        ExerciseMetricChartCard(
                            title: "Top Weight",
                            points: topWeightPoints,
                            tint: .blue,
                            yAxisTitle: "lbs"
                        )
                    }

                    if !volumePoints.isEmpty {
                        ExerciseMetricChartCard(
                            title: "Volume",
                            points: volumePoints,
                            tint: .green,
                            yAxisTitle: "lbs"
                        )
                    }
                }

                Section("Recent Sessions") {
                    ForEach(recentPerformances) { performance in
                        RecentExercisePerformanceRow(performance: performance)
                    }
                }
            }
        }
        .accessibilityIdentifier("exerciseDetailList")
        .navigationTitle(displayName)
        .navigationSubtitle(Text(subtitle))
        .toolbarTitleDisplayMode(.inline)
    }
}

private struct ExerciseSnapshotSection: View {
    let equipment: String
    let muscles: String
    let trend: ProgressionTrend
    let completedSessionCount: Int
    let last30DaySessionCount: Int
    let lastWorkoutDate: Date?

    var body: some View {
        Section("Overview") {
            LabeledContent("Equipment", value: equipment)

            if !muscles.isEmpty {
                LabeledContent("Primary Muscles", value: muscles)
            }

            LabeledContent("Trend") {
                Text(trend.displayName)
                    .foregroundStyle(trendColor)
            }

            LabeledContent("Completed Sessions", value: "\(completedSessionCount)")
            LabeledContent("Last 30 Days", value: "\(last30DaySessionCount)")

            if let lastWorkoutDate {
                LabeledContent("Last Performed") {
                    Text(lastWorkoutDate, format: .dateTime.month(.abbreviated).day().year())
                }
            }
        }
    }

    private var trendColor: Color {
        switch trend {
        case .improving:
            return .green
        case .stable:
            return .orange
        case .declining:
            return .red
        case .insufficient:
            return .secondary
        }
    }
}

private struct ExerciseStatCard: View {
    let title: String
    let value: Double
    let format: FloatingPointFormatStyle<Double>
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value, format: format)
                .font(.title3)
                .bold()
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct ExerciseTextStatCard: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3)
                .bold()
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct ExerciseMetricChartCard: View {
    let title: String
    let points: [ExerciseMetricPoint]
    let tint: Color
    let yAxisTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            Chart(points) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value(title, point.value)
                )
                .foregroundStyle(tint)
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", point.date),
                    y: .value(title, point.value)
                )
                .foregroundStyle(tint)
            }
            .frame(height: 180)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: min(points.count, 4))) { value in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }

            HStack {
                Text("Latest")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(points.last?.value ?? 0, format: .number.precision(.fractionLength(0)))
                    .font(.callout)
                    .bold()
                Text(yAxisTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct RecentExercisePerformanceRow: View {
    let performance: ExercisePerformance

    private var workingSetCount: Int {
        performance.sortedSets.filter { $0.type == .working }.count
    }

    private var topWeight: Double {
        performance.bestWeight ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(performance.workoutSession?.title ?? "Workout")
                    .font(.headline)
                Spacer()
                Text(performance.date, format: .dateTime.month(.abbreviated).day().year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(sessionSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(performance.sortedSets) { set in
                        Text(set.summaryText)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(.vertical, 4)
    }

    private var sessionSummary: String {
        var components: [String] = []
        if workingSetCount > 0 {
            components.append("\(workingSetCount) working sets")
        }
        if topWeight > 0 {
            components.append("\(topWeight.formatted(.number.precision(.fractionLength(0)))) lbs top set")
        }
        let volume = performance.totalVolume
        if volume > 0 {
            components.append("\(volume.formatted(.number.precision(.fractionLength(0)))) lbs volume")
        }
        return ListFormatter.localizedString(byJoining: components)
    }
}

private struct ExerciseMetricPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

private extension SetPerformance {
    var summaryText: String {
        let repsText = "\(reps) reps"
        if weight > 0 {
            return "\(type.shortLabel) \(weight.formatted(.number.precision(.fractionLength(0)))) x \(reps)"
        }
        return "\(type.shortLabel) \(repsText)"
    }
}

#Preview("Exercise Detail") {
    NavigationStack {
        ExerciseDetailView(catalogID: "dumbbell_incline_bench_press")
    }
    .sampleDataContainerSuggestionGeneration()
}

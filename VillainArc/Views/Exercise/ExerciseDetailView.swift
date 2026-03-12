import SwiftUI
import SwiftData
import Charts
import AppIntents

struct ExerciseDetailView: View {
    private enum ChartMetric: String, CaseIterable, Identifiable {
        case estimatedOneRepMax = "Est. 1RM"
        case topWeight = "Top Weight"
        case volume = "Volume"
        case reps = "Reps"

        var id: String { rawValue }

        var tint: Color {
            switch self {
            case .estimatedOneRepMax:
                return .red
            case .topWeight:
                return .blue
            case .volume:
                return .green
            case .reps:
                return .orange
            }
        }

        var unit: String {
            switch self {
            case .reps:
                return "reps"
            default:
                return "lbs"
            }
        }
    }

    let catalogID: String

    @Query private var exercises: [Exercise]
    @Query private var histories: [ExerciseHistory]

    private let appRouter = AppRouter.shared

    @State private var selectedMetric: ChartMetric = .estimatedOneRepMax
    @State private var showProgressionFeedbackSheet = false

    init(catalogID: String) {
        self.catalogID = catalogID
        _exercises = Query(Exercise.withCatalogID(catalogID))
        _histories = Query(ExerciseHistory.forCatalogID(catalogID))
    }

    private var exercise: Exercise? {
        exercises.first
    }

    private var history: ExerciseHistory? {
        histories.first
    }

    private var displayName: String {
        exercise?.name ?? "Exercise"
    }

    private var latestEstimatedOneRepMax: Double? {
        guard let history, history.latestEstimated1RM > 0 else { return nil }
        return history.latestEstimated1RM
    }

    private var bestWeight: Double? {
        guard let history, history.bestWeight > 0 else { return nil }
        return history.bestWeight
    }

    private var bestVolume: Double? {
        guard let history, history.bestVolume > 0 else { return nil }
        return history.bestVolume
    }

    private var totalSessions: Int {
        history?.totalSessions ?? 0
    }

    private var canShowProgressionFeedback: Bool {
        totalSessions >= ExerciseProgressionContextBuilder.minimumSessionCount
    }

    private var totalSets: Int {
        history?.totalCompletedSets ?? 0
    }

    private var totalReps: Int {
        history?.totalCompletedReps ?? 0
    }

    private var totalVolume: Double {
        history?.cumulativeVolume ?? 0
    }

    private var bestReps: Int? {
        guard let history, history.bestReps > 0 else { return nil }
        return history.bestReps
    }

    private var statItems: [ExerciseStatItem] {
        guard totalSessions > 0 else { return [] }

        var items: [ExerciseStatItem] = [
            .init(title: "Times Done", value: "\(totalSessions)"),
            .init(title: "Sets Done", value: "\(totalSets)")
        ]

        if totalReps > 0 {
            items.append(.init(title: "Total Reps", value: "\(totalReps)"))
        }

        if totalVolume > 0 {
            items.append(.init(title: "Total Volume", value: "\(totalVolume.formatted(.number.precision(.fractionLength(0)))) lbs"))
        }

        if let bestReps {
            items.append(.init(title: "Best Reps", value: "\(bestReps)"))
        }

        if let latestEstimatedOneRepMax {
            items.append(.init(title: "Est. 1RM", value: "\(latestEstimatedOneRepMax.formatted(.number.precision(.fractionLength(0)))) lbs"))
        }

        if let bestWeight {
            items.append(.init(title: "Best Weight", value: "\(bestWeight.formatted(.number.precision(.fractionLength(0)))) lbs"))
        }

        if let bestVolume {
            items.append(.init(title: "Best Volume", value: "\(bestVolume.formatted(.number.precision(.fractionLength(0)))) lbs"))
        }

        return items
    }

    private var estimatedOneRepMaxPoints: [ExerciseMetricPoint] {
        guard let history else { return [] }
        return history.sortedProgressionPoints
            .reversed()
            .compactMap { point in
                guard point.estimated1RM > 0 else { return nil }
                return ExerciseMetricPoint(date: point.date, value: point.estimated1RM)
            }
    }

    private var topWeightPoints: [ExerciseMetricPoint] {
        guard let history else { return [] }
        return history.sortedProgressionPoints
            .reversed()
            .compactMap { point in
                guard point.weight > 0 else { return nil }
                return ExerciseMetricPoint(date: point.date, value: point.weight)
            }
    }

    private var volumePoints: [ExerciseMetricPoint] {
        guard let history else { return [] }
        return history.sortedProgressionPoints
            .reversed()
            .compactMap { point in
                guard point.volume > 0 else { return nil }
                return ExerciseMetricPoint(date: point.date, value: point.volume)
            }
    }

    private var repsPoints: [ExerciseMetricPoint] {
        guard let history else { return [] }
        return history.sortedProgressionPoints
            .reversed()
            .compactMap { point in
                guard point.totalReps > 0 else { return nil }
                return ExerciseMetricPoint(date: point.date, value: Double(point.totalReps))
            }
    }

    private var availableMetrics: [ChartMetric] {
        ChartMetric.allCases.filter { points(for: $0).count >= 2 }
    }

    private var activeMetric: ChartMetric? {
        if availableMetrics.contains(selectedMetric) {
            return selectedMetric
        }
        return availableMetrics.first
    }

    private var latestMetricValueText: String {
        guard let activeMetric, let latestValue = points(for: activeMetric).last?.value else { return "" }
        return "\(latestValue.formatted(.number.precision(.fractionLength(0)))) \(activeMetric.unit)"
    }

    var body: some View {
        ScrollView {
            if hasContent {
                LazyVStack(alignment: .leading, spacing: 44) {
                    if !statItems.isEmpty {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(statItems) { item in
                                SummaryStatCard(title: item.title, value: item.value)
                            }
                        }
                    }

                    if let activeMetric {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text(activeMetric.rawValue)
                                    .font(.headline)
                                Spacer()
                                Text("Latest")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(latestMetricValueText)
                                    .font(.headline)
                            }

                            ExerciseMetricChartCard(points: points(for: activeMetric), tint: activeMetric.tint, unit: activeMetric.unit)

                            if availableMetrics.count > 1 {
                                Picker("Metric", selection: $selectedMetric) {
                                    ForEach(availableMetrics) { metric in
                                        Text(metric.rawValue).tag(metric)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                    } else if totalSessions > 0 {
                        chartUnavailableCard
                    }
                }
                .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if !hasContent {
                ContentUnavailableView("No Exercise History", systemImage: "chart.line.uptrend.xyaxis", description: Text("Complete this exercise in a workout to see progress and personal records."))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("exerciseDetailEmptyState")
            }
        }
        .accessibilityIdentifier("exerciseDetailScrollView")
        .navigationTitle(displayName)
        .navigationSubtitle(Text(exercise?.detailSubtitle ?? "Unknown Equipment"))
        .toolbarTitleDisplayMode(.inline)
        .sheet(isPresented: $showProgressionFeedbackSheet) {
            ExerciseProgressionFeedbackSheet(catalogID: catalogID)
        }
        .task(id: availableMetrics.map(\.rawValue).joined(separator: ",")) {
            if let firstMetric = availableMetrics.first, !availableMetrics.contains(selectedMetric) {
                selectedMetric = firstMetric
            }
        }
        .userActivity("com.villainarc.exercise.view", isActive: exercise != nil) { activity in
            guard let exercise else { return }
            activity.title = exercise.name
            activity.isEligibleForSearch = true
            activity.isEligibleForPrediction = true
            let entity = ExerciseEntity(exercise: exercise)
            activity.appEntityIdentifier = .init(for: entity)
        }
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                if canShowProgressionFeedback {
                    Button("Progress Feedback", systemImage: "sparkles") {
                        showProgressionFeedbackSheet = true
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.exerciseDetailProgressionFeedbackButton)
                }
            }
            ToolbarSpacer(.flexible, placement: .bottomBar)
            ToolbarItem(placement: .bottomBar) {
                if totalSessions > 0 {
                    Button("View Exercise History", systemImage: "clock.arrow.circlepath") {
                        appRouter.navigate(to: .exerciseHistory(catalogID))
                    }
                    .accessibilityIdentifier("exerciseDetailHistoryButton")
                }
            }
        }
    }

    private var hasContent: Bool {
        history != nil && (!statItems.isEmpty || !availableMetrics.isEmpty)
    }

    private var chartUnavailableCard: some View {
        ContentUnavailableView("Progress Charts", systemImage: "chart.line.uptrend.xyaxis", description: Text("Charts appear after at least 2 logged sessions for this exercise."))
        .padding()
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
    }

    private func points(for metric: ChartMetric) -> [ExerciseMetricPoint] {
        switch metric {
        case .estimatedOneRepMax:
            return estimatedOneRepMaxPoints
        case .topWeight:
            return topWeightPoints
        case .volume:
            return volumePoints
        case .reps:
            return repsPoints
        }
    }
}

private struct ExerciseStatItem: Identifiable {
    let id = UUID()
    let title: String
    let value: String
}

private struct ExerciseMetricChartCard: View {
    let points: [ExerciseMetricPoint]
    let tint: Color
    let unit: String

    @State private var selectedDate: Date?

    private var yDomain: ClosedRange<Double> {
        let values = points.map(\.value)
        guard let minimum = values.min(), let maximum = values.max() else {
            return 0...1
        }

        if minimum == maximum {
            let padding = max(abs(minimum) * 0.05, 1)
            return (minimum - padding)...(maximum + padding)
        }

        let range = maximum - minimum
        let padding = max(range * 0.15, range < 5 ? 0.5 : 1)
        return (minimum - padding)...(maximum + padding)
    }

    private var displayedPoint: ExerciseMetricPoint? {
        guard let selectedDate else { return nil }
        return nearestPoint(to: selectedDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Chart(points) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(tint)
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(tint)

                if point.id == displayedPoint?.id {
                    RuleMark(x: .value("Selected Date", point.date))
                        .foregroundStyle(tint)
                        .lineStyle(.init(lineWidth: 1, dash: [4, 4]))
                        .annotation(position: .top, spacing: 8, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(point.date, style: .date)
                                    .foregroundStyle(.white.opacity(0.9))
                                Text("\(point.value, format: .number) \(unit)")
                                    .font(.title2)
                                    .foregroundStyle(.white)
                            }
                            .bold()
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(tint.gradient, in: .rect(cornerRadius: 12))
                        }
                }
            }
            .frame(height: 220)
            .chartYScale(domain: yDomain)
            .chartXSelection(value: $selectedDate)
            
            .chartYAxis {
                AxisMarks(position: .leading, values: .stride(by: axisStep)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text(doubleValue, format: .number.precision(.fractionLength(0)))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: min(points.count, 4))) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        .onChange(of: points) { _, newPoints in
            if let selectedDate {
                self.selectedDate = nearestPoint(in: newPoints, to: selectedDate)?.date
            }
        }
    }

    private var axisStep: Double {
        let range = yDomain.upperBound - yDomain.lowerBound
        if range <= 5 {
            return 1
        }
        if range <= 20 {
            return 2.5
        }
        if range <= 60 {
            return 5
        }
        return max((range / 4).rounded(.up), 10)
    }

    private func nearestPoint(to date: Date) -> ExerciseMetricPoint? {
        nearestPoint(in: points, to: date)
    }

    private func nearestPoint(in points: [ExerciseMetricPoint], to date: Date) -> ExerciseMetricPoint? {
        points.min { left, right in
            abs(left.date.timeIntervalSince(date)) < abs(right.date.timeIntervalSince(date))
        }
    }
}

private struct ExerciseMetricPoint: Identifiable, Equatable {
    let id: Date
    let date: Date
    let value: Double

    init(date: Date, value: Double) {
        self.id = date
        self.date = date
        self.value = value
    }
}

#Preview("Exercise Detail") {
    NavigationStack {
        ExerciseDetailView(catalogID: "dumbbell_incline_bench_press")
    }
    .sampleDataContainerSuggestionGeneration()
}

#Preview("Exercise Detail Empty") {
    NavigationStack {
        ExerciseDetailView(catalogID: "barbell_bent_over_row")
    }
    .sampleDataContainer()
}

import SwiftUI
import SwiftData
import Charts
import AppIntents
import CoreSpotlight

struct ExerciseDetailView: View {
    private enum ChartMetric: String, CaseIterable, Identifiable {
        case estimatedOneRepMax = "Est. 1RM"
        case topWeight = "Top Weight"
        case volume = "Volume"
        case reps = "Reps"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .estimatedOneRepMax:
                return String(localized: "Est. 1RM")
            case .topWeight:
                return String(localized: "Top Weight")
            case .volume:
                return String(localized: "Volume")
            case .reps:
                return String(localized: "Reps")
            }
        }

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

        func unitString(weightUnit: WeightUnit) -> String {
            switch self {
            case .reps:
                return "reps"
            default:
                return weightUnit.rawValue
            }
        }

        var valueFractionDigits: ClosedRange<Int> {
            switch self {
            case .estimatedOneRepMax:
                return 0...1
            case .topWeight:
                return 0...2
            case .volume, .reps:
                return 0...0
            }
        }

        func formattedValueText(_ value: Double, weightUnit: WeightUnit) -> String {
            let valueText = value.formatted(.number.precision(.fractionLength(valueFractionDigits)))
            return "\(valueText) \(unitString(weightUnit: weightUnit))"
        }
    }

    let catalogID: String

    @Query private var exercises: [Exercise]
    @Query private var histories: [ExerciseHistory]
    @Query(AppSettings.single) private var appSettings: [AppSettings]

    private let appRouter = AppRouter.shared

    private var weightUnit: WeightUnit { appSettings.first?.weightUnit ?? .lbs }

    @State private var selectedMetric: ChartMetric = .estimatedOneRepMax
    @State private var suggestionSettingsExercise: Exercise?

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
            items.append(.init(title: "Total Volume", value: formattedWeightText(totalVolume, unit: weightUnit, fractionDigits: 0...0)))
        }

        if totalSets > 1, let bestReps {
            items.append(.init(title: "Best Reps", value: "\(bestReps)"))
        }

        if let latestEstimatedOneRepMax {
            items.append(.init(title: "Est. 1RM", value: formattedWeightText(latestEstimatedOneRepMax, unit: weightUnit, fractionDigits: 0...0)))
        }

        if let bestWeight {
            items.append(.init(title: "Best Weight", value: formattedWeightText(bestWeight, unit: weightUnit)))
        }

        if totalSessions > 1, let bestVolume {
            items.append(.init(title: "Best Volume", value: formattedWeightText(bestVolume, unit: weightUnit, fractionDigits: 0...0)))
        }

        return items
    }

    private var progressionPoints: [ProgressionPoint] {
        history?.chronologicalProgressionPoints ?? []
    }

    private var estimatedOneRepMaxPoints: [ExerciseMetricPoint] {
        progressionPoints
            .compactMap { point in
                guard point.estimated1RM > 0 else { return nil }
                return ExerciseMetricPoint(date: point.date, value: weightUnit.fromKg(point.estimated1RM))
            }
    }

    private var topWeightPoints: [ExerciseMetricPoint] {
        progressionPoints
            .compactMap { point in
                guard point.weight > 0 else { return nil }
                return ExerciseMetricPoint(date: point.date, value: weightUnit.fromKg(point.weight))
            }
    }

    private var volumePoints: [ExerciseMetricPoint] {
        progressionPoints
            .compactMap { point in
                guard point.volume > 0 else { return nil }
                return ExerciseMetricPoint(date: point.date, value: weightUnit.fromKg(point.volume))
            }
    }

    private var repsPoints: [ExerciseMetricPoint] {
        progressionPoints
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
        return activeMetric.formattedValueText(latestValue, weightUnit: weightUnit)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 44) {
                if hasContent {
                    if !statItems.isEmpty {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(statItems) { item in
                                SummaryStatCard(title: item.title, text: item.value)
                            }
                        }
                    }

                    if let activeMetric {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text(activeMetric.displayName)
                                    .font(.headline)
                                Spacer()
                                Text("Latest")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(latestMetricValueText)
                                    .font(.headline)
                            }

                            ExerciseMetricChartCard(
                                points: points(for: activeMetric),
                                tint: activeMetric.tint,
                                aggregation: aggregation(for: activeMetric),
                                formatValueText: { activeMetric.formattedValueText($0, weightUnit: weightUnit) }
                            )

                            if availableMetrics.count > 1 {
                                Picker("Metric", selection: $selectedMetric) {
                                    ForEach(availableMetrics) { metric in
                                        Text(metric.displayName).tag(metric)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                    } else if totalSessions > 0 {
                        chartUnavailableCard
                    }
                } else if exercise != nil {
                    noHistoryCard
                }

                if let exercise {
                    suggestionSettingsSection(for: exercise)
                }
            }
            .padding(.horizontal)
        }
        .quickActionContentBottomInset()
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appBackground()
        .sheet(item: $suggestionSettingsExercise) { exercise in
            ExerciseSuggestionSettingsSheet(exercise: exercise)
                .presentationBackground(Color.sheetBg)
        }
        .overlay {
            if exercise == nil {
                ContentUnavailableView("No Exercise History", systemImage: "chart.line.uptrend.xyaxis", description: Text("Complete this exercise in a workout to see progress and personal records."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier(AccessibilityIdentifiers.exerciseDetailEmptyState)
            }
        }
        .accessibilityIdentifier(AccessibilityIdentifiers.exerciseDetailScrollView)
        .navigationTitle(displayName)
        .navigationSubtitle(Text(exercise?.detailSubtitle ?? "Unknown Equipment"))
        .toolbarTitleDisplayMode(.inline)
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
            activity.persistentIdentifier = NSUserActivityPersistentIdentifier(SpotlightIndexer.exerciseIdentifier(for: exercise.catalogID))
            let attributeSet = activity.contentAttributeSet ?? CSSearchableItemAttributeSet(contentType: .item)
            attributeSet.relatedUniqueIdentifier = SpotlightIndexer.exerciseIdentifier(for: exercise.catalogID)
            activity.contentAttributeSet = attributeSet
            let entity = ExerciseEntity(exercise: exercise)
            activity.appEntityIdentifier = .init(for: entity)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if totalSessions > 0 {
                    Button("View Exercise History", systemImage: "clock.arrow.circlepath") {
                        appRouter.push(to: .exerciseHistory(catalogID))
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.exerciseDetailHistoryButton)
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
        .appCardStyle()
    }

    private var noHistoryCard: some View {
        ContentUnavailableView("No Exercise History", systemImage: "chart.line.uptrend.xyaxis", description: Text("Complete this exercise in a workout to start tracking progress and personal records."))
            .padding()
            .frame(maxWidth: .infinity)
            .appCardStyle()
            .accessibilityIdentifier(AccessibilityIdentifiers.exerciseDetailEmptyState)
    }

    private func suggestionSettingsSection(for exercise: Exercise) -> some View {
        Button {
            Haptics.selection()
            suggestionSettingsExercise = exercise
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(suggestionSettingsTitle(for: exercise))
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }

                Text(suggestionSettingsDescription(for: exercise))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .appCardStyle()
            .tint(.primary)
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier(AccessibilityIdentifiers.exerciseDetailSuggestionSettingsButton)
        .accessibilityHint(AccessibilityText.exerciseDetailSuggestionSettingsHint)
    }

    private func suggestionSettingsTitle(for exercise: Exercise) -> String {
        if exercise.suggestionsEnabled {
            return "Exercise Suggestions (\(exercise.equipmentType.progressionStepValueText(preferredWeightChange: exercise.preferredWeightChange, unit: weightUnit)))"
        }

        return "Exercise Suggestions (Off)"
    }

    private func suggestionSettingsDescription(for exercise: Exercise) -> String {
        if exercise.suggestionsEnabled {
            return exercise.equipmentType.progressionStepCardDescription
        }

        return "Villain Arc will not generate suggestions for this exercise until you turn them back on."
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
    
    private func aggregation(for metric: ChartMetric) -> ExerciseMetricChartCard.Aggregation {
        switch metric {
        case .estimatedOneRepMax, .topWeight, .reps:
            return .maximum
        case .volume:
            return .sum
        }
    }
}

private struct ExerciseStatItem: Identifiable {
    let id = UUID()
    let title: String
    let value: String
}

private struct ExerciseMetricChartCard: View {
    enum Aggregation {
        case maximum
        case sum
        
        var timeSeriesStrategy: TimeSeriesAggregationStrategy {
            switch self {
            case .maximum:
                return .maximum
            case .sum:
                return .sum
            }
        }
    }
    
    let points: [ExerciseMetricPoint]
    let tint: Color
    let aggregation: Aggregation
    let formatValueText: (Double) -> String

    @State private var selectedDate: Date?
    
    private var timeSeriesSamples: [TimeSeriesSample] {
        points.map { TimeSeriesSample(date: $0.date, value: $0.value) }
    }
    
    private var chartLayout: TimeSeriesChartLayout {
        TimeSeriesChartLayout(rangeFilter: .all, samples: timeSeriesSamples, now: .now, calendar: .autoupdatingCurrent, aggregation: aggregation.timeSeriesStrategy)
    }
    
    private var linePoints: [TimeSeriesBucketedPoint] {
        timeSeriesAnchoredLinePoints(points: chartLayout.points, samples: timeSeriesSamples, domain: chartLayout.currentDomain)
    }

    private var yDomain: ClosedRange<Double> {
        let values = chartLayout.points.map(\.value)
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

    private var displayedPoint: TimeSeriesBucketedPoint? {
        guard let selectedDate else { return nil }
        return nearestPoint(to: selectedDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Chart {
                ForEach(linePoints) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(tint)
                    .interpolationMethod(.catmullRom)
                }
                
                ForEach(chartLayout.points) { point in
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
                                    Text(annotationDateText(for: point))
                                        .foregroundStyle(.white.opacity(0.9))
                                    Text(formatValueText(point.value))
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
            }
            .frame(height: 220)
            .chartYScale(domain: yDomain)
            .chartXSelection(value: $selectedDate)
            .chartXScale(domain: chartLayout.currentDomain)
            
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
                AxisMarks(values: chartLayout.axisDates) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(axisLabel(for: date))
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        .onChange(of: points) { _, newPoints in
            if let selectedDate {
                self.selectedDate = selectedTimeSeriesPoint(in: newPoints.map { TimeSeriesBucketedPoint(date: $0.date, value: $0.value) }, for: selectedDate)?.date
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

    private func nearestPoint(to date: Date) -> TimeSeriesBucketedPoint? {
        selectedTimeSeriesPoint(in: chartLayout.points, for: date)
    }
    
    private func axisLabel(for date: Date) -> String {
        timeSeriesAxisLabelText(for: date, style: chartLayout.axisLabelStyle)
    }
    
    private func annotationDateText(for point: TimeSeriesBucketedPoint) -> String {
        timeSeriesBucketLabelText(for: point, bucketStyle: chartLayout.bucketStyle)
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

#Preview("Exercise Detail", traits: .sampleDataSuggestionGeneration) {
    NavigationStack {
        ExerciseDetailView(catalogID: "dumbbell_incline_bench_press")
    }
}

#Preview("Exercise Detail Empty", traits: .sampleData) {
    NavigationStack {
        ExerciseDetailView(catalogID: "barbell_bent_over_row")
    }
}

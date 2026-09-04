import FCTMetrics
import Charts
import MuscleMap
import SwiftData
import SwiftUI
import Foundation

// MARK: - Muscle Mapping

private extension Muscle {
    var muscleMapMuscles: [MuscleMap.Muscle] {
        switch self {
        case .chest: return [.chest]
        case .back: return [.upperBack, .lowerBack]
        case .shoulders: return [.deltoids]
        case .biceps: return [.biceps]
        case .triceps: return [.triceps]
        case .abs: return [.abs]
        case .glutes: return [.gluteal]
        case .quads: return [.quadriceps]
        case .hamstrings: return [.hamstring]
        case .calves: return [.calves]
        case .forearms: return [.forearm]
        case .adductors: return [.adductors]
        case .abductors: return []
        case .upperChest: return [.upperChest]
        case .lowerChest: return [.lowerChest]
        case .midChest: return [.chest]
        case .lats: return [.upperBack]
        case .lowerBack: return [.lowerBack]
        case .upperTraps: return [.upperTrapezius]
        case .lowerTraps: return [.lowerTrapezius]
        case .midTraps: return [.trapezius]
        case .rhomboids: return [.rhomboids]
        case .frontDelt: return [.frontDeltoid]
        case .sideDelt: return [.deltoids]
        case .rearDelt: return [.rearDeltoid]
        case .rotatorCuff: return [.rotatorCuff]
        case .longHeadBiceps, .shortHeadBiceps, .brachialis: return [.biceps]
        case .longHeadTriceps, .lateralHeadTriceps, .medialHeadTriceps: return [.triceps]
        case .wrists: return [.forearm]
        case .upperAbs: return [.upperAbs]
        case .lowerAbs: return [.lowerAbs]
        case .obliques: return [.obliques]
        }
    }
}

// MARK: - ExerciseInfoView

struct ExerciseInfoView: View {
    let catalogID: String
    let isSelected: Bool
    let onToggleSelect: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var exercises: [Exercise]
    @Query private var histories: [ExerciseHistory]
    @Query private var performances: [ExercisePerformance]
    @Query(AppSettings.single) private var appSettings: [AppSettings]

    private let appRouter = AppRouter.shared

    @State private var selectedMetric: ChartMetric = .estimatedOneRepMax
    @State private var suggestionSettingsExercise: Exercise?

    private var weightUnit: WeightUnit { appSettings.first?.weightUnit ?? .lbs }
    private var exercise: Exercise? { exercises.first }
    private var history: ExerciseHistory? { histories.first }
    private var recentPerformances: [ExercisePerformance] { Array(performances.prefix(3)) }
    private var howToSteps: [String] { ExerciseCatalog.byID[catalogID]?.steps ?? [] }

    init(catalogID: String, isSelected: Bool, onToggleSelect: @escaping () -> Void) {
        self.catalogID = catalogID
        self.isSelected = isSelected
        self.onToggleSelect = onToggleSelect
        _exercises = Query(Exercise.withCatalogID(catalogID))
        _histories = Query(ExerciseHistory.forCatalogID(catalogID))
        _performances = Query(ExercisePerformance.matching(catalogID: catalogID))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    muscleMapSection
                    if let exercise, hasStats {
                        statsSection(exercise: exercise)
                    }
                    if let activeMetric {
                        chartSection(metric: activeMetric)
                    }
                    if !howToSteps.isEmpty {
                        howToSection
                    }
                    recentSection
                    if let exercise {
                        suggestionSettingsSection(for: exercise)
                    }
                }
                .padding([.horizontal, .bottom])
                .padding(.top, 12)
            }
            .scrollIndicators(.hidden)
            .appBackground()
            .navigationTitle(exercise?.name ?? "Exercise")
            .navigationSubtitle(Text(exercise?.detailSubtitle ?? ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if let exercise {
                        Button {
                            Haptics.selection()
                            exercise.toggleFavorite()
                            saveContext(context: context)
                            Task { await IntentDonations.donateToggleExerciseFavorite(exercise: exercise) }
                        } label: {
                            Image(systemName: exercise.favorite ? "star.fill" : "star")
                                .foregroundStyle(exercise.favorite ? .yellow : .primary)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .accessibilityIdentifier(AccessibilityIdentifiers.exerciseInfoFavoriteButton)
                        .accessibilityLabel(exercise.favorite ? "Unfavorite Exercise" : "Favorite Exercise")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.selection()
                        onToggleSelect()
                        if !isSelected { dismiss() }
                    } label: {
                        Image(systemName: isSelected ? "checkmark" : "plus")
                            .foregroundStyle(isSelected ? .blue : .primary)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .accessibilityLabel(isSelected ? "Remove from Workout" : "Add to Workout")
                    .accessibilityIdentifier(AccessibilityIdentifiers.exerciseInfoSelectButton)
                }
            }
            .sheet(item: $suggestionSettingsExercise) { exercise in
                ExerciseSuggestionSettingsSheet(exercise: exercise)
                    .presentationBackground(Color.sheetBg)
            }
        }
        .task(id: availableMetrics.map(\.rawValue).joined(separator: ",")) {
            if let firstMetric = availableMetrics.first, !availableMetrics.contains(selectedMetric) {
                selectedMetric = firstMetric
            }
        }
        .diagScreen(VACrumb.exerciseInfo)
    }

    // MARK: - Muscle Map

    private var muscleMapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Muscles Targeted")
                .font(.headline)

            HStack(spacing: 12) {
                highlightedBodyView(side: .front)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)

                highlightedBodyView(side: .back)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
            }
            .padding(12)
            .appCardStyle()

            if let exercise, !exercise.musclesTargeted.isEmpty {
                muscleChipRow(for: exercise)
            }
        }
    }

    private func highlightedBodyView(side: BodySide) -> BodyView {
        guard let exercise else { return BodyView(gender: .male, side: side) }
        var view = BodyView(gender: .male, side: side)
        for (index, appMuscle) in exercise.musclesTargeted.enumerated() {
            let color: Color = index == 0 ? .red : .orange
            let opacity: Double = index == 0 ? 0.85 : 0.55
            for mapMuscle in appMuscle.muscleMapMuscles {
                view = view.highlight(mapMuscle, color: color, opacity: opacity)
            }
        }
        return view
    }

    private func muscleChipRow(for exercise: Exercise) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(exercise.musclesTargeted.enumerated()), id: \.element) { index, muscle in
                    Text(muscle.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            (index == 0 ? Color.red : Color.orange).opacity(index == 0 ? 0.2 : 0.15),
                            in: Capsule()
                        )
                        .foregroundStyle(index == 0 ? .red : .orange)
                }
            }
        }
        .scrollClipDisabled()
    }

    // MARK: - Stats

    private var hasStats: Bool {
        guard let history else { return false }
        return history.totalSessions > 0
    }

    private func statsSection(exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Personal Records")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(statItems, id: \.title) { item in
                    SummaryStatCard(title: item.title, text: item.value)
                }
            }
        }
    }

    private var statItems: [(title: String, value: String)] {
        guard let history, history.totalSessions > 0 else { return [] }
        var items: [(title: String, value: String)] = [
            ("Times Done", "\(history.totalSessions)"),
            ("Sets Done", "\(history.totalCompletedSets)")
        ]
        if history.totalCompletedReps > 0 {
            items.append(("Total Reps", "\(history.totalCompletedReps)"))
        }
        if history.cumulativeVolume > 0 {
            items.append(("Total Volume", formattedWeightText(history.cumulativeVolume, unit: weightUnit, fractionDigits: 0...0)))
        }
        if history.bestReps > 0 {
            items.append(("Best Reps", "\(history.bestReps)"))
        }
        if history.latestEstimated1RM > 0 {
            items.append(("Est. 1RM", formattedWeightText(history.latestEstimated1RM, unit: weightUnit, fractionDigits: 0...0)))
        }
        if history.bestWeight > 0 {
            items.append(("Best Weight", formattedWeightText(history.bestWeight, unit: weightUnit)))
        }
        return items
    }

    // MARK: - Chart

    private var progressionPoints: [ProgressionPoint] {
        history?.chronologicalProgressionPoints ?? []
    }

    private var estimatedOneRepMaxPoints: [ExerciseInfoMetricPoint] {
        progressionPoints.compactMap { p in p.estimated1RM > 0 ? .init(date: p.date, value: weightUnit.fromKg(p.estimated1RM)) : nil }
    }
    private var topWeightPoints: [ExerciseInfoMetricPoint] {
        progressionPoints.compactMap { p in p.weight > 0 ? .init(date: p.date, value: weightUnit.fromKg(p.weight)) : nil }
    }
    private var volumePoints: [ExerciseInfoMetricPoint] {
        progressionPoints.compactMap { p in p.volume > 0 ? .init(date: p.date, value: weightUnit.fromKg(p.volume)) : nil }
    }
    private var repsPoints: [ExerciseInfoMetricPoint] {
        progressionPoints.compactMap { p in p.totalReps > 0 ? .init(date: p.date, value: Double(p.totalReps)) : nil }
    }

    private var availableMetrics: [ChartMetric] {
        ChartMetric.allCases.filter { points(for: $0).count >= 2 }
    }

    private var activeMetric: ChartMetric? {
        availableMetrics.contains(selectedMetric) ? selectedMetric : availableMetrics.first
    }

    private func points(for metric: ChartMetric) -> [ExerciseInfoMetricPoint] {
        switch metric {
        case .estimatedOneRepMax: return estimatedOneRepMaxPoints
        case .topWeight: return topWeightPoints
        case .volume: return volumePoints
        case .reps: return repsPoints
        }
    }

    private var latestMetricValueText: String {
        guard let m = activeMetric, let last = points(for: m).last?.value else { return "" }
        return m.formattedValueText(last, weightUnit: weightUnit)
    }

    private func chartSection(metric: ChartMetric) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Progress")
                    .font(.headline)
                Spacer()
                Text("Latest")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(latestMetricValueText)
                    .font(.headline)
            }

            ExerciseInfoChartCard(
                points: points(for: metric),
                tint: metric.tint,
                formatValueText: { metric.formattedValueText($0, weightUnit: weightUnit) }
            )

            if availableMetrics.count > 1 {
                Picker("Metric", selection: $selectedMetric) {
                    ForEach(availableMetrics) { m in
                        Text(m.displayName).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier(AccessibilityIdentifiers.exerciseInfoMetricPicker)
            }
        }
    }

    // MARK: - How To

    private var howToSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How To")
                .font(.headline)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(howToSteps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 14) {
                        Text("\(index + 1)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(.blue, in: Circle())
                            .padding(.top, 2)

                        Text(step)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)

                    if index < howToSteps.count - 1 {
                        Divider()
                            .padding(.leading, 54)
                    }
                }
            }
            .appCardStyle()
        }
    }

    // MARK: - Recent Sessions

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Sessions")
                    .font(.headline)
                Spacer()
                if !recentPerformances.isEmpty {
                    NavigationLink {
                        ExerciseHistoryView(catalogID: catalogID)
                    } label: {
                        Text("See All")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.exerciseInfoAllHistoryLink)
                }
            }

            if recentPerformances.isEmpty {
                ContentUnavailableView("No History", systemImage: "clock.arrow.circlepath", description: Text("Complete a workout with this exercise to see your history."))
            } else {
                VStack(spacing: 10) {
                    ForEach(recentPerformances) { performance in
                        ExerciseHistoryPerformanceCard(
                            performance: performance,
                            weightUnit: weightUnit,
                            availableCopyModes: [],
                            showSheetBackground: false,
                            onCopy: nil
                        )
                    }
                }
            }
        }
    }

    // MARK: - Suggestion Settings

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
        .accessibilityIdentifier(AccessibilityIdentifiers.exerciseInfoSuggestionSettingsButton)
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
}

// MARK: - Chart Types

private enum ChartMetric: String, CaseIterable, Identifiable {
    case estimatedOneRepMax = "Est. 1RM"
    case topWeight = "Top Weight"
    case volume = "Volume"
    case reps = "Reps"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .estimatedOneRepMax: return String(localized: "Est. 1RM")
        case .topWeight: return String(localized: "Top Weight")
        case .volume: return String(localized: "Volume")
        case .reps: return String(localized: "Reps")
        }
    }

    var tint: Color {
        switch self {
        case .estimatedOneRepMax: return .red
        case .topWeight: return .blue
        case .volume: return .green
        case .reps: return .orange
        }
    }

    func formattedValueText(_ value: Double, weightUnit: WeightUnit) -> String {
        let digits: ClosedRange<Int>
        switch self {
        case .estimatedOneRepMax: digits = 0...1
        case .topWeight: digits = 0...2
        case .volume, .reps: digits = 0...0
        }
        return "\(value.formatted(.number.precision(.fractionLength(digits)))) \(self == .reps ? "reps" : weightUnit.rawValue)"
    }
}

private struct ExerciseInfoMetricPoint: Identifiable, Equatable {
    let id: Date
    let date: Date
    let value: Double
    init(date: Date, value: Double) { self.id = date; self.date = date; self.value = value }
}

// MARK: - Chart Card

private struct ExerciseInfoChartCard: View {
    let points: [ExerciseInfoMetricPoint]
    let tint: Color
    let formatValueText: (Double) -> String

    @State private var selectedDate: Date?

    private var timeSeriesSamples: [TimeSeriesSample] {
        points.map { TimeSeriesSample(date: $0.date, value: $0.value) }
    }

    private var chartLayout: TimeSeriesChartLayout {
        TimeSeriesChartLayout(rangeFilter: .all, samples: timeSeriesSamples, now: .now, calendar: .autoupdatingCurrent, aggregation: .maximum)
    }

    private var linePoints: [TimeSeriesBucketedPoint] {
        timeSeriesAnchoredLinePoints(points: chartLayout.points, samples: timeSeriesSamples, domain: chartLayout.currentDomain)
    }

    private var yDomain: ClosedRange<Double> {
        let values = chartLayout.points.map(\.value)
        guard let min = values.min(), let max = values.max() else { return 0...1 }
        if min == max {
            let pad = Swift.max(abs(min) * 0.05, 1)
            return (min - pad)...(max + pad)
        }
        let range = max - min
        let pad = Swift.max(range * 0.15, range < 5 ? 0.5 : 1)
        return (min - pad)...(max + pad)
    }

    private var displayedPoint: TimeSeriesBucketedPoint? {
        guard let selectedDate else { return nil }
        return selectedTimeSeriesPoint(in: chartLayout.points, for: selectedDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Chart {
                ForEach(linePoints) { point in
                    LineMark(x: .value("Date", point.date), y: .value("Value", point.value))
                        .foregroundStyle(tint)
                        .interpolationMethod(.catmullRom)
                }
                ForEach(chartLayout.points) { point in
                    PointMark(x: .value("Date", point.date), y: .value("Value", point.value))
                        .foregroundStyle(tint)
                    if point.id == displayedPoint?.id {
                        RuleMark(x: .value("Selected", point.date))
                            .foregroundStyle(tint)
                            .lineStyle(.init(lineWidth: 1, dash: [4, 4]))
                            .annotation(position: .top, spacing: 8, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(timeSeriesBucketLabelText(for: point, bucketStyle: chartLayout.bucketStyle))
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
            .frame(height: 200)
            .chartYScale(domain: yDomain)
            .chartXSelection(value: $selectedDate)
            .chartXScale(domain: chartLayout.currentDomain)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(v, format: .number.precision(.fractionLength(0)))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: chartLayout.axisDates) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let d = value.as(Date.self) {
                            Text(timeSeriesAxisLabelText(for: d, style: chartLayout.axisLabelStyle))
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: - Recent Session Card

private struct ExerciseInfoRecentCard: View {
    let performance: ExercisePerformance
    let weightUnit: WeightUnit

    private var completedSets: [SetPerformance] {
        (performance.sets ?? []).filter(\.complete).sorted { ($0.index) < ($1.index) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(formattedDateRange(start: performance.date))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            if completedSets.isEmpty {
                Text("No completed sets")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(completedSets.prefix(5)) { set in
                        HStack(spacing: 8) {
                            Text("Set \(set.index + 1)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .frame(width: 44, alignment: .leading)
                            Text(setDescription(for: set))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                    }
                    if completedSets.count > 5 {
                        Text("+\(completedSets.count - 5) more sets")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .appCardStyle()
    }

    private func setDescription(for set: SetPerformance) -> String {
        let reps = set.reps
        let weight = set.weight
        if weight > 0 && reps > 0 {
            return "\(reps) × \(formattedWeightText(weightUnit.fromKg(weight), unit: weightUnit, fractionDigits: 0...2))"
        } else if reps > 0 {
            return "\(reps) reps"
        } else if weight > 0 {
            return formattedWeightText(weightUnit.fromKg(weight), unit: weightUnit, fractionDigits: 0...2)
        }
        return "—"
    }
}

#Preview(traits: .sampleDataSuggestionGeneration) {
    ExerciseInfoView(
        catalogID: "dumbbell_incline_bench_press",
        isSelected: false,
        onToggleSelect: {}
    )
}

import SwiftUI
import SwiftData
import Charts
import AppIntents
import CoreSpotlight
import MuscleMap
import TipKit

private extension Muscle {
    var detailMuscleMapMuscles: [MuscleMap.Muscle] {
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
    @Query private var performances: [ExercisePerformance]
    @Query(AppSettings.single) private var appSettings: [AppSettings]

    private let appRouter = AppRouter.shared

    private var weightUnit: WeightUnit { appSettings.first?.weightUnit ?? .lbs }

    @State private var selectedMetric: ChartMetric = .topWeight
    @State private var suggestionSettingsExercise: Exercise?
    @State private var addedConfirmationDestination: ActiveFlowAddDestination?
    private let exerciseHistoryChartTip = ExerciseHistoryChartTip()
    #if DEBUG
    @State private var isSeedingDebugHistory = false
    #endif

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

    private enum ActiveFlowAddDestination {
        case workout
        case plan

        var addLabel: String {
            switch self {
            case .workout: return String(localized: "Add to Workout")
            case .plan: return String(localized: "Add to Plan")
            }
        }

        var confirmationTitle: String {
            switch self {
            case .workout: return String(localized: "Added to Workout")
            case .plan: return String(localized: "Added to Plan")
            }
        }

        func confirmationMessage(exerciseName: String) -> String {
            switch self {
            case .workout: return String(localized: "\(exerciseName) was added to your active workout.")
            case .plan: return String(localized: "\(exerciseName) was added to your active plan.")
            }
        }
    }

    private var activeFlowAddDestination: ActiveFlowAddDestination? {
        if appRouter.activeWorkoutSession?.statusValue == .active {
            return .workout
        }
        if appRouter.activeWorkoutPlan != nil {
            return .plan
        }
        return nil
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

    private var recentPerformances: [ExercisePerformance] {
        Array(performances.prefix(3))
    }

    private var howToSteps: [String] {
        ExerciseCatalog.byID[catalogID]?.steps ?? []
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

    private func bestMetricTitle(for metric: ChartMetric) -> String {
        switch metric {
        case .estimatedOneRepMax, .topWeight:
            return "Highest"
        case .volume:
            return "Best"
        case .reps:
            return "Max"
        }
    }

    private func bestMetricValueText(for metric: ChartMetric) -> String {
        guard let bestValue = points(for: metric).map(\.value).max() else { return "" }
        return metric.formattedValueText(bestValue, weightUnit: weightUnit)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 44) {
                // Muscle map is intrinsic to the exercise — always show it, even with no history.
                if let exercise, !exercise.musclesTargeted.isEmpty {
                    muscleMapSection(for: exercise)
                }

                if hasContent {
                    if !statItems.isEmpty {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(statItems) { item in
                                SummaryStatCard(title: item.title, text: item.value)
                            }
                        }
                    }

                    if let activeMetric {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                ExerciseMetricHeaderValue(title: "Latest", value: latestMetricValueText)

                                Spacer(minLength: 16)

                                ExerciseMetricHeaderValue(title: bestMetricTitle(for: activeMetric), value: bestMetricValueText(for: activeMetric), alignment: .trailing, frameAlignment: .trailing)
                            }

                            ExerciseMetricChartCard(
                                points: points(for: activeMetric),
                                tint: activeMetric.tint,
                                aggregation: aggregation(for: activeMetric),
                                formatValueText: { activeMetric.formattedValueText($0, weightUnit: weightUnit) }
                            )
                            .id(activeMetric.id)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                            .popoverTip(exerciseHistoryChartTip)

                            if availableMetrics.count > 1 {
                                Picker("Metric", selection: $selectedMetric) {
                                    ForEach(availableMetrics) { metric in
                                        Text(metric.displayName).tag(metric)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .accessibilityIdentifier(AccessibilityIdentifiers.exerciseDetailMetricPicker)
                            }
                        }
                        .padding(16)
                        .appCardStyle()
                        .animation(.smooth(duration: 0.22), value: activeMetric.id)
                    } else if totalSessions > 0 {
                        chartUnavailableCard
                    }
                } else if exercise != nil {
                    noHistoryCard
                }

                if !howToSteps.isEmpty {
                    howToSection
                }

                if let exercise {
                    suggestionSettingsSection(for: exercise)
                }

                if !recentPerformances.isEmpty {
                    recentPerformancesSection
                }
            }
            .padding([.horizontal, .bottom])
        }
        .quickActionContentBottomInset()
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appBackground()
        .sheet(item: $suggestionSettingsExercise) { exercise in
            ExerciseSuggestionSettingsSheet(exercise: exercise)
                .presentationBackground(Color.sheetBg)
        }
        .alert(addedConfirmationDestination?.confirmationTitle ?? "", isPresented: addedConfirmationBinding) {
            Button("OK", role: .cancel) {
                addedConfirmationDestination = nil
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.exerciseDetailAddedConfirmationDismissButton)
        } message: {
            if let destination = addedConfirmationDestination {
                Text(destination.confirmationMessage(exerciseName: displayName))
            }
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
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let exercise {
                    #if DEBUG
                    Button("Seed", systemImage: "chart.line.uptrend.xyaxis") {
                        seedDebugHistory(for: exercise)
                    }
                    .disabled(isSeedingDebugHistory)
                    .accessibilityIdentifier(AccessibilityIdentifiers.debugSeedExerciseDetailHistoryButton)
                    #endif

                    if let destination = activeFlowAddDestination {
                        Button(destination.addLabel, systemImage: "plus") {
                            if appRouter.addExerciseToActiveFlow(exercise) {
                                addedConfirmationDestination = destination
                            }
                        }
                        .accessibilityIdentifier(AccessibilityIdentifiers.exerciseDetailAddToActiveFlowButton)
                        .accessibilityLabel(destination.addLabel)
                    }
                }
            }
        }
    }

    private var addedConfirmationBinding: Binding<Bool> {
        Binding(
            get: { addedConfirmationDestination != nil },
            set: { isPresented in
                if !isPresented {
                    addedConfirmationDestination = nil
                }
            }
        )
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

    private func muscleMapSection(for exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Muscles Targeted")
                .font(.headline)

            HStack(spacing: 12) {
                highlightedBodyView(for: exercise, side: .front)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)

                highlightedBodyView(for: exercise, side: .back)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
            }
            .padding(12)
            .appCardStyle()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(exercise.musclesTargeted.enumerated()), id: \.element) { index, muscle in
                        Text(muscle.displayName)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background((index == 0 ? Color.red : Color.orange).opacity(index == 0 ? 0.2 : 0.15), in: Capsule())
                    }
                }
            }
        }
    }

    private func highlightedBodyView(for exercise: Exercise, side: BodySide) -> BodyView {
        var view = BodyView(gender: .male, side: side)
        for (index, appMuscle) in exercise.musclesTargeted.enumerated() {
            let color: Color = index == 0 ? .red : .orange
            let opacity: Double = index == 0 ? 0.85 : 0.55
            for mapMuscle in appMuscle.detailMuscleMapMuscles {
                view = view.highlight(mapMuscle, color: color, opacity: opacity)
            }
        }
        return view
    }

    private var howToSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How To")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(howToSteps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(.blue, in: Circle())
                        Text(step)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            .padding(16)
            .appCardStyle()
        }
    }

    private var recentPerformancesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Recent Performances")
                    .font(.headline)
                Spacer()
                Button("See All") {
                    appRouter.push(to: .exerciseHistory(catalogID))
                }
                .font(.subheadline.weight(.semibold))
                .accessibilityIdentifier(AccessibilityIdentifiers.exerciseDetailAllHistoryButton)
            }

            ForEach(recentPerformances) { performance in
                ExerciseHistoryPerformanceCard(performance: performance, weightUnit: weightUnit, availableCopyModes: [], showSheetBackground: false, onCopy: nil)
            }
        }
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

    #if DEBUG
    private func seedDebugHistory(for exercise: Exercise) {
        guard !isSeedingDebugHistory else { return }
        Haptics.selection()
        isSeedingDebugHistory = true
        Task {
            do {
                try DebugOperations.seedExerciseHistory(for: exercise)
            } catch {
                AppLog.error("Debug exercise history seed failed", error: error)
            }
            isSeedingDebugHistory = false
        }
    }
    #endif
}

private struct ExerciseStatItem: Identifiable {
    let id = UUID()
    let title: String
    let value: String
}

private struct ExerciseMetricHeaderValue: View {
    let title: String
    let value: String
    var alignment: HorizontalAlignment = .leading
    var frameAlignment: Alignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: frameAlignment)
    }
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

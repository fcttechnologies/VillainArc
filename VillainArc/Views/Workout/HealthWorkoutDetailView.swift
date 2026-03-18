import SwiftUI
import SwiftData
import Charts

struct HealthWorkoutDetailView: View {
    let workout: HealthWorkout
    
    @Query(AppSettings.single) private var appSettings: [AppSettings]
    @State private var loader: HealthWorkoutDetailLoader
    
    init(workout: HealthWorkout) {
        self.workout = workout
        _loader = State(initialValue: HealthWorkoutDetailLoader(workout: workout))
    }
    
    private var distanceUnit: DistanceUnit {
        appSettings.first?.distanceUnit ?? .systemDefault
    }
    
    private var durationText: String {
        secondsToTimeWithHours(Int(loader.summary.duration.rounded()))
    }
    
    private var activeEnergyText: String {
        guard let activeEnergyBurned = loader.summary.activeEnergyBurned else { return "-" }
        return "\(Int(activeEnergyBurned.rounded())) cal"
    }

    private var totalEnergyText: String? {
        guard let totalCalories = loader.summary.totalCalories else { return nil }
        return "\(Int(totalCalories.rounded())) cal"
    }
    
    private var distanceText: String {
        guard let totalDistance = loader.summary.totalDistance else { return "-" }
        return distanceUnit.display(totalDistance)
    }
    
    private var chartAccessibilitySummary: String {
        let parts = [
            loader.heartRateSummary.averageBPM.map { "Average \(Int($0.rounded())) bpm" },
            loader.heartRateSummary.minimumBPM.map { "Low \(Int($0.rounded())) bpm" },
            loader.heartRateSummary.maximumBPM.map { "High \(Int($0.rounded())) bpm" }
        ]
            .compactMap(\.self)
        
        return parts.isEmpty ? "No heart rate data available." : parts.joined(separator: ", ")
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 32) {
                if loader.isLoading {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Loading Apple Health details...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                summarySection
                
                if loader.heartRateSummary.hasContent {
                    heartRateSection
                }

                if loader.energyPoints.count >= 2 {
                    energySection
                }
                
                if !loader.metrics.isEmpty {
                    metricsSection
                }
                
                if loader.activities.count > 1 {
                    activitiesSection
                }
                
            }
            .padding(.horizontal)
            .padding(.vertical, 20)
        }
        .navigationTitle(loader.summary.activityTypeDisplayName)
        .navigationSubtitle(Text(formattedDateRange(start: loader.summary.startDate, end: loader.summary.endDate, includeTime: true)))
        .toolbarTitleDisplayMode(.inline)
        .task(id: workout.healthWorkoutUUID) {
            await loader.loadIfNeeded()
        }
    }
    
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Summary")
                .font(.headline)
            
            SummaryStatCard(title: "Source", value: loader.summary.sourceName)
            
            HStack(alignment: .top, spacing: 12) {
                SummaryStatCard(title: "Duration", value: durationText)
                SummaryStatCard(title: "Active", value: activeEnergyText)
                
                if loader.summary.totalDistance != nil {
                    SummaryStatCard(title: "Distance", value: distanceText)
                }
            }

            if let totalEnergyText {
                SummaryStatCard(title: "Total", value: totalEnergyText)
            }
            
            if loader.isUsingCachedSummaryOnly {
                Text("This workout is no longer available in Apple Health. VillainArc is showing the last synced summary.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if let loadErrorMessage = loader.loadErrorMessage {
                Text(loadErrorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var heartRateSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Heart")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                if let average = loader.heartRateSummary.averageBPM {
                    SummaryStatCard(title: "Average", value: "\(Int(average.rounded())) bpm")
                }
                
                if let minimum = loader.heartRateSummary.minimumBPM {
                    SummaryStatCard(title: "Low", value: "\(Int(minimum.rounded())) bpm")
                }
                
                if let maximum = loader.heartRateSummary.maximumBPM {
                    SummaryStatCard(title: "High", value: "\(Int(maximum.rounded())) bpm")
                }
            }
            
            if loader.heartRatePoints.count >= 2 {
                HealthWorkoutHeartRateChartCard(points: loader.heartRatePoints, averageBPM: loader.heartRateSummary.averageBPM)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Heart rate chart")
                    .accessibilityValue(chartAccessibilitySummary)
            }
        }
    }

    private var energySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Energy")
                .font(.headline)

            HealthWorkoutEnergyChartCard(points: loader.energyPoints)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Active energy chart")
                .accessibilityValue(energyChartAccessibilitySummary)
        }
    }
    
    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Metrics")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(loader.metrics) { metric in
                    SummaryStatCard(title: metric.title, value: formattedMetricValue(metric))
                }
            }
        }
    }
    
    private var activitiesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Activities")
                .font(.headline)
            
            ForEach(loader.activities) { activity in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(activity.title)
                            .fontWeight(.semibold)
                        Spacer()
                        Text(secondsToTimeWithHours(Int(activity.duration.rounded())))
                            .foregroundStyle(.secondary)
                    }
                    
                    if let energyBurned = activity.energyBurned {
                        Text("\(Int(energyBurned.rounded())) cal")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .fontDesign(.rounded)
                .padding(.vertical, 6)
            }
        }
    }
    
    private func formattedMetricValue(_ metric: HealthWorkoutDetailMetric) -> String {
        switch metric.valueStyle {
        case .integer:
            return metric.value.formatted(.number.precision(.fractionLength(0)))
        case .breathsPerMinute:
            return "\(metric.value.formatted(.number.precision(.fractionLength(1)))) br/min"
        case .watts:
            return "\(metric.value.formatted(.number.precision(.fractionLength(0...1)))) W"
        case .cadencePerMinute:
            return "\(metric.value.formatted(.number.precision(.fractionLength(0...1)))) rpm"
        case .milliseconds:
            return "\(metric.value.formatted(.number.precision(.fractionLength(0)))) ms"
        case .centimeters:
            return "\((metric.value * 100).formatted(.number.precision(.fractionLength(0...1)))) cm"
        case .score:
            return metric.value.formatted(.number.precision(.fractionLength(0...1)))
        }
    }

    private var energyChartAccessibilitySummary: String {
        guard let latest = loader.energyPoints.last?.cumulativeCalories else {
            return "No active energy data available."
        }

        return "Cumulative active energy burned ending at \(Int(latest.rounded())) calories."
    }
    
}

private struct HealthWorkoutHeartRateChartCard: View {
    let points: [HealthWorkoutHeartRatePoint]
    let averageBPM: Double?
    
    @State private var selectedDate: Date?
    
    private var displayedPoint: HealthWorkoutHeartRatePoint? {
        guard let selectedDate else { return nil }
        return nearestPoint(to: selectedDate)
    }
    
    var body: some View {
        Chart(points) { point in
            if let averageBPM {
                RuleMark(y: .value("Average Heart Rate", averageBPM))
                    .foregroundStyle(Color.primary.opacity(0.45))
                    .lineStyle(.init(lineWidth: 1, dash: [6, 4]))
            }
            
            AreaMark(x: .value("Time", point.date), y: .value("Heart Rate", point.bpm))
                .foregroundStyle(LinearGradient(colors: [.red.opacity(0.28), .red.opacity(0.06)], startPoint: .top, endPoint: .bottom))
            
            LineMark(x: .value("Time", point.date), y: .value("Heart Rate", point.bpm))
                .foregroundStyle(.red)
                .lineStyle(.init(lineWidth: 3, lineCap: .round, lineJoin: .round))
            
            if point.id == displayedPoint?.id {
                PointMark(x: .value("Time", point.date), y: .value("Heart Rate", point.bpm))
                    .foregroundStyle(.red)
                    .symbolSize(80)
                
                RuleMark(x: .value("Selected Time", point.date))
                    .foregroundStyle(.red)
                    .lineStyle(.init(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .top, spacing: 8, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(point.date.formatted(date: .omitted, time: .shortened))
                                .foregroundStyle(.white.opacity(0.9))
                            Text("\(Int(point.bpm.rounded())) bpm")
                                .font(.title3)
                                .foregroundStyle(.white)
                        }
                        .bold()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.red.gradient, in: .rect(cornerRadius: 12))
                    }
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.hour().minute())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .frame(height: 220)
        .padding(14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18))
        .onChange(of: points) { _, newPoints in
            guard let selectedDate else { return }
            self.selectedDate = nearestPoint(in: newPoints, to: selectedDate)?.date
        }
    }
    
    private func nearestPoint(to date: Date) -> HealthWorkoutHeartRatePoint? {
        nearestPoint(in: points, to: date)
    }
    
    private func nearestPoint(in points: [HealthWorkoutHeartRatePoint], to date: Date) -> HealthWorkoutHeartRatePoint? {
        points.min { left, right in
            abs(left.date.timeIntervalSince(date)) < abs(right.date.timeIntervalSince(date))
        }
    }
}

private struct HealthWorkoutEnergyChartCard: View {
    let points: [HealthWorkoutEnergyPoint]

    @State private var selectedDate: Date?

    private var displayedPoint: HealthWorkoutEnergyPoint? {
        guard let selectedDate else { return nil }
        return nearestPoint(to: selectedDate)
    }

    var body: some View {
        Chart(points) { point in
            AreaMark(x: .value("Time", point.date), y: .value("Calories", point.cumulativeCalories))
                .foregroundStyle(LinearGradient(colors: [.orange.opacity(0.28), .orange.opacity(0.06)], startPoint: .top, endPoint: .bottom))

            LineMark(x: .value("Time", point.date), y: .value("Calories", point.cumulativeCalories))
                .foregroundStyle(.orange)
                .lineStyle(.init(lineWidth: 3, lineCap: .round, lineJoin: .round))

            if point.id == displayedPoint?.id {
                PointMark(x: .value("Time", point.date), y: .value("Calories", point.cumulativeCalories))
                    .foregroundStyle(.orange)
                    .symbolSize(80)

                RuleMark(x: .value("Selected Time", point.date))
                    .foregroundStyle(.orange)
                    .lineStyle(.init(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .top, spacing: 8, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(point.date.formatted(date: .omitted, time: .shortened))
                                .foregroundStyle(.white.opacity(0.9))
                            Text("\(Int(point.cumulativeCalories.rounded())) cal")
                                .font(.title3)
                                .foregroundStyle(.white)
                        }
                        .bold()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.orange.gradient, in: .rect(cornerRadius: 12))
                    }
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.hour().minute())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .frame(height: 220)
        .padding(14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18))
        .onChange(of: points) { _, newPoints in
            guard let selectedDate else { return }
            self.selectedDate = nearestPoint(in: newPoints, to: selectedDate)?.date
        }
    }

    private func nearestPoint(to date: Date) -> HealthWorkoutEnergyPoint? {
        nearestPoint(in: points, to: date)
    }

    private func nearestPoint(in points: [HealthWorkoutEnergyPoint], to date: Date) -> HealthWorkoutEnergyPoint? {
        points.min { left, right in
            abs(left.date.timeIntervalSince(date)) < abs(right.date.timeIntervalSince(date))
        }
    }
}

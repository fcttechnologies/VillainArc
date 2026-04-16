import SwiftUI
import SwiftData
import Charts
import HealthKit
import MapKit

struct HealthWorkoutDetailView: View {
    let workout: HealthWorkout

    @Query(AppSettings.single) private var appSettings: [AppSettings]
    @Query(UserProfile.single) private var userProfiles: [UserProfile]
    @State private var loader: HealthWorkoutDetailLoader

    init(workout: HealthWorkout) {
        self.workout = workout
        _loader = State(initialValue: HealthWorkoutDetailLoader(workout: workout))
    }

    private var distanceUnit: DistanceUnit {
        appSettings.first?.distanceUnit ?? .systemDefault
    }

    private var energyUnit: EnergyUnit {
        appSettings.first?.energyUnit ?? .systemDefault
    }

    private var estimatedMaxHeartRate: Double? {
        guard let birthday = userProfiles.first?.birthday else { return nil }
        let years = Calendar.current.dateComponents([.year], from: birthday, to: loader.summary.startDate).year ?? 0
        let age = max(1, years)
        return max(120, Double(220 - age))
    }

    var body: some View {
        ScrollView {
            HealthWorkoutDetailContent(loader: loader, distanceUnit: distanceUnit, energyUnit: energyUnit, estimatedMaxHeartRate: estimatedMaxHeartRate, extraSummaryItems: [], effortCardModel: effortCardModel)
            .padding(.horizontal)
            .padding(.vertical, 20)
        }
        .quickActionContentBottomInset()
        .appBackground()
        .navigationTitle(loader.summary.activityTypeDisplayName)
        .navigationSubtitle(Text(formattedDateRange(start: loader.summary.startDate, end: loader.summary.endDate, includeTime: true)))
        .toolbarTitleDisplayMode(.inline)
        .task(id: workout.healthWorkoutUUID) {
            await loader.loadIfNeeded(distanceUnit: distanceUnit, estimatedMaxHeartRate: estimatedMaxHeartRate)
        }
    }

    private var effortCardModel: WorkoutEffortCardModel? {
        guard let summary = loader.effortSummary else { return nil }

        switch summary.source {
        case .actualScore, .estimatedScore:
            let roundedScore = max(1, min(Int(summary.value.rounded()), 10))
            return .init(title: workoutEffortTitle(roundedScore), description: workoutEffortDescription(roundedScore), valueText: summary.value.formatted(.number.precision(.fractionLength(0...1))), score: summary.value, caption: summary.source == .estimatedScore ? "Estimated from Apple Health" : nil)
        case .physicalEffort:
            return .init(title: "Physical Effort", description: "Average estimated physical effort was \(summary.value.formatted(.number.precision(.fractionLength(0...1)))) METs.", valueText: summary.value.formatted(.number.precision(.fractionLength(0...1))), score: nil, caption: "From Apple Health")
        }
    }

}

struct HealthWorkoutDetailContent: View {
    let loader: HealthWorkoutDetailLoader
    let distanceUnit: DistanceUnit
    let energyUnit: EnergyUnit
    let estimatedMaxHeartRate: Double?
    let extraSummaryItems: [SummaryStatItem]
    let effortCardModel: WorkoutEffortCardModel?

    private var summaryGridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 140), spacing: 12, alignment: .top)]
    }

    private var metricGridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 130), spacing: 12, alignment: .top)]
    }

    private var durationText: String {
        let activeDurationText = formattedDuration(loader.summary.activeDuration)
        guard loader.summary.pausedDuration >= 1 else { return activeDurationText }
        let totalDurationText = formattedDuration(loader.summary.totalDuration)
        return "\(activeDurationText) active\n\(totalDurationText) total"
    }

    private var activeEnergyText: String {
        guard let activeEnergyBurned = loader.summary.activeEnergyBurned else { return "-" }
        return formattedEnergyText(activeEnergyBurned, unit: energyUnit)
    }

    private var totalEnergyText: String? {
        guard let totalCalories = loader.summary.totalCalories else { return nil }
        return formattedEnergyText(totalCalories, unit: energyUnit)
    }

    private var distanceText: String {
        guard let totalDistance = loader.summary.totalDistance else { return "-" }
        return formattedDistanceText(totalDistance, unit: distanceUnit)
    }

    private var paceText: String? {
        guard loader.summary.activityType.supportsPacePresentation,
              let totalDistance = loader.summary.totalDistance else {
            return nil
        }

        return formattedPaceText(duration: loader.summary.activeDuration, distanceMeters: totalDistance, distanceUnit: distanceUnit)
    }

    private var summaryItems: [SummaryStatItem] {
        var items = [SummaryStatItem(title: "Duration", value: durationText)]
        if let paceText { items.append(SummaryStatItem(title: "Pace", value: paceText)) }
        if loader.summary.totalDistance != nil { items.append(SummaryStatItem(title: "Distance", value: distanceText)) }
        items.append(SummaryStatItem(title: "Active Energy", value: activeEnergyText))
        if let totalEnergyText { items.append(SummaryStatItem(title: "Total Energy", value: totalEnergyText)) }
        items.append(contentsOf: extraSummaryItems)
        return items
    }

    private var showsSplitSection: Bool {
        loader.summary.activityType.supportsPacePresentation && !loader.splits.isEmpty
    }

    private var routeCoordinates: [CLLocationCoordinate2D] {
        loader.routePoints.map(\.coordinate)
    }

    private var chartAccessibilitySummary: String {
        let parts = [
            loader.heartRateSummary.averageBPM.map { String(localized: "Average \(formattedHeartRateText($0))") },
            loader.heartRateSummary.maximumBPM.map { String(localized: "High \(formattedHeartRateText($0))") }
        ]
            .compactMap(\.self)

        return parts.isEmpty ? "No heart rate data available." : parts.joined(separator: ", ")
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 32) {
            summarySection
            
            if loader.isLoading {
                ProgressView("Loading Apple Health details...")
                    .frame(maxWidth: .infinity)
            }

            if routeCoordinates.count >= 2 {
                routeSection
            }

            if loader.heartRateSummary.hasContent {
                heartRateSection
            }

            if !loader.heartRateZones.isEmpty {
                heartRateZonesSection
            }

            if showsSplitSection {
                splitsSection
            }

            if !loader.metrics.isEmpty {
                metricsSection
            }

            if loader.activities.count > 1 {
                activitiesSection
            }
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Summary")
                .font(.headline)

            LazyVGrid(columns: summaryGridColumns, spacing: 12) {
                ForEach(summaryItems) { item in
                    SummaryStatCard(title: item.title, text: item.value)
                }
            }

            if let effortCardModel {
                WorkoutEffortCardView(model: effortCardModel)
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier(AccessibilityIdentifiers.healthWorkoutDetailEffortDisplay)
                    .accessibilityLabel(AccessibilityText.healthWorkoutDetailEffortLabel)
                    .accessibilityValue(healthEffortAccessibilityValue)
            }

            if loader.isUsingCachedSummaryOnly {
                Text("This workout is no longer available in Apple Health. Villain Arc is showing the last synced summary.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if let loadErrorMessage = loader.loadErrorMessage {
                Text(loadErrorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var healthEffortAccessibilityValue: String {
        guard let summary = loader.effortSummary else { return "" }
        switch summary.source {
        case .actualScore:
            return String(localized: "\(summary.value.formatted(.number.precision(.fractionLength(0...1)))) out of 10")
        case .estimatedScore:
            return String(localized: "Estimated \(summary.value.formatted(.number.precision(.fractionLength(0...1)))) out of 10")
        case .physicalEffort:
            return String(localized: "\(summary.value.formatted(.number.precision(.fractionLength(0...1)))) METs")
        }
    }

    private var routeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Route")
                .font(.headline)

            HealthWorkoutRouteMapCard(coordinates: routeCoordinates)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(AccessibilityText.healthWorkoutRouteMapLabel)
                .accessibilityValue(AccessibilityText.healthWorkoutRouteMapValue(pointCount: routeCoordinates.count))
        }
    }

    private var heartRateSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Heart Rate")
                .font(.headline)

            if loader.heartRatePoints.count >= 2 {
                HealthWorkoutHeartRateChartCard(points: loader.heartRatePoints, summary: loader.heartRateSummary, estimatedMaxHeartRate: estimatedMaxHeartRate)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(AccessibilityText.healthWorkoutHeartRateChartLabel)
                    .accessibilityValue(AccessibilityText.healthWorkoutHeartRateChartValue(summary: chartAccessibilitySummary))
            }
        }
    }

    private var heartRateZonesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Zones")
                .font(.headline)

            ForEach(loader.heartRateZones) { zone in
                HealthWorkoutZoneRow(zoneTitle: "Zone \(zone.zone)", rangeText: heartRateZoneRangeText(for: zone), durationText: formattedDuration(zone.duration), percentageText: zone.percentage.formatted(.percent.precision(.fractionLength(0))), color: heartRateZoneColor(for: zone.zone))
            }
        }
    }

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Metrics")
                .font(.headline)

            LazyVGrid(columns: metricGridColumns, spacing: 12) {
                ForEach(loader.metrics) { metric in
                    SummaryStatCard(title: metric.title, text: formattedMetricValue(metric))
                }
            }
        }
    }

    private var splitsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Splits")
                .font(.headline)

            ForEach(loader.splits) { split in
                HealthWorkoutSplitRow(splitLabel: formattedSplitLabel(split), paceText: formattedSplitPace(split) ?? "-", heartRateText: formattedSplitHeartRate(split), tint: heartRateZoneColor(for: zoneColorIndex(for: split.averageHeartRate)))
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
                        Text(formattedEnergyText(energyBurned, unit: energyUnit))
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

    private func formattedDuration(_ duration: TimeInterval) -> String {
        secondsToTimeWithHours(Int(duration.rounded()))
    }

    private func formattedSplitLabel(_ split: HealthWorkoutSplitSummary) -> String {
        formattedDistanceText(split.markerDistanceMeters, unit: distanceUnit, fractionDigits: 0...2)
    }

    private func formattedSplitPace(_ split: HealthWorkoutSplitSummary) -> String? {
        formattedPaceText(duration: split.duration, distanceMeters: split.segmentDistanceMeters, distanceUnit: distanceUnit)
    }

    private func formattedSplitHeartRate(_ split: HealthWorkoutSplitSummary) -> String {
        guard let averageHeartRate = split.averageHeartRate else { return "-" }
        return formattedHeartRateValue(averageHeartRate, fractionDigits: 0...0)
    }

    private func heartRateZoneRangeText(for zone: HealthWorkoutHeartRateZoneSummary) -> String {
        formattedHeartRateRangeText(lower: zone.lowerBoundBPM, upper: zone.upperBoundBPM)
    }

    private func heartRateZoneColor(for zone: Int) -> Color {
        switch zone {
        case 1:
            return .blue
        case 2:
            return .green
        case 3:
            return .yellow
        case 4:
            return .orange
        default:
            return .red
        }
    }

    private func zoneColorIndex(for averageHeartRate: Double?) -> Int {
        guard let averageHeartRate,
              let estimatedMaxHeartRate,
              estimatedMaxHeartRate > 0 else {
            return 1
        }

        let percentage = averageHeartRate / estimatedMaxHeartRate
        switch percentage {
        case ..<0.6:
            return 1
        case ..<0.7:
            return 2
        case ..<0.8:
            return 3
        case ..<0.9:
            return 4
        default:
            return 5
        }
    }
}

private struct HealthWorkoutZoneRow: View {
    let zoneTitle: String
    let rangeText: String
    let durationText: String
    let percentageText: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(color)
                .frame(width: 10, height: 52)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(zoneTitle)
                    .font(.headline)
                Text(rangeText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(durationText)
                    .font(.headline)
                Text(percentageText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .fontDesign(.rounded)
        .padding(12)
        .appCardStyle()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(zoneTitle)
        .accessibilityValue(AccessibilityText.healthWorkoutZoneValue(durationText: durationText, percentageText: percentageText, rangeText: rangeText))
    }
}

private struct HealthWorkoutSplitRow: View {
    let splitLabel: String
    let paceText: String
    let heartRateText: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Text(splitLabel)
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(paceText)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .center)

            splitHeartRateView
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .fontDesign(.rounded)
        .padding(12)
        .appCardStyle()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(splitLabel)
        .accessibilityValue(AccessibilityText.healthWorkoutSplitValue(paceText: paceText, heartRateText: heartRateText))
    }

    @ViewBuilder
    private var splitHeartRateView: some View {
        if heartRateText == "-" {
            Text(heartRateText)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
        } else {
            HStack(spacing: 0) {
                Text(heartRateText)
                    .foregroundStyle(tint)
                Text(" \(heartRateUnitLabel())")
                    .foregroundStyle(.primary)
            }
            .fontWeight(.semibold)
        }
    }
}

private struct HealthWorkoutRouteMapCard: View {
    let coordinates: [CLLocationCoordinate2D]

    @State private var position: MapCameraPosition = .automatic

    private var region: MKCoordinateRegion {
        guard let first = coordinates.first else {
            return MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090), span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
        }

        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)

        let minLatitude = latitudes.min() ?? first.latitude
        let maxLatitude = latitudes.max() ?? first.latitude
        let minLongitude = longitudes.min() ?? first.longitude
        let maxLongitude = longitudes.max() ?? first.longitude

        let center = CLLocationCoordinate2D(latitude: (minLatitude + maxLatitude) / 2, longitude: (minLongitude + maxLongitude) / 2)
        let span = MKCoordinateSpan(latitudeDelta: max((maxLatitude - minLatitude) * 1.35, 0.01), longitudeDelta: max((maxLongitude - minLongitude) * 1.35, 0.01))

        return MKCoordinateRegion(center: center, span: span)
    }

    var body: some View {
        Map(position: $position, interactionModes: []) {
            MapPolyline(coordinates: coordinates)
                .stroke(.blue, lineWidth: 4)
        }
        .mapStyle(.standard(elevation: .realistic))
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .appCardStyle()
        .task(id: coordinates.count) {
            position = .region(region)
        }
    }
}

private extension HKWorkoutActivityType {
    var supportsPacePresentation: Bool {
        switch self {
        case .walking, .running, .hiking, .wheelchairWalkPace, .wheelchairRunPace:
            return true
        default:
            return false
        }
    }
}

private struct HealthWorkoutHeartRateChartCard: View {
    private struct Segment: Identifiable {
        let id: Int
        let start: HealthWorkoutHeartRatePoint
        let end: HealthWorkoutHeartRatePoint
    }

    let points: [HealthWorkoutHeartRatePoint]
    let summary: HealthWorkoutHeartRateSummary
    let estimatedMaxHeartRate: Double?
    
    @State private var selectedDate: Date?

    private var yAxisDomain: ClosedRange<Double> {
        let values = points.map(\.bpm)
        guard let minValue = values.min(), let maxValue = values.max() else {
            return 0...200
        }

        let padding = max(4, (maxValue - minValue) * 0.08)
        let lowerBound = max(0, floor(minValue - padding))
        let upperBound = ceil(maxValue + padding)
        if lowerBound == upperBound {
            return lowerBound...(upperBound + 1)
        }
        return lowerBound...upperBound
    }
    
    private var displayedPoint: HealthWorkoutHeartRatePoint? {
        guard let selectedDate else { return nil }
        return nearestPoint(to: selectedDate)
    }

    private var primaryTitle: String {
        guard let displayedPoint else { return "Average" }
        return displayedPoint.date.formatted(date: .omitted, time: .shortened)
    }

    private var primaryValue: String {
        if let displayedPoint { return formattedHeartRateText(displayedPoint.bpm, fractionDigits: 0...0) }
        guard let averageBPM = summary.averageBPM else { return "-" }
        return formattedHeartRateText(averageBPM, fractionDigits: 0...0)
    }

    private var segments: [Segment] {
        guard points.count >= 2 else { return [] }
        return zip(points.indices, zip(points, points.dropFirst())).map { index, pair in
            Segment(id: index, start: pair.0, end: pair.1)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(primaryTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(primaryValue)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(displayedPoint.map { HealthWorkoutHeartRatePalette.color(for: $0.bpm, estimatedMaxHeartRate: estimatedMaxHeartRate) } ?? .primary)
                }

                Spacer(minLength: 12)

                heartRateMetric(title: "High", value: summary.maximumBPM)
            }

            Chart {
                ForEach(segments) { segment in
                    LineMark(x: .value("Time", segment.start.date), y: .value("Heart Rate", segment.start.bpm), series: .value("Segment", segment.id))
                    .foregroundStyle(HealthWorkoutHeartRatePalette.color(for: segment.start.bpm, estimatedMaxHeartRate: estimatedMaxHeartRate))
                    .lineStyle(.init(lineWidth: 2, lineCap: .round, lineJoin: .round))

                    LineMark(x: .value("Time", segment.end.date), y: .value("Heart Rate", segment.end.bpm), series: .value("Segment", segment.id))
                    .foregroundStyle(HealthWorkoutHeartRatePalette.color(for: segment.start.bpm, estimatedMaxHeartRate: estimatedMaxHeartRate))
                    .lineStyle(.init(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }

                if let displayedPoint {
                    PointMark(x: .value("Time", displayedPoint.date), y: .value("Heart Rate", displayedPoint.bpm))
                        .foregroundStyle(HealthWorkoutHeartRatePalette.color(for: displayedPoint.bpm, estimatedMaxHeartRate: estimatedMaxHeartRate))
                        .symbolSize(80)

                    RuleMark(x: .value("Selected Time", displayedPoint.date))
                        .foregroundStyle(HealthWorkoutHeartRatePalette.color(for: displayedPoint.bpm, estimatedMaxHeartRate: estimatedMaxHeartRate))
                        .lineStyle(.init(lineWidth: 1, dash: [4, 4]))
                }
            }
            .chartXSelection(value: $selectedDate)
            .chartYScale(domain: yAxisDomain)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.hour().minute())
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing)
            }
            .frame(height: 220)
        }
        .padding(14)
        .appCardStyle()
        .onChange(of: points) { _, newPoints in
            guard let selectedDate else { return }
            self.selectedDate = nearestPoint(in: newPoints, to: selectedDate)?.date
        }
    }

    @ViewBuilder
    private func heartRateMetric(title: String, value: Double?) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(formattedHeartRateText(value, fractionDigits: 0...0))
                .font(.headline)
                .fontWeight(.semibold)
        }
        .frame(minWidth: 64, alignment: .trailing)
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

private enum HealthWorkoutHeartRatePalette {
    static func color(for bpm: Double, estimatedMaxHeartRate: Double?) -> Color {
        switch zone(for: bpm, estimatedMaxHeartRate: estimatedMaxHeartRate) {
        case 1:
            return .blue
        case 2:
            return .green
        case 3:
            return .yellow
        case 4:
            return .orange
        default:
            return .red
        }
    }

    static func zone(for bpm: Double, estimatedMaxHeartRate: Double?) -> Int {
        guard let estimatedMaxHeartRate, estimatedMaxHeartRate > 0 else { return 5 }

        let percentage = bpm / estimatedMaxHeartRate
        switch percentage {
        case ..<0.6:
            return 1
        case ..<0.7:
            return 2
        case ..<0.8:
            return 3
        case ..<0.9:
            return 4
        default:
            return 5
        }
    }
}

import SwiftUI
import Charts

struct WeightGoalSummaryCard: View {
    let activeGoal: WeightGoal?
    let analysis: WeightGoalAnalysis?
    let entries: [WeightEntry]
    let weightUnit: WeightUnit
    let hasGoalHistory: Bool
    let action: () -> Void
    
    private var progressModel: WeightGoalProgressChartModel? {
        guard let activeGoal else { return nil }
        return WeightGoalProgressChartModel(goal: activeGoal, entries: entries, now: .now)
    }
    
    private var latestGoalWeight: Double? {
        progressModel?.latestPoint?.value
    }
    
    var body: some View {
        Button(action: action) {
            Group {
                if let activeGoal {
                    HStack(alignment: .center, spacing: 0) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "target")
                                    .font(.subheadline)
                                Text("Weight Goal")
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(.secondary)
                            
                            Text(activeGoalTitle(activeGoal))
                                .font(.title3)
                                .fontWeight(.bold)
                                .fontDesign(.rounded)
                                .foregroundStyle(.primary)
                            
                            if let subtitleText {
                                Text(subtitleText)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                            }
                            
                            if let statusLine {
                                Text(statusLine)
                                    .font(.caption)
                                    .foregroundStyle(statusLineColor)
                            }
                            
                            if let progressText {
                                Text(progressText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .fontDesign(.rounded)
                        .foregroundStyle(.secondary)
                        .fontWeight(.semibold)
                        
                        Spacer()
                        
                        if let progressModel {
                            WeightGoalProgressChart(model: progressModel, weightUnit: weightUnit)
                                .frame(width: 160, height: 80)
                                .accessibilityHidden(true)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "target")
                                .font(.subheadline)
                            Text("Weight Goal")
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.secondary)
                        
                        Text("No active goal")
                            .font(.title3)
                            .bold()
                            .fontDesign(.rounded)
                        
                        Text(emptyStateText)
                            .foregroundStyle(.secondary)
                            .fontWeight(.semibold)
                    }
                }
            }
            .padding(4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.roundedRectangle(radius: 12))
        .accessibilityIdentifier(AccessibilityIdentifiers.healthWeightGoalSummaryButton)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(AccessibilityText.healthWeightGoalSummaryHint)
    }
    
    private func activeGoalTitle(_ goal: WeightGoal) -> String {
        if goal.type == .maintain {
            return "Maintain around \(formattedWeightText(goal.targetWeight, unit: weightUnit))"
        }
        
        return "\(goal.type.title) to \(formattedWeightText(goal.targetWeight, unit: weightUnit))"
    }
    
    private var subtitleText: String? {
        guard let targetDate = activeGoal?.targetDate else { return nil }
        return "Target \(formattedRecentDay(targetDate))"
    }
    
    private var progressText: String? {
        guard let activeGoal, let latestGoalWeight else { return nil }
        return weightGoalProgressText(goal: activeGoal, currentWeight: latestGoalWeight, unit: weightUnit)
    }
    
    private var statusLine: String? {
        guard let activeGoal, activeGoal.type != .maintain, let analysis else { return nil }
        return analysis.status.title
    }
    
    private var statusLineColor: Color {
        analysis?.status.foregroundStyle ?? .secondary
    }
    
    private var accessibilityValue: String {
        guard let activeGoal else { return AccessibilityText.healthWeightGoalSummaryEmptyValue }
        return AccessibilityText.healthWeightGoalSummaryValue(goalTitle: activeGoalTitle(activeGoal), statusText: analysis?.status.title, progressText: progressText, chartSummary: progressModel?.accessibilitySummary(unit: weightUnit))
    }
    
    private var emptyStateText: String {
        hasGoalHistory ? "Tap to view your goal history." : "Tap to create a weight goal."
    }
}

struct WeightGoalAnalysis {
    enum Status {
        case onTrack
        case aheadOfSchedule
        case behindSchedule
        
        var title: String {
            switch self {
            case .onTrack:
                return "On Track"
            case .aheadOfSchedule:
                return "Ahead of Schedule"
            case .behindSchedule:
                return "Behind Schedule"
            }
        }
        
        var foregroundStyle: Color {
            switch self {
            case .onTrack:
                return .green
            case .aheadOfSchedule:
                return .orange
            case .behindSchedule:
                return .red
            }
        }
    }
    
    let status: Status
    
    init?(goal: WeightGoal, entries: [WeightEntry]) {
        guard goal.type != .maintain else { return nil }
        
        let goalEntries = entries
            .filter { $0.date >= goal.startedAt && $0.date <= .now }
            .sorted { $0.date < $1.date }
        
        let dailyPoints = Self.dailyAveragedPoints(from: goalEntries)
        guard dailyPoints.count >= 5 else { return nil }
        
        let smoothedPoints = Self.smoothedPoints(from: dailyPoints, desiredWindow: 7)
        guard let latestPoint = smoothedPoints.last else { return nil }
        
        let recentLowerBound = max(goal.startedAt, Calendar.autoupdatingCurrent.date(byAdding: .day, value: -21, to: latestPoint.date) ?? goal.startedAt)
        let recentPoints = smoothedPoints.filter { $0.date >= recentLowerBound }
        guard recentPoints.count >= 5 else { return nil }
        guard let firstRecentPoint = recentPoints.first, let lastRecentPoint = recentPoints.last else { return nil }
        
        let spanDays = max(0, lastRecentPoint.date.timeIntervalSince(firstRecentPoint.date) / 86_400)
        guard spanDays >= 7 else { return nil }
        
        let actualPacePerWeek = ((lastRecentPoint.weight - firstRecentPoint.weight) / spanDays) * 7
        guard let targetPacePerWeek = Self.targetPacePerWeek(for: goal) else { return nil }
        
        status = Self.makeStatus(for: goal, actualPacePerWeek: actualPacePerWeek, targetPacePerWeek: targetPacePerWeek)
    }
    
    private static func targetPacePerWeek(for goal: WeightGoal) -> Double? {
        if let targetRatePerWeek = goal.targetRatePerWeek { return targetRatePerWeek }
        guard let targetDate = goal.targetDate, targetDate > goal.startedAt else { return nil }
        let weeks = targetDate.timeIntervalSince(goal.startedAt) / 604_800
        guard weeks > 0 else { return nil }
        return (goal.targetWeight - goal.startWeight) / weeks
    }
    
    private static func makeStatus(for goal: WeightGoal, actualPacePerWeek: Double, targetPacePerWeek: Double) -> Status {
        let tolerance = max(abs(targetPacePerWeek) * 0.2, 0.1)
        let difference = actualPacePerWeek - targetPacePerWeek
        if abs(difference) <= tolerance { return .onTrack }
        
        switch goal.type {
        case .cut:
            return actualPacePerWeek < targetPacePerWeek ? .aheadOfSchedule : .behindSchedule
        case .bulk:
            return actualPacePerWeek > targetPacePerWeek ? .aheadOfSchedule : .behindSchedule
        case .maintain:
            return .onTrack
        }
    }
    
    private static func dailyAveragedPoints(from entries: [WeightEntry]) -> [WeightGoalDailyPoint] {
        let calendar = Calendar.autoupdatingCurrent
        let buckets = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.date) }
        return buckets.compactMap { date, bucketEntries in
            guard !bucketEntries.isEmpty else { return nil }
            let averageWeight = bucketEntries.reduce(0) { $0 + $1.weight } / Double(bucketEntries.count)
            return WeightGoalDailyPoint(date: date, weight: averageWeight)
        }
        .sorted { $0.date < $1.date }
    }
    
    private static func smoothedPoints(from points: [WeightGoalDailyPoint], desiredWindow: Int) -> [WeightGoalDailyPoint] {
        let windowSize = min(desiredWindow, points.count)
        guard windowSize > 1 else { return points }
        return points.indices.map { index in
            let lowerBound = max(0, index - windowSize + 1)
            let window = points[lowerBound...index]
            let averageWeight = window.reduce(0) { $0 + $1.weight } / Double(window.count)
            return WeightGoalDailyPoint(date: points[index].date, weight: averageWeight)
        }
    }
}

private struct WeightGoalDailyPoint {
    let date: Date
    let weight: Double
}

struct WeightGoalProgressChartModel {
    private static let maintainBandDeltaKg = 1.0
    
    let goalType: WeightGoalType
    let startDate: Date
    let endDate: Date?
    let historyPoints: [TimeSeriesSample]
    let latestPoint: TimeSeriesSample?
    let targetWeight: Double
    let targetDate: Date?
    let currentDomain: ClosedRange<Date>
    let yDomain: ClosedRange<Double>
    let maintainBand: ClosedRange<Double>?
    
    init?(goal: WeightGoal, entries: [WeightEntry], now: Date, calendar: Calendar = .autoupdatingCurrent) {
        let goalEntries = entries.filter { $0.date >= goal.startedAt && $0.date <= now }.sorted { $0.date < $1.date }
        let historyPoints = Self.dailyAveragedPoints(from: goalEntries, calendar: calendar)
        let lowerBound = calendar.startOfDay(for: goal.startedAt)
        let effectiveEndDate = goal.endedAt ?? now
        let effectiveUpperBound = calendar.endOfDay(for: effectiveEndDate)
        let targetUpperBound = goal.endedAt == nil ? (goal.targetDate.map { calendar.endOfDay(for: $0) } ?? effectiveUpperBound) : effectiveUpperBound
        let upperBound = max(effectiveUpperBound, targetUpperBound)
        let visibleHistoryPoints = historyPoints.filter { $0.date >= lowerBound && $0.date <= upperBound }
        let maintainBand = goal.type == .maintain ? (goal.targetWeight - Self.maintainBandDeltaKg)...(goal.targetWeight + Self.maintainBandDeltaKg) : nil
        let bandValues = maintainBand.map { [$0.lowerBound, $0.upperBound] } ?? []
        let yValues = visibleHistoryPoints.map(\.value) + [goal.targetWeight] + bandValues
        
        self.goalType = goal.type
        self.startDate = goal.startedAt
        self.endDate = goal.endedAt
        self.historyPoints = visibleHistoryPoints
        self.latestPoint = visibleHistoryPoints.last
        self.targetWeight = goal.targetWeight
        self.targetDate = goal.targetDate
        self.currentDomain = lowerBound...upperBound
        self.yDomain = weightYDomain(for: yValues, minimumPadding: 0.5)
        self.maintainBand = maintainBand
    }
    
    func accessibilitySummary(unit: WeightUnit) -> String {
        var parts: [String] = []
        parts.append("Started \(formattedRecentDay(startDate))")
        if let latestPoint {
            parts.append("Latest \(formattedWeightText(latestPoint.value, unit: unit))")
        }
        parts.append("Target \(formattedWeightText(targetWeight, unit: unit))")
        if let targetDate, currentDomain.contains(targetDate) {
            parts.append("Target date \(formattedRecentDay(targetDate))")
        }
        if let endDate {
            parts.append("Ended \(formattedRecentDay(endDate))")
        }
        return parts.joined(separator: ", ")
    }
    
    private static func dailyAveragedPoints(from entries: [WeightEntry], calendar: Calendar) -> [TimeSeriesSample] {
        let buckets = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.date) }
        return buckets.compactMap { date, bucketEntries in
            guard !bucketEntries.isEmpty else { return nil }
            let averageWeight = bucketEntries.reduce(0) { $0 + $1.weight } / Double(bucketEntries.count)
            return TimeSeriesSample(date: date, value: averageWeight)
        }
        .sorted { $0.date < $1.date }
    }
}

func weightGoalProgressText(goal: WeightGoal, currentWeight: Double, unit: WeightUnit) -> String {
    let totalChangeNeeded = abs(goal.targetWeight - goal.startWeight)
    guard totalChangeNeeded > 0.05 else { return "At target" }
    let progress = min(max(abs(currentWeight - goal.startWeight), 0), totalChangeNeeded)
    return "\(formattedWeightText(progress, unit: unit)) / \(formattedWeightText(totalChangeNeeded, unit: unit))"
}

struct WeightGoalProgressChart: View {
    let model: WeightGoalProgressChartModel
    let weightUnit: WeightUnit
    
    private let historyTint = Color.blue
    private let targetTint = Color.green
    private let targetDateTint = Color.orange
    private let boundaryTint = Color.secondary
    
    private var targetWeightAnnotationPosition: AnnotationPosition {
        switch model.goalType {
        case .cut:
            return .bottom
        case .bulk, .maintain:
            return .top
        }
    }
    
    var body: some View {
        Chart {
            if let maintainBand = model.maintainBand {
                RectangleMark(xStart: .value("Maintain Band Start", model.currentDomain.lowerBound), xEnd: .value("Maintain Band End", model.currentDomain.upperBound), yStart: .value("Maintain Lower", maintainBand.lowerBound), yEnd: .value("Maintain Upper", maintainBand.upperBound))
                    .foregroundStyle(targetTint.opacity(0.08))
            }
            
            if model.currentDomain.contains(model.startDate) {
                RuleMark(x: .value("Start Date", model.startDate))
                    .foregroundStyle(boundaryTint.opacity(0.45))
                    .lineStyle(.init(lineWidth: 1, dash: [2, 3]))
            }
            
            RuleMark(y: .value("Target Weight", model.targetWeight))
                .foregroundStyle(targetTint.opacity(0.7))
                .lineStyle(.init(lineWidth: 1.5, dash: [5, 4]))
                .annotation(position: targetWeightAnnotationPosition, alignment: .leading) {
                    Text(formattedWeightText(model.targetWeight, unit: weightUnit, fractionDigits: 0...1))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            
            if let targetDate = model.targetDate, model.currentDomain.contains(targetDate) {
                RuleMark(x: .value("Target Date", targetDate))
                    .foregroundStyle((targetDate < .now ? Color.red : targetDateTint).opacity(0.8))
                    .lineStyle(.init(lineWidth: 1, dash: [3, 3]))
            }
            
            if let endDate = model.endDate, model.currentDomain.contains(endDate) {
                RuleMark(x: .value("Ended Date", endDate))
                    .foregroundStyle(boundaryTint.opacity(0.7))
                    .lineStyle(.init(lineWidth: 1, dash: [3, 2]))
            }
            
            ForEach(model.historyPoints) { point in
                LineMark(x: .value("History Date", point.date), y: .value("History Weight", point.value))
                    .foregroundStyle(historyTint)
                    .lineStyle(.init(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
            }
            
            if let latestPoint = model.latestPoint {
                PointMark(x: .value("Latest Date", latestPoint.date), y: .value("Latest Weight", latestPoint.value))
                    .foregroundStyle(historyTint.opacity(0.2))
                    .symbolSize(220)
                
                PointMark(x: .value("Latest Date", latestPoint.date), y: .value("Latest Weight", latestPoint.value))
                    .foregroundStyle(.white)
                    .symbolSize(90)
                
                PointMark(x: .value("Latest Date", latestPoint.date), y: .value("Latest Weight", latestPoint.value))
                    .foregroundStyle(historyTint)
                    .symbolSize(44)
            }
        }
        .chartXScale(domain: model.currentDomain)
        .chartYScale(domain: model.yDomain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }
}

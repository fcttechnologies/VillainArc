import Charts
import SwiftData
import SwiftUI

struct CorrelationSample: Identifiable, Equatable {
    let id: UUID
    let sessionDate: Date
    let qualityScore: Double // 0...1
    let sleepHours: Double?
    let averageRPE: Double?
}

enum SessionQualityScorer {
    /// Map a UserFeedback enum value to a normalized 0...1 quality score.
    static func score(for feedback: UserFeedback) -> Double {
        switch feedback {
        case .feltGood, .tooEasy: return 1.0
        case .noChange: return 0.5
        case .tooHard: return 0.0
        }
    }
}

enum CorrelationDataBuilder {
    /// Build correlation samples from completed sessions. We attribute a session's
    /// quality rating to the first completed session that uses the same workout
    /// plan AND started after the suggestion event's sessionFrom — since the
    /// app applies userFeedback to suggestion events whose decision == .accepted
    /// and sessionFrom != current. This is a pragmatic approximation; if a plan
    /// is reused over many sessions all later ones inherit the same dominant
    /// feedback signal until events with newer sessionFroms exist.
    static func build(sessions: [WorkoutSession], context: ModelContext) -> [CorrelationSample] {
        var sleepCache: [Date: Double] = [:]
        var samples: [CorrelationSample] = []

        for session in sessions {
            guard let plan = session.workoutPlan else { continue }
            let feedbackValues = collectFeedback(for: session, plan: plan)
            guard !feedbackValues.isEmpty else { continue }
            let quality = feedbackValues.map(SessionQualityScorer.score).reduce(0, +) / Double(feedbackValues.count)

            let sleepHours = sleepHoursForSession(session, context: context, cache: &sleepCache)
            let avgRPE = averageRPE(for: session)

            samples.append(CorrelationSample(id: session.id, sessionDate: session.startedAt, qualityScore: quality, sleepHours: sleepHours, averageRPE: avgRPE))
        }
        return samples
    }

    private static func collectFeedback(for session: WorkoutSession, plan: WorkoutPlan) -> [UserFeedback] {
        var values: [UserFeedback] = []
        for prescription in plan.sortedExercises {
            for event in prescription.suggestionEvents ?? [] {
                guard let feedback = event.userFeedback else { continue }
                guard event.decision == .accepted else { continue }
                guard let sourceID = event.sessionFrom?.id, sourceID != session.id else { continue }
                guard let sourceStart = event.sessionFrom?.startedAt, sourceStart < session.startedAt else { continue }
                values.append(feedback)
            }
        }
        return values
    }

    private static func sleepHoursForSession(_ session: WorkoutSession, context: ModelContext, cache: inout [Date: Double]) -> Double? {
        let key = HealthSleepNight.wakeDayKey(for: session.startedAt)
        if let hit = cache[key] { return hit > 0 ? hit : nil }
        let descriptor = HealthSleepNight.forStoredWakeDayKey(key)
        guard let night = try? context.fetch(descriptor).first, night.timeAsleep > 0 else {
            cache[key] = 0
            return nil
        }
        let hours = night.timeAsleep / 3600
        cache[key] = hours
        return hours
    }

    private static func averageRPE(for session: WorkoutSession) -> Double? {
        let rpes = session.sortedExercises.flatMap(\.sortedSets)
            .filter { $0.complete && $0.rpe > 0 }
            .map { Double($0.rpe) }
        guard !rpes.isEmpty else { return nil }
        return rpes.reduce(0, +) / Double(rpes.count)
    }
}

struct LinearFit {
    let slope: Double
    let intercept: Double
    let pearson: Double

    func y(at x: Double) -> Double { slope * x + intercept }

    static func fit(_ points: [(x: Double, y: Double)]) -> LinearFit? {
        guard points.count >= 3 else { return nil }
        let n = Double(points.count)
        let sumX = points.map(\.x).reduce(0, +)
        let sumY = points.map(\.y).reduce(0, +)
        let meanX = sumX / n
        let meanY = sumY / n
        var num = 0.0
        var denomX = 0.0
        var denomY = 0.0
        for p in points {
            let dx = p.x - meanX
            let dy = p.y - meanY
            num += dx * dy
            denomX += dx * dx
            denomY += dy * dy
        }
        guard denomX > 0 else { return nil }
        let slope = num / denomX
        let intercept = meanY - slope * meanX
        let pearson = denomY > 0 ? num / sqrt(denomX * denomY) : 0
        return LinearFit(slope: slope, intercept: intercept, pearson: pearson)
    }
}

struct CorrelationInsightsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(WorkoutSession.completedSession) private var sessions: [WorkoutSession]

    private static let minimumSamples = 8

    private var samples: [CorrelationSample] {
        CorrelationDataBuilder.build(sessions: sessions, context: modelContext)
    }

    private var sleepPoints: [(CorrelationSample, Double, Double)] {
        samples.compactMap { sample in
            guard let sleep = sample.sleepHours else { return nil }
            return (sample, sleep, sample.qualityScore)
        }
    }

    private var rpePoints: [(CorrelationSample, Double, Double)] {
        samples.compactMap { sample in
            guard let rpe = sample.averageRPE else { return nil }
            return (sample, rpe, sample.qualityScore)
        }
    }

    private var sleepFit: LinearFit? {
        LinearFit.fit(sleepPoints.map { ($0.1, $0.2) })
    }

    private var rpeFit: LinearFit? {
        LinearFit.fit(rpePoints.map { ($0.1, $0.2) })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if samples.count < Self.minimumSamples {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Keep rating your sessions")
                            .font(.headline)
                        Text("You have \(samples.count) of \(Self.minimumSamples) rated sessions needed to surface correlations. Rate workouts on the summary screen — \"Great\", \"Good\", \"OK\", or \"Tough\" — to feed this view.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .appCardStyle()
                } else {
                    if let summary = autoInsight() {
                        InsightHeroCard(text: summary)
                    }

                    CorrelationScatterCard(
                        title: String(localized: "Sleep vs Session Quality"),
                        xAxis: String(localized: "Hours slept"),
                        yAxis: String(localized: "Session quality"),
                        xDomain: domain(for: sleepPoints.map(\.1), padding: 0.5, fallback: 5...10),
                        points: sleepPoints,
                        fit: sleepFit,
                        tint: .indigo,
                        emptyStateText: emptyState(forCount: sleepPoints.count, kind: .sleep)
                    )

                    CorrelationScatterCard(
                        title: String(localized: "RPE vs Session Quality"),
                        xAxis: String(localized: "Average RPE"),
                        yAxis: String(localized: "Session quality"),
                        xDomain: domain(for: rpePoints.map(\.1), padding: 0.5, fallback: 5...10),
                        points: rpePoints,
                        fit: rpeFit,
                        tint: .orange,
                        emptyStateText: emptyState(forCount: rpePoints.count, kind: .rpe)
                    )
                }
            }
            .padding()
        }
        .quickActionContentBottomInset()
        .appBackground()
        .navigationTitle("Correlations")
        .toolbarTitleDisplayMode(.inline)
        .accessibilityIdentifier(AccessibilityIdentifiers.correlationInsightsRoot)
        .task { await IntentDonations.donateShowCorrelationInsights() }
    }

    private func domain(for values: [Double], padding: Double, fallback: ClosedRange<Double>) -> ClosedRange<Double> {
        guard let lo = values.min(), let hi = values.max(), lo < hi else { return fallback }
        return (lo - padding)...(hi + padding)
    }

    private enum EmptyKind { case sleep, rpe }
    private func emptyState(forCount count: Int, kind: EmptyKind) -> String {
        switch kind {
        case .sleep:
            return String(localized: "Sync more sleep data to chart this correlation. (\(count) data points so far.)")
        case .rpe:
            return String(localized: "Log RPE on completed sets to chart this correlation. (\(count) data points so far.)")
        }
    }

    private func autoInsight() -> String? {
        let goodSleep = sleepPoints.filter { $0.1 >= 7.0 }
        let lowRPE = rpePoints.filter { $0.1 <= 8.0 }
        let both = sleepPoints.filter { sleep in
            sleep.1 >= 7.0 && rpePoints.contains(where: { $0.0.id == sleep.0.id && $0.1 <= 8.0 })
        }
        if both.count >= 3 {
            let avgQuality = both.map(\.2).reduce(0, +) / Double(both.count)
            if avgQuality >= 0.7 {
                let pct = Int((avgQuality * 100).rounded())
                return String(localized: "You feel best when you sleep 7+ hours and keep average RPE at 8 or lower — \(pct)% session-quality on those days.")
            }
        }
        if let fit = sleepFit, fit.pearson >= 0.3, goodSleep.count >= 3 {
            return String(localized: "Sleep is moving the needle: more sleep tracks with better-rated sessions.")
        }
        if let fit = rpeFit, fit.pearson <= -0.3, lowRPE.count >= 3 {
            return String(localized: "Intensity matters: sessions feel better when average RPE stays controlled.")
        }
        return nil
    }
}

private struct InsightHeroCard: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundStyle(.yellow.gradient)
                .font(.title3)
            Text(text)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding()
        .appCardStyle()
    }
}

private struct CorrelationScatterCard: View {
    let title: String
    let xAxis: String
    let yAxis: String
    let xDomain: ClosedRange<Double>
    let points: [(CorrelationSample, Double, Double)]
    let fit: LinearFit?
    let tint: Color
    let emptyStateText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)

            if points.count < 3 {
                Text(emptyStateText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Chart {
                    ForEach(points, id: \.0.id) { item in
                        PointMark(x: .value(xAxis, item.1), y: .value(yAxis, item.2))
                            .foregroundStyle(tint.gradient)
                            .symbolSize(80)
                    }
                    if let fit {
                        let lo = xDomain.lowerBound
                        let hi = xDomain.upperBound
                        LineMark(x: .value(xAxis, lo), y: .value(yAxis, max(0, min(1, fit.y(at: lo)))))
                            .foregroundStyle(tint.opacity(0.4))
                            .lineStyle(.init(lineWidth: 2, dash: [4, 4]))
                        LineMark(x: .value(xAxis, hi), y: .value(yAxis, max(0, min(1, fit.y(at: hi)))))
                            .foregroundStyle(tint.opacity(0.4))
                            .lineStyle(.init(lineWidth: 2, dash: [4, 4]))
                    }
                }
                .chartXScale(domain: xDomain)
                .chartYScale(domain: 0...1)
                .chartXAxisLabel(xAxis)
                .chartYAxis {
                    AxisMarks(values: [0, 0.5, 1]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                switch v {
                                case 0: Text("Tough")
                                case 0.5: Text("OK")
                                case 1: Text("Great")
                                default: EmptyView()
                                }
                            }
                        }
                    }
                }
                .frame(height: 200)
                .accessibilityLabel(Text("\(title) scatter chart with fitted line"))

                if let fit {
                    Text("Correlation r = \(String(format: "%.2f", fit.pearson)) · \(points.count) sessions")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .appCardStyle()
    }
}

#Preview(traits: .sampleData) {
    NavigationStack { CorrelationInsightsView() }
}

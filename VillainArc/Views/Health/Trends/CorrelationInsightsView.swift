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

// MARK: - Auto-captured session metrics

/// A single completed session reduced to the signals the app captures automatically — no manual
/// session rating required. This is what lets Correlations be useful from day one.
struct SessionMetricsSample: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let sleepHours: Double?       // night before the session
    let averageRPE: Double?       // mean RPE over completed, rated sets
    let totalVolumeKg: Double     // Σ weight × reps (weights are kg on completed sessions)
    let topEstimated1RMKg: Double? // best estimated 1RM across completed working sets
    let durationMinutes: Double?  // wall-clock session length
}

extension CorrelationDataBuilder {
    /// Reduce completed sessions to auto-captured metric samples. `sleepByWakeDay` is prebuilt once
    /// (no per-session fetch) keyed by `HealthSleepNight.wakeDay`.
    static func buildSessionMetrics(sessions: [WorkoutSession], sleepByWakeDay: [Date: Double]) -> [SessionMetricsSample] {
        sessions.map { session in
            let sleepKey = HealthSleepNight.wakeDayKey(for: session.startedAt)
            let sleep = (sleepByWakeDay[sleepKey]).flatMap { $0 > 0 ? $0 : nil }

            let completedSets = session.sortedExercises.flatMap(\.sortedSets).filter(\.complete)
            let rpes = completedSets.filter { $0.rpe > 0 }.map { Double($0.rpe) }
            let averageRPE = rpes.isEmpty ? nil : rpes.reduce(0, +) / Double(rpes.count)
            let top1RM = completedSets.compactMap(\.estimated1RM).max()
            let duration = session.totalDuration > 0 ? session.totalDuration / 60 : nil

            return SessionMetricsSample(
                id: session.id,
                date: session.startedAt,
                sleepHours: sleep,
                averageRPE: averageRPE,
                totalVolumeKg: session.totalVolume,
                topEstimated1RMKg: top1RM,
                durationMinutes: duration
            )
        }
    }
}

/// One (x, y) observation for a scatter correlation.
struct CorrelationPoint: Identifiable, Equatable {
    let id: UUID
    let x: Double
    let y: Double
}

/// A fully-prepared correlation chart: points, optional fitted line, axis labels, and the headline
/// sentences to use if this turns out to be the strongest relationship.
struct CorrelationMetric: Identifiable {
    let id = UUID()
    let title: String
    let xAxisLabel: String
    let yAxisLabel: String
    let points: [CorrelationPoint]
    let fit: LinearFit?
    let tint: Color
    let caption: String?
    let emptyStateText: String
    let insightUp: String
    let insightDown: String
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
    @Query(HealthSleepNight.history) private var sleepNights: [HealthSleepNight]
    @Query(AppSettings.single) private var appSettings: [AppSettings]

    // Built off the body-render path in `.task` (per the perf learning: no O(table) reduction or
    // SwiftData walking inside a body-read computed var).
    @State private var metrics: [CorrelationMetric] = []
    @State private var heroInsight: String?
    @State private var ratedSleepPoints: [(CorrelationSample, Double, Double)] = []
    @State private var ratedRPEPoints: [(CorrelationSample, Double, Double)] = []
    @State private var hasRatedData = false

    private var weightUnit: WeightUnit { appSettings.first?.weightUnit ?? .lbs }

    // Cheap signature so the heavy rebuild only re-runs when the inputs actually change.
    private var rebuildSignature: String {
        "\(sessions.count)-\(sleepNights.count)-\(weightUnit.rawValue)"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let heroInsight {
                    InsightHeroCard(text: heroInsight)
                }

                if metrics.isEmpty && !hasRatedData {
                    ContentUnavailableView {
                        Label(LocalizedStringResource("Building Your Correlations"), systemImage: "chart.dots.scatter")
                    } description: {
                        Text("Log a few more workouts and Villain Arc will chart how your sleep, effort, and training line up. Sync Apple Health sleep to unlock even more.")
                    }
                    .padding(.top, 40)
                } else {
                    ForEach(metrics) { metric in
                        MetricScatterCard(metric: metric)
                    }
                    if hasRatedData {
                        ratedQualityCard
                    }
                }
            }
            .padding()
        }
        .quickActionContentBottomInset()
        .appBackground()
        .navigationTitle("Correlations")
        .toolbarTitleDisplayMode(.inline)
        .accessibilityIdentifier(AccessibilityIdentifiers.correlationInsightsRoot)
        .task(id: rebuildSignature) { rebuild() }
        .task { await IntentDonations.donateShowCorrelationInsights() }
    }

    private var ratedQualityCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("From Your Session Ratings")
                    .font(.headline)
                Text("How sleep and effort line up with how each session felt — from the ratings you give on the workout summary.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            CorrelationScatterCard(
                title: String(localized: "Sleep vs Session Quality"),
                xAxis: String(localized: "Hours slept"),
                yAxis: String(localized: "Session quality"),
                xDomain: domain(for: ratedSleepPoints.map(\.1), padding: 0.5, fallback: 5...10),
                points: ratedSleepPoints,
                fit: LinearFit.fit(ratedSleepPoints.map { ($0.1, $0.2) }),
                tint: .indigo,
                emptyStateText: String(localized: "Rate a few more sessions with sleep synced to chart this. (\(ratedSleepPoints.count) data points so far.)")
            )

            Divider()

            CorrelationScatterCard(
                title: String(localized: "RPE vs Session Quality"),
                xAxis: String(localized: "Average RPE"),
                yAxis: String(localized: "Session quality"),
                xDomain: domain(for: ratedRPEPoints.map(\.1), padding: 0.5, fallback: 5...10),
                points: ratedRPEPoints,
                fit: LinearFit.fit(ratedRPEPoints.map { ($0.1, $0.2) }),
                tint: .orange,
                emptyStateText: String(localized: "Rate a few more sessions with RPE logged to chart this. (\(ratedRPEPoints.count) data points so far.)")
            )
        }
        .padding()
        .appCardStyle()
    }

    // MARK: - Build

    private func rebuild() {
        let unit = weightUnit
        let sleepByWakeDay = Dictionary(
            sleepNights.map { ($0.wakeDay, $0.timeAsleep / 3600) },
            uniquingKeysWith: { Swift.max($0, $1) }
        )
        let samples = CorrelationDataBuilder.buildSessionMetrics(sessions: sessions, sleepByWakeDay: sleepByWakeDay)

        let volumeLabel = "\(String(localized: "Volume")) (\(unit.rawValue))"
        let oneRMLabel = "\(String(localized: "Top set 1RM")) (\(unit.rawValue))"

        let built: [CorrelationMetric] = [
            makeMetric(
                title: String(localized: "Session Length vs Volume"),
                xLabel: String(localized: "Duration (min)"),
                yLabel: volumeLabel,
                tint: .blue,
                needs: String(localized: "Finish a few more workouts to chart this."),
                insightUp: String(localized: "Your longer sessions pack in more total volume."),
                insightDown: String(localized: "You squeeze more volume into your shorter sessions — efficient training."),
                samples: samples,
                x: { $0.durationMinutes },
                y: { volumeDisplay($0.totalVolumeKg, unit: unit) }
            ),
            makeMetric(
                title: String(localized: "Effort vs Volume"),
                xLabel: String(localized: "Average RPE"),
                yLabel: volumeLabel,
                tint: .orange,
                needs: String(localized: "Log RPE on more sessions to chart this."),
                insightUp: String(localized: "Higher-effort sessions track with more total volume."),
                insightDown: String(localized: "Your biggest-volume sessions actually feel easier — strength is paying off."),
                samples: samples,
                x: { $0.averageRPE },
                y: { volumeDisplay($0.totalVolumeKg, unit: unit) }
            ),
            makeMetric(
                title: String(localized: "Sleep vs Volume"),
                xLabel: String(localized: "Hours slept"),
                yLabel: volumeLabel,
                tint: .indigo,
                needs: String(localized: "Sync Apple Health sleep to chart this."),
                insightUp: String(localized: "You train with more volume after better sleep."),
                insightDown: String(localized: "Your highest-volume days don't depend on a long night's sleep."),
                samples: samples,
                x: { $0.sleepHours },
                y: { volumeDisplay($0.totalVolumeKg, unit: unit) }
            ),
            makeMetric(
                title: String(localized: "Sleep vs Top-Set Strength"),
                xLabel: String(localized: "Hours slept"),
                yLabel: oneRMLabel,
                tint: .teal,
                needs: String(localized: "Sync Apple Health sleep to chart this."),
                insightUp: String(localized: "Your top sets are stronger after more sleep."),
                insightDown: String(localized: "Your top-set strength holds up even on shorter sleep."),
                samples: samples,
                x: { $0.sleepHours },
                y: { oneRMDisplay($0.topEstimated1RMKg, unit: unit) }
            )
        ]

        metrics = built.filter { !$0.points.isEmpty }
        heroInsight = makeHeroInsight(from: built)

        let rated = CorrelationDataBuilder.build(sessions: sessions, context: modelContext)
        ratedSleepPoints = rated.compactMap { sample in sample.sleepHours.map { (sample, $0, sample.qualityScore) } }
        ratedRPEPoints = rated.compactMap { sample in sample.averageRPE.map { (sample, $0, sample.qualityScore) } }
        hasRatedData = !rated.isEmpty
    }

    private func makeMetric(
        title: String,
        xLabel: String,
        yLabel: String,
        tint: Color,
        needs: String,
        insightUp: String,
        insightDown: String,
        samples: [SessionMetricsSample],
        x: (SessionMetricsSample) -> Double?,
        y: (SessionMetricsSample) -> Double?
    ) -> CorrelationMetric {
        let points = samples.compactMap { sample -> CorrelationPoint? in
            guard let xv = x(sample), let yv = y(sample) else { return nil }
            return CorrelationPoint(id: sample.id, x: xv, y: yv)
        }.sorted { $0.x < $1.x }

        let fit = LinearFit.fit(points.map { ($0.x, $0.y) })
        let caption = fit.map { String(localized: "Correlation r = \(String(format: "%.2f", $0.pearson)) · \(points.count) sessions") }
        let emptyText = "\(needs) \(String(localized: "(\(points.count) data points so far.)"))"

        return CorrelationMetric(
            title: title,
            xAxisLabel: xLabel,
            yAxisLabel: yLabel,
            points: points,
            fit: fit,
            tint: tint,
            caption: caption,
            emptyStateText: emptyText,
            insightUp: insightUp,
            insightDown: insightDown
        )
    }

    /// Surface the single strongest, well-supported relationship as the hero line.
    private func makeHeroInsight(from metrics: [CorrelationMetric]) -> String? {
        let strongest = metrics
            .compactMap { metric -> (CorrelationMetric, Double)? in
                guard let fit = metric.fit, metric.points.count >= 5, abs(fit.pearson) >= 0.35 else { return nil }
                return (metric, fit.pearson)
            }
            .max(by: { abs($0.1) < abs($1.1) })
        guard let (metric, pearson) = strongest else { return nil }
        return pearson >= 0 ? metric.insightUp : metric.insightDown
    }

    private func volumeDisplay(_ kg: Double, unit: WeightUnit) -> Double? {
        guard kg > 0 else { return nil }
        return unit.fromKg(kg).rounded()
    }

    private func oneRMDisplay(_ kg: Double?, unit: WeightUnit) -> Double? {
        guard let kg, kg > 0 else { return nil }
        return roundedDisplayValue(unit.fromKg(kg), fractionDigits: 1)
    }

    private func domain(for values: [Double], padding: Double, fallback: ClosedRange<Double>) -> ClosedRange<Double> {
        guard let lo = values.min(), let hi = values.max(), lo < hi else { return fallback }
        return (lo - padding)...(hi + padding)
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

/// Generic scatter card for an auto-captured correlation: numeric axes, dynamic domains, and a
/// dashed fitted line when there are enough points.
private struct MetricScatterCard: View {
    let metric: CorrelationMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(metric.title)
                .font(.subheadline)
                .fontWeight(.semibold)

            if metric.points.count < 3 {
                Text(metric.emptyStateText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                chart
                if let caption = metric.caption {
                    Text(caption)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .appCardStyle()
    }

    private var chart: some View {
        let xDomain = domain(for: metric.points.map(\.x))
        let yDomain = domain(for: metric.points.map(\.y))
        return Chart {
            ForEach(metric.points) { point in
                PointMark(x: .value(metric.xAxisLabel, point.x), y: .value(metric.yAxisLabel, point.y))
                    .foregroundStyle(metric.tint.gradient)
                    .symbolSize(70)
            }
            if let fit = metric.fit {
                let lo = xDomain.lowerBound
                let hi = xDomain.upperBound
                LineMark(x: .value(metric.xAxisLabel, lo), y: .value(metric.yAxisLabel, clamp(fit.y(at: lo), to: yDomain)))
                    .foregroundStyle(metric.tint.opacity(0.4))
                    .lineStyle(.init(lineWidth: 2, dash: [4, 4]))
                LineMark(x: .value(metric.xAxisLabel, hi), y: .value(metric.yAxisLabel, clamp(fit.y(at: hi), to: yDomain)))
                    .foregroundStyle(metric.tint.opacity(0.4))
                    .lineStyle(.init(lineWidth: 2, dash: [4, 4]))
            }
        }
        .chartXScale(domain: xDomain)
        .chartYScale(domain: yDomain)
        .chartXAxisLabel(metric.xAxisLabel)
        .chartYAxisLabel(metric.yAxisLabel)
        .frame(height: 200)
        .accessibilityLabel(Text("\(metric.title) scatter chart with fitted line"))
    }

    private func domain(for values: [Double]) -> ClosedRange<Double> {
        guard let lo = values.min(), let hi = values.max(), lo < hi else {
            let v = values.first ?? 0
            return (v - 1)...(v + 1)
        }
        let pad = (hi - lo) * 0.1
        return (lo - pad)...(hi + pad)
    }

    private func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
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
    }
}

#Preview(traits: .sampleData) {
    NavigationStack { CorrelationInsightsView() }
}

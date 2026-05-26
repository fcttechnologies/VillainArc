import Foundation
import SwiftData

struct OutcomePatternInsight: Equatable {
    let headline: String
    let detail: String
    let positiveCount: Int
    let totalRatedCount: Int
}

enum OutcomePatternsAnalyzer {
    private static let minRatedSessions = 5
    private static let minPositiveSessions = 3
    private static let goodSleepHoursThreshold: Double = 7.0
    private static let goodRPEThreshold: Double = 8.0
    private static let minBucketRateForPositive: Double = 0.6
    private static let minRateGap: Double = 0.2

    static func analyze(context: ModelContext) -> OutcomePatternInsight? {
        let descriptor = WorkoutSession.completedSession
        guard let sessions = try? context.fetch(descriptor) else { return nil }

        let rated = sessions.filter { $0.postOutcomeValue != .notSet }
        guard rated.count >= minRatedSessions else { return nil }

        let positive = rated.filter { $0.postOutcomeValue.isPositive }
        guard positive.count >= minPositiveSessions else { return nil }

        let sleepByID = sleepHoursByWakeDay(for: rated, context: context)

        let sleepInsight = sleepInsight(positive: positive, rated: rated, sleepByID: sleepByID)
        let rpeInsight = rpeInsight(positive: positive, rated: rated)

        let candidates = [sleepInsight, rpeInsight].compactMap { $0 }
        return candidates.first
    }

    private static func sleepHoursByWakeDay(for sessions: [WorkoutSession], context: ModelContext) -> [UUID: Double] {
        var result: [UUID: Double] = [:]
        var nightCache: [Date: HealthSleepNight] = [:]

        for session in sessions {
            let key = HealthSleepNight.wakeDayKey(for: session.startedAt)
            if let cached = nightCache[key] {
                result[session.id] = cached.timeAsleep / 3600
                continue
            }
            let descriptor = HealthSleepNight.forStoredWakeDayKey(key)
            if let night = try? context.fetch(descriptor).first, night.timeAsleep > 0 {
                nightCache[key] = night
                result[session.id] = night.timeAsleep / 3600
            }
        }
        return result
    }

    private static func sleepInsight(positive: [WorkoutSession], rated: [WorkoutSession], sleepByID: [UUID: Double]) -> OutcomePatternInsight? {
        let positiveWithSleep = positive.compactMap { sleepByID[$0.id] }
        let negativeWithSleep = rated.filter { !$0.postOutcomeValue.isPositive }.compactMap { sleepByID[$0.id] }
        guard positiveWithSleep.count >= minPositiveSessions else { return nil }

        let positiveGoodSleepRate = Double(positiveWithSleep.filter { $0 >= goodSleepHoursThreshold }.count) / Double(positiveWithSleep.count)
        guard positiveGoodSleepRate >= minBucketRateForPositive else { return nil }

        if !negativeWithSleep.isEmpty {
            let negativeGoodSleepRate = Double(negativeWithSleep.filter { $0 >= goodSleepHoursThreshold }.count) / Double(negativeWithSleep.count)
            guard positiveGoodSleepRate - negativeGoodSleepRate >= minRateGap else { return nil }
        }

        let pctText = Int((positiveGoodSleepRate * 100).rounded())
        return OutcomePatternInsight(
            headline: String(localized: "Sleep is moving the needle"),
            detail: String(localized: "\(pctText)% of your best sessions came after 7+ hours of sleep."),
            positiveCount: positiveWithSleep.count,
            totalRatedCount: rated.count
        )
    }

    private static func rpeInsight(positive: [WorkoutSession], rated: [WorkoutSession]) -> OutcomePatternInsight? {
        func avgRPE(_ session: WorkoutSession) -> Double? {
            let rpes = session.sortedExercises.flatMap { $0.sortedSets }
                .filter { $0.complete && $0.rpe > 0 }
                .map { Double($0.rpe) }
            guard !rpes.isEmpty else { return nil }
            return rpes.reduce(0, +) / Double(rpes.count)
        }

        let positiveRPEs = positive.compactMap { avgRPE($0) }
        let negativeRPEs = rated.filter { !$0.postOutcomeValue.isPositive }.compactMap { avgRPE($0) }
        guard positiveRPEs.count >= minPositiveSessions else { return nil }

        let positiveControlledRate = Double(positiveRPEs.filter { $0 <= goodRPEThreshold }.count) / Double(positiveRPEs.count)
        guard positiveControlledRate >= minBucketRateForPositive else { return nil }

        if !negativeRPEs.isEmpty {
            let negativeControlledRate = Double(negativeRPEs.filter { $0 <= goodRPEThreshold }.count) / Double(negativeRPEs.count)
            guard positiveControlledRate - negativeControlledRate >= minRateGap else { return nil }
        }

        let pctText = Int((positiveControlledRate * 100).rounded())
        return OutcomePatternInsight(
            headline: String(localized: "Intensity sweet spot"),
            detail: String(localized: "\(pctText)% of your best sessions stayed at an average RPE of 8 or lower."),
            positiveCount: positiveRPEs.count,
            totalRatedCount: rated.count
        )
    }
}

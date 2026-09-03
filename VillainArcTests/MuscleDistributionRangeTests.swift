import FCTCore
import Foundation
import SwiftData
import Testing

@testable import VillainArc

/// The windowed muscle-distribution summary: the range the profile card offers, and the
/// multi-session aggregation behind it.
@Suite struct MuscleDistributionRangeTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        return calendar
    }

    private var noon: Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 2, hour: 12))!
    }

    // MARK: - The window

    @Test func theWeekWindowStartsSixDaysBackAtMidnight() throws {
        let start = try #require(MuscleDistributionCalculator.windowStart(for: .week, now: noon, calendar: calendar))
        // Six days back from the 2nd is the 27th: seven days counting today.
        #expect(calendar.dateComponents([.year, .month, .day], from: start) == DateComponents(year: 2026, month: 8, day: 27))
        // Midnight, so a session logged earlier today is inside the window all day long.
        #expect(start == calendar.startOfDay(for: start))
    }

    @Test func theMonthWindowStartsOneMonthBack() throws {
        let start = try #require(MuscleDistributionCalculator.windowStart(for: .month, now: noon, calendar: calendar))
        #expect(calendar.dateComponents([.year, .month, .day], from: start) == DateComponents(year: 2026, month: 8, day: 2))
    }

    @Test func allTimeHasNoWindow() {
        #expect(MuscleDistributionCalculator.windowStart(for: .all, now: noon, calendar: calendar) == nil)
    }

    /// A range read at 11pm covers the same days it covered at 6am — the anchor is the day, not
    /// the instant, so nothing drops out of "past week" while you are looking at it.
    @Test func theWindowDoesNotDriftThroughTheDay() throws {
        let morning = calendar.date(from: DateComponents(year: 2026, month: 9, day: 2, hour: 6))!
        let night = calendar.date(from: DateComponents(year: 2026, month: 9, day: 2, hour: 23))!
        #expect(MuscleDistributionCalculator.windowStart(for: .week, now: morning, calendar: calendar)
            == MuscleDistributionCalculator.windowStart(for: .week, now: night, calendar: calendar))
    }

    // MARK: - The aggregation

    /// The property the fold exists for: a session with one exercise and a session with several
    /// contribute in proportion to the work they hold, not equally. Summing each session's
    /// *percentages* would make the small session count as much as the large one.
    @Test @MainActor func sessionsAggregateByWorkDoneNotBySessionCount() throws {
        let context = try TestDataFactory.makeContext()
        let (_, benchPrescription) = TestDataFactory.makePrescription(context: context, catalogID: "barbell_bench_press")
        let (_, squatPrescription) = TestDataFactory.makePrescription(context: context, catalogID: "barbell_squat")

        // A big chest session: four heavy sets.
        let chestSession = TestDataFactory.makeSession(context: context, daysAgo: 1)
        _ = TestDataFactory.makePerformance(
            context: context, session: chestSession, prescription: benchPrescription,
            sets: Array(repeating: (weight: 100.0, reps: 10, rest: 90, type: ExerciseSetType.working), count: 4)
        )
        // A token leg session: one light set.
        let legSession = TestDataFactory.makeSession(context: context, daysAgo: 2)
        _ = TestDataFactory.makePerformance(
            context: context, session: legSession, prescription: squatPrescription,
            sets: [(weight: 10, reps: 1, rest: 90, type: .working)]
        )

        let slices = MuscleDistributionCalculator.slices(for: [chestSession, legSession])
        let quads = try #require(slices.first { $0.muscle == .quads })

        // 4,000 units of pressing work against 10 units of squatting. Averaging the two sessions'
        // own percentages would put the quads somewhere near a third of the picture; weighting by
        // the work actually done puts them under a percent, which is what the athlete did.
        #expect(quads.percentage < 1)
        #expect(abs(slices.map(\.percentage).reduce(0, +) - 100) < 0.0001)
    }

    @Test @MainActor func noSessionsIsAnEmptyDistributionRatherThanZeroes() throws {
        #expect(MuscleDistributionCalculator.slices(for: [WorkoutSession]()).isEmpty)
    }

    // MARK: - The windowed fetch

    @Test @MainActor func theWindowedDescriptorExcludesSessionsOutsideIt() throws {
        let context = try TestDataFactory.makeContext()
        let recent = TestDataFactory.makeSession(context: context, daysAgo: 2)
        recent.statusValue = .done
        let old = TestDataFactory.makeSession(context: context, daysAgo: 40)
        old.statusValue = .done
        try context.save()

        let week = try context.fetch(WorkoutSession.completedSessions(since: MuscleDistributionCalculator.windowStart(for: .week)))
        let all = try context.fetch(WorkoutSession.completedSessions(since: MuscleDistributionCalculator.windowStart(for: .all)))

        #expect(week.map(\.id) == [recent.id])
        #expect(Set(all.map(\.id)) == Set([recent.id, old.id]))
    }
}

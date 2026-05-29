import Foundation
import Testing

@testable import VillainArc

struct DateExtensionsTests {
    private var utc: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        cal.locale = Locale(identifier: "en_US")
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0, _ second: Int = 0) -> Date {
        utc.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
    }

    @Test func endOfDayIsLastSecondOfTheDay() {
        let result = utc.endOfDay(for: date(2026, 1, 15, 9, 30, 0))
        #expect(result == date(2026, 1, 15, 23, 59, 59))
    }

    @Test func startOfMonthIsFirstDayAtMidnight() {
        let result = utc.startOfMonth(for: date(2026, 3, 18, 14, 0, 0))
        #expect(result == date(2026, 3, 1, 0, 0, 0))
    }

    @Test func startOfYearIsJanuaryFirstAtMidnight() {
        let result = utc.startOfYear(for: date(2026, 7, 4))
        #expect(result == date(2026, 1, 1, 0, 0, 0))
    }

    @Test func endOfYearIsLastSecondOfDecember() {
        let result = utc.endOfYear(for: date(2026, 7, 4))
        #expect(result == date(2026, 12, 31, 23, 59, 59))
    }

    @Test func chartUpperBoundIsOneSecondBeforeIntervalEnd() {
        let start = date(2026, 1, 1)
        let end = date(2026, 2, 1)
        let interval = DateInterval(start: start, end: end)
        #expect(interval.chartUpperBound == end.addingTimeInterval(-1))
    }
}

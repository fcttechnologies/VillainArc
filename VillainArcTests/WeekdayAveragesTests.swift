import Foundation
import Testing

@testable import VillainArc

struct WeekdayAveragesTests {
    private func calendar(firstWeekday: Int) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        cal.locale = Locale(identifier: "en_US")
        cal.firstWeekday = firstWeekday
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    @Test func initFromCalendarWeekdayNumberMapsAllSevenAndRejectsOutOfRange() {
        #expect(Weekday(calendarWeekdayNumber: 1) == .sunday)
        #expect(Weekday(calendarWeekdayNumber: 7) == .saturday)
        #expect(Weekday(calendarWeekdayNumber: 0) == nil)
        #expect(Weekday(calendarWeekdayNumber: 8) == nil)
    }

    @Test func calendarWeekdayNumberRoundTrips() {
        for weekday in Weekday.allCases {
            #expect(Weekday(calendarWeekdayNumber: weekday.calendarWeekdayNumber) == weekday)
        }
    }

    @Test func labelsUseEnglishSymbols() {
        let cal = calendar(firstWeekday: 1)
        #expect(Weekday.sunday.shortLabel(calendar: cal) == "Sun")
        #expect(Weekday.monday.fullLabel(calendar: cal) == "Monday")
        #expect(Weekday.monday.pluralLabel(calendar: cal) == "Monday")
    }

    @Test func orderedWeekdaysHonorsFirstWeekday() {
        #expect(orderedWeekdays(calendar: calendar(firstWeekday: 1)) == [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday])
        #expect(orderedWeekdays(calendar: calendar(firstWeekday: 2)) == [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday])
    }

    @Test func makeWeekdayAveragePointsGroupsAndAverages() {
        let cal = calendar(firstWeekday: 1)
        // 2026-01-12 and 2026-01-19 are Mondays; 2026-01-13 is a Tuesday.
        let entries: [(date: Date, value: Double)] = [
            (date(2026, 1, 12), 10),
            (date(2026, 1, 19), 20),
            (date(2026, 1, 13), 5)
        ]
        let points = makeWeekdayAveragePoints(from: entries, calendar: cal, date: { $0.date }, value: { $0.value })
        #expect(points.count == 7)

        let monday = points.first { $0.weekday == .monday }
        #expect(monday?.averageValue == 15)
        #expect(monday?.sampleCount == 2)

        let tuesday = points.first { $0.weekday == .tuesday }
        #expect(tuesday?.averageValue == 5)
        #expect(tuesday?.sampleCount == 1)

        let wednesday = points.first { $0.weekday == .wednesday }
        #expect(wednesday?.averageValue == 0)
        #expect(wednesday?.sampleCount == 0)
    }
}

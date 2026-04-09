import Foundation
import Testing
@testable import VillainArc

struct FormattingHelpersTests {
    @Test func formattedRecentDay_usesWeekdayNamesForLastFiveRecentDays() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let locale = Locale(identifier: "en_US")

        let referenceDate = calendar.date(from: DateComponents(year: 2026, month: 4, day: 9, hour: 12))!

        #expect(formattedRecentDay(referenceDate, relativeTo: referenceDate, calendar: calendar, locale: locale) == "Today")
        #expect(formattedRecentDay(calendar.date(byAdding: .day, value: -1, to: referenceDate)!, relativeTo: referenceDate, calendar: calendar, locale: locale) == "Yesterday")
        #expect(formattedRecentDay(calendar.date(byAdding: .day, value: -2, to: referenceDate)!, relativeTo: referenceDate, calendar: calendar, locale: locale) == "Tuesday")
        #expect(formattedRecentDay(calendar.date(byAdding: .day, value: -3, to: referenceDate)!, relativeTo: referenceDate, calendar: calendar, locale: locale) == "Monday")
        #expect(formattedRecentDay(calendar.date(byAdding: .day, value: -4, to: referenceDate)!, relativeTo: referenceDate, calendar: calendar, locale: locale) == "Sunday")
        #expect(formattedRecentDay(calendar.date(byAdding: .day, value: -5, to: referenceDate)!, relativeTo: referenceDate, calendar: calendar, locale: locale) == "Saturday")
        #expect(formattedRecentDay(calendar.date(byAdding: .day, value: -6, to: referenceDate)!, relativeTo: referenceDate, calendar: calendar, locale: locale) == "Apr 3, 2026")
        #expect(formattedRecentDay(calendar.date(byAdding: .day, value: 1, to: referenceDate)!, relativeTo: referenceDate, calendar: calendar, locale: locale) == "Apr 10, 2026")
    }
}

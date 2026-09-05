import Foundation
import Testing

@testable import VillainArc

struct FormattingHelpersTests {
    @Test func secondsToTimeFormatsUnderAndOverTenMinutes() {
        #expect(secondsToTime(65) == "1:05")
        #expect(secondsToTime(600) == "10:00")
        #expect(secondsToTime(605) == "10:05")
        #expect(secondsToTime(0) == "0:00")
        #expect(secondsToTime(-30) == "0:00")
    }

    @Test func secondsToTimeWithHoursFormatsHMS() {
        #expect(secondsToTimeWithHours(3_661) == "1:01:01")
        #expect(secondsToTimeWithHours(0) == "0:00:00")
        #expect(secondsToTimeWithHours(-5) == "0:00:00")
    }

    /// The clock-face digit pair, across every second of an hour plus the widths past it, against
    /// the C form it replaces — the one comparison that proves an interpolated pad is the same
    /// string a `%02d` produced.
    @Test func zeroPaddedTwoDigitsMatchesFixedWidthPadding() {
        for value in (-5...125) {
            let expected = unsafe String(format: "%02d", max(0, value))
            #expect(zeroPaddedTwoDigits(value) == expected, "\(value)")
        }
    }

    /// One decimal place with a period separator, whatever the process locale is, because these
    /// strings are read back by `Double(_:)` rather than by a person.
    @Test func fixedOneDecimalIsLocaleIndependentAndRoundTrips() {
        #expect(fixedOneDecimal(0) == "0.0")
        #expect(fixedOneDecimal(5.5) == "5.5")
        #expect(fixedOneDecimal(8) == "8.0")
        #expect(fixedOneDecimal(12.34) == "12.3")
        #expect(fixedOneDecimal(12.36) == "12.4")
        #expect(fixedOneDecimal(15) == "15.0")
        #expect(fixedOneDecimal(100) == "100.0")
        // Every value the treadmill fields hold reads back as itself, which is what the commit
        // path does with them.
        for tenths in 0...300 {
            let value = Double(tenths) / 10
            #expect(Double(fixedOneDecimal(value)) == value, "\(value)")
        }
    }

    @Test func localizedCountTextUsesSingularAndPlural() {
        #expect(localizedCountText(1, singular: "set", plural: "sets") == "1 set")
        #expect(localizedCountText(0, singular: "set", plural: "sets") == "0 sets")
        #expect(localizedCountText(3, singular: "set", plural: "sets") == "3 sets")
    }

    @Test func roundedDisplayValueRoundsAndPassesThroughNegativeDigits() {
        #expect(abs(roundedDisplayValue(2.346, fractionDigits: 2) - 2.35) < 1e-9)
        #expect(abs(roundedDisplayValue(2.344, fractionDigits: 2) - 2.34) < 1e-9)
        #expect(roundedDisplayValue(2.5, fractionDigits: 0) == 3)
        #expect(roundedDisplayValue(123.456, fractionDigits: -1) == 123.456)
    }

    @Test func roundedWeightDisplayValueConvertsThenRounds() {
        #expect(roundedWeightDisplayValue(100, unit: .kg, fractionDigits: 2) == 100)
        let lbs = roundedWeightDisplayValue(100, unit: .lbs, fractionDigits: 2)
        #expect(abs(lbs - 220.46) < 0.01)
    }

    @Test func formattedWeightTextAppendsUnitLabel() {
        #expect(formattedWeightText(100, unit: .kg, fractionDigits: 0...1) == "100 kg")
    }

    @Test func formattedHeartRateTextHandlesNilAndValue() {
        #expect(formattedHeartRateText(nil) == "-")
        #expect(formattedHeartRateText(72) == "72 bpm")
    }

    @Test func formattedHeartRateRangeTextCoversAllCombinations() {
        #expect(formattedHeartRateRangeText(lower: nil, upper: 100) == "Under 100 bpm")
        #expect(formattedHeartRateRangeText(lower: 60, upper: nil) == "60+ bpm")
        #expect(formattedHeartRateRangeText(lower: 60, upper: 100) == "60-100 bpm")
        #expect(formattedHeartRateRangeText(lower: nil, upper: nil) == "Estimated range")
    }

    @Test func workoutEffortTitleMapsBandsAndDefaults() {
        #expect(workoutEffortTitle(1) == "Very Easy")
        #expect(workoutEffortTitle(2) == "Very Easy")
        #expect(workoutEffortTitle(4) == "Light")
        #expect(workoutEffortTitle(6) == "Moderate")
        #expect(workoutEffortTitle(8) == "Hard")
        #expect(workoutEffortTitle(9) == "Near Max")
        #expect(workoutEffortTitle(10) == "All Out")
        #expect(workoutEffortTitle(0) == "Workout Effort")
        #expect(workoutEffortTitle(11) == "Workout Effort")
    }

    @Test func workoutEffortDescriptionMapsBandsAndDefault() {
        #expect(workoutEffortDescription(2) == "Very easy, minimal exertion.")
        #expect(workoutEffortDescription(10) == "Absolute maximum effort.")
        #expect(workoutEffortDescription(0) == "How hard was this workout?")
    }

    @Test func formattedRecentDayUsesWeekdayForRecentPastAndAbsoluteForOlder() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        cal.locale = Locale(identifier: "en_US")
        let locale = Locale(identifier: "en_US")
        func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
            cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
        }
        let reference = date(2026, 1, 15)
        // 2026-01-12 is a Monday, 3 days before the reference → weekday name.
        #expect(formattedRecentDay(date(2026, 1, 12), relativeTo: reference, calendar: cal, locale: locale) == "Monday")
        // 14 days before → absolute format that includes the year.
        let older = formattedRecentDay(date(2026, 1, 1), relativeTo: reference, calendar: cal, locale: locale)
        #expect(older.contains("2026"))
    }

    @Test func formattedDistanceTextUsesUnitLabel() {
        #expect(formattedDistanceText(1_000, unit: .km, fractionDigits: 0...2) == "1 km")
        #expect(formattedDistanceText(1_609.344, unit: .mi, fractionDigits: 0...2) == "1 mi")
    }

    @Test func formattedEnergyTextConvertsAndLabels() {
        #expect(formattedEnergyText(100, unit: .kcal) == "100 kcal")
        #expect(formattedEnergyText(100, unit: .kJ) == "418 kJ")
    }

    @Test func formattedPaceTextNilGuardsAndValue() {
        #expect(formattedPaceText(duration: 0, distanceMeters: 1_000, distanceUnit: .km) == nil)
        #expect(formattedPaceText(duration: 600, distanceMeters: 0, distanceUnit: .km) == nil)
        #expect(formattedPaceText(duration: 600, distanceMeters: 1_000, distanceUnit: .km) == "10:00 /km")
    }

    @Test func formattedWeightPerWeekTextAppendsPerWeekLabel() {
        #expect(formattedWeightPerWeekText(1, unit: .kg, fractionDigits: 0...1) == "1 kg/wk")
    }

    @Test func formattedHeartRateValueOmitsUnit() {
        #expect(formattedHeartRateValue(72) == "72")
    }
}

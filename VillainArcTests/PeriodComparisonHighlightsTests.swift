import Foundation
import Testing

@testable import VillainArc

struct PeriodComparisonHighlightsTests {
    private func cal() -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.locale = Locale(identifier: "en_US")
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal().date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    @Test func monthComparisonReturnsUpTrend() {
        let now = date(2026, 3, 15)
        let entries: [(date: Date, value: Double)] = [
            (date(2026, 3, 10), 100),
            (date(2026, 2, 10), 50)
        ]
        let highlight = makePeriodComparisonHighlight(entries: entries, kind: .month, now: now, calendar: cal(), date: { $0.date }, value: { $0.value })
        #expect(highlight != nil)
        #expect(highlight?.kind == .month)
        // Labels render via Date.formatted in the system timezone; assert the timezone-stable trend.
        #expect(highlight?.trend == .up)
    }

    @Test func monthComparisonNilWithoutPreviousData() {
        let now = date(2026, 3, 15)
        let entries: [(date: Date, value: Double)] = [(date(2026, 3, 10), 100)]
        #expect(makePeriodComparisonHighlight(entries: entries, kind: .month, now: now, calendar: cal(), date: { $0.date }, value: { $0.value }) == nil)
    }

    @Test func monthComparisonNilWithoutCurrentData() {
        let now = date(2026, 3, 15)
        let entries: [(date: Date, value: Double)] = [(date(2026, 2, 10), 50)]
        #expect(makePeriodComparisonHighlight(entries: entries, kind: .month, now: now, calendar: cal(), date: { $0.date }, value: { $0.value }) == nil)
    }

    @Test func yearComparisonReturnsUpTrend() {
        let now = date(2026, 6, 1)
        let entries: [(date: Date, value: Double)] = [
            (date(2026, 5, 1), 200),
            (date(2025, 5, 1), 100)
        ]
        let highlight = makePeriodComparisonHighlight(entries: entries, kind: .year, now: now, calendar: cal(), date: { $0.date }, value: { $0.value })
        #expect(highlight != nil)
        #expect(highlight?.kind == .year)
        #expect(highlight?.trend == .up)
    }

    @Test func flatThresholdForcesFlatTrend() {
        let now = date(2026, 3, 15)
        let entries: [(date: Date, value: Double)] = [
            (date(2026, 3, 10), 100),
            (date(2026, 2, 10), 50)
        ]
        let highlight = makePeriodComparisonHighlight(entries: entries, kind: .month, now: now, calendar: cal(), date: { $0.date }, value: { $0.value }, flatThreshold: 1_000_000)
        #expect(highlight?.trend == .flat)
    }

    @Test func yearLeadInSwitchesAtMidYear() {
        #expect(yearComparisonLeadIn(now: date(2026, 1, 5), calendar: cal()) == "So far this year")
        #expect(yearComparisonLeadIn(now: date(2026, 12, 20), calendar: cal()) == "This year")
    }
}

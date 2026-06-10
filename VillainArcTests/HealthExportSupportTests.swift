import Foundation
import Testing

@testable import VillainArc

struct HealthExportSupportTests {
    @Test func fullHealthExportJSONEncodesNonFiniteValuesAsStrings() throws {
        let day = Self.date(2026, 6, 8)
        let export = HealthFullExport(
            exportedAt: day,
            weightEntries: [
                WeightEntryExportRecord(date: day, weightKg: .nan)
            ],
            sleepNights: [
                SleepNightExportRecord(
                    date: day,
                    timeAsleepSeconds: .infinity,
                    timeInBedSeconds: 30_000,
                    remSeconds: 3_600,
                    coreSeconds: 14_400,
                    deepSeconds: 7_200,
                    awakeSeconds: 1_200,
                    sleepStart: day,
                    sleepEnd: day.addingTimeInterval(30_000)
                )
            ],
            stepsDistanceDays: [
                StepsDistanceExportRecord(date: day, steps: 12_345, distanceMeters: -.infinity)
            ],
            energyDays: [
                EnergyExportRecord(date: day, activeEnergyKcal: .nan, restingEnergyKcal: 1_850)
            ],
            heartDays: [
                HeartExportRecord(
                    date: day,
                    restingHeartRate: 58,
                    minHeartRate: .nan,
                    maxHeartRate: .infinity,
                    walkingHeartRateAverage: 92,
                    heartRateVariabilitySDNN: -.infinity
                )
            ],
            respiratoryRateDays: [
                RespiratoryRateExportRecord(date: day, minRate: .nan, maxRate: .infinity)
            ],
            wristTemperatureDays: [
                WristTemperatureExportRecord(date: day, temperatureCelsius: .nan)
            ],
            hydrationDays: [
                HydrationDayExportRecord(date: day, totalVolumeML: .infinity, goalTargetML: 3_000)
            ]
        )

        let json = try healthExportJSONString(export)

        #expect(json.contains(#""weightKg":"NaN""#))
        #expect(json.contains(#""timeAsleepSeconds":"+Infinity""#))
        #expect(json.contains(#""distanceMeters":"-Infinity""#))
        #expect(json.contains(#""heartRateVariabilitySDNN":"-Infinity""#))
        #expect(json.contains(#""totalVolumeML":"+Infinity""#))
    }

    @Test func buildHealthFullExportReferencesEveryLocalHealthBucketInSource() throws {
        let source = try Self.healthExportSupportSource()

        #expect(source.contains("context.fetch(WeightEntry.history)"))
        #expect(source.contains("context.fetch(HealthSleepNight.history)"))
        #expect(source.contains("context.fetch(HealthStepsDistance.history)"))
        #expect(source.contains("context.fetch(HealthEnergy.history)"))
        #expect(source.contains("context.fetch(HealthHeart.history)"))
        #expect(source.contains("context.fetch(HealthRespiratoryRate.history)"))
        #expect(source.contains("context.fetch(HealthWristTemperature.history)"))
        #expect(source.contains("context.fetch(HydrationDay.history)"))
    }

    @Test func healthExportDayStartsNormalizeReversedRangeAndIncludeInteriorDays() {
        let calendar = Self.testCalendar()
        let firstDay = calendar.startOfDay(for: Self.date(2026, 6, 8, calendar: calendar))
        let secondDay = calendar.date(byAdding: .day, value: 1, to: firstDay)!
        let thirdDay = calendar.date(byAdding: .day, value: 2, to: firstDay)!

        let days = healthExportDayStarts(
            start: thirdDay.addingTimeInterval(60 * 60 * 8),
            end: firstDay.addingTimeInterval(60 * 60 * 18),
            calendar: calendar
        )

        #expect(days == [firstDay, secondDay, thirdDay])
    }

    private static func date(_ year: Int, _ month: Int, _ day: Int, calendar: Calendar = .autoupdatingCurrent) -> Date {
        DateComponents(calendar: calendar, year: year, month: month, day: day, hour: 12).date!
    }

    private static func testCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private static func healthExportSupportSource() throws -> String {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("VillainArc/Intents/Health/HealthExportSupport.swift")
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}

import AppIntents
import Foundation
import SwiftData
import UniformTypeIdentifiers

// Codable JSON shapes for the health-export intents. These mirror the app's own
// local Health caches and records so a Shortcut can run an export intent and save
// the returned JSON to a file (e.g. iCloud Drive) for an external sync.
//
// Values are emitted RAW / canonical — weight in kilograms, durations in seconds,
// distance in meters, energy in kilocalories, wrist temperature in Celsius, water
// in milliliters — and dates are ISO8601. Unit conversion is the consumer's job.

nonisolated struct HealthDayExportRecord: Codable, Sendable {
    let date: Date
    let weightKg: Double?
    let sleepSeconds: Double?
    let steps: Int?
    let distanceMeters: Double?
    let activeEnergyKcal: Double?
    let restingEnergyKcal: Double?
}

nonisolated struct WeightEntryExportRecord: Codable, Sendable {
    let date: Date
    let weightKg: Double
}

nonisolated struct SleepNightExportRecord: Codable, Sendable {
    let date: Date
    let timeAsleepSeconds: Double
    let timeInBedSeconds: Double
    let remSeconds: Double
    let coreSeconds: Double
    let deepSeconds: Double
    let awakeSeconds: Double
    let sleepStart: Date?
    let sleepEnd: Date?
}

nonisolated struct StepsDistanceExportRecord: Codable, Sendable {
    let date: Date
    let steps: Int
    let distanceMeters: Double
}

nonisolated struct EnergyExportRecord: Codable, Sendable {
    let date: Date
    let activeEnergyKcal: Double
    let restingEnergyKcal: Double
}

nonisolated struct HeartExportRecord: Codable, Sendable {
    let date: Date
    let restingHeartRate: Double?
    let minHeartRate: Double?
    let maxHeartRate: Double?
    let walkingHeartRateAverage: Double?
    let heartRateVariabilitySDNN: Double?
}

nonisolated struct RespiratoryRateExportRecord: Codable, Sendable {
    let date: Date
    let minRate: Double?
    let maxRate: Double?
}

nonisolated struct WristTemperatureExportRecord: Codable, Sendable {
    let date: Date
    let temperatureCelsius: Double
}

nonisolated struct HydrationDayExportRecord: Codable, Sendable {
    let date: Date
    let totalVolumeML: Double
    let goalTargetML: Double?
}

nonisolated struct HealthFullExport: Codable, Sendable {
    let exportedAt: Date
    let weightEntries: [WeightEntryExportRecord]
    let sleepNights: [SleepNightExportRecord]
    let stepsDistanceDays: [StepsDistanceExportRecord]
    let energyDays: [EnergyExportRecord]
    let heartDays: [HeartExportRecord]
    let respiratoryRateDays: [RespiratoryRateExportRecord]
    let wristTemperatureDays: [WristTemperatureExportRecord]
    let hydrationDays: [HydrationDayExportRecord]
}

nonisolated func healthExportJSONEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    // A single non-finite Double (e.g. a NaN average computed over zero samples)
    // anywhere in the full-history export would otherwise make the default encoder
    // throw and fail the entire export. Emit a marker string for those rare values
    // instead of throwing, so the export always succeeds.
    encoder.nonConformingFloatEncodingStrategy = .convertToString(
        positiveInfinity: "+Infinity",
        negativeInfinity: "-Infinity",
        nan: "NaN"
    )
    return encoder
}

nonisolated func healthExportJSONString(_ value: some Encodable) throws -> String {
    let data = try healthExportJSONEncoder().encode(value)
    return String(decoding: data, as: UTF8.self)
}

// All export intents hand back an IntentFile (not a String) for one consistent shape
// a Shortcut can "Save File" — and because the full-history export is far larger than
// a Shortcuts string return can carry (it came back empty).
nonisolated func healthExportJSONFile(_ value: some Encodable, filename: String) throws -> IntentFile {
    IntentFile(data: try healthExportJSONEncoder().encode(value), filename: filename, type: .json)
}

nonisolated func healthDayExportRecord(from snapshot: HealthDaySnapshot) -> HealthDayExportRecord {
    HealthDayExportRecord(
        date: snapshot.day,
        weightKg: snapshot.weightKg,
        sleepSeconds: snapshot.sleepDuration,
        steps: snapshot.steps,
        distanceMeters: snapshot.distanceMeters,
        activeEnergyKcal: snapshot.activeEnergyKilocalories,
        restingEnergyKcal: snapshot.restingEnergyKilocalories
    )
}

// Builds one day-level record per calendar day in [start, end] (inclusive), reusing
// the same per-day snapshot loader the spoken health intents use.
nonisolated func healthDayExportRecords(start: Date, end: Date, context: ModelContext) throws -> [HealthDayExportRecord] {
    let calendar = Calendar.autoupdatingCurrent
    let lowerBound = calendar.startOfDay(for: min(start, end))
    // Never iterate past today — there is no tracked data for future days, and a
    // mis-entered end date would otherwise emit a tail of empty future records.
    let upperBound = min(calendar.startOfDay(for: max(start, end)), calendar.startOfDay(for: .now))

    var records: [HealthDayExportRecord] = []
    var day = lowerBound
    while day <= upperBound {
        records.append(healthDayExportRecord(from: try loadHealthDaySnapshot(for: day, context: context)))
        guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
        day = next
    }
    return records
}

// Full local-history dump across every per-day Health cache and the weight log.
// Workouts and cardio sessions are intentionally omitted (relationship-heavy; see
// APP_INTENTS_AUDIT.md follow-ups). Nutrition/dietary intake is not yet tracked.
nonisolated func buildHealthFullExport(context: ModelContext) throws -> HealthFullExport {
    let weightEntries = try context.fetch(WeightEntry.history).map {
        WeightEntryExportRecord(date: $0.date, weightKg: $0.weight)
    }

    let sleepNights = try context.fetch(HealthSleepNight.history).map {
        SleepNightExportRecord(
            date: $0.wakeDay,
            timeAsleepSeconds: $0.timeAsleep,
            timeInBedSeconds: $0.timeInBed,
            remSeconds: $0.remDuration,
            coreSeconds: $0.coreDuration,
            deepSeconds: $0.deepDuration,
            awakeSeconds: $0.awakeDuration,
            sleepStart: $0.sleepStart,
            sleepEnd: $0.sleepEnd
        )
    }

    let stepsDistanceDays = try context.fetch(HealthStepsDistance.history).map {
        StepsDistanceExportRecord(date: $0.date, steps: $0.stepCount, distanceMeters: $0.distance)
    }

    let energyDays = try context.fetch(HealthEnergy.history).map {
        EnergyExportRecord(date: $0.date, activeEnergyKcal: $0.activeEnergyBurned, restingEnergyKcal: $0.restingEnergyBurned)
    }

    let heartDays = try context.fetch(HealthHeart.history).map {
        HeartExportRecord(
            date: $0.date,
            restingHeartRate: $0.restingHeartRate,
            minHeartRate: $0.minHeartRate,
            maxHeartRate: $0.maxHeartRate,
            walkingHeartRateAverage: $0.walkingHeartRateAverage,
            heartRateVariabilitySDNN: $0.heartRateVariabilitySDNN
        )
    }

    let respiratoryRateDays = try context.fetch(HealthRespiratoryRate.history).map {
        RespiratoryRateExportRecord(date: $0.date, minRate: $0.minRate, maxRate: $0.maxRate)
    }

    let wristTemperatureDays = try context.fetch(HealthWristTemperature.history).map {
        WristTemperatureExportRecord(date: $0.date, temperatureCelsius: $0.temperature)
    }

    let hydrationDays = try context.fetch(HydrationDay.history).map {
        HydrationDayExportRecord(date: $0.date, totalVolumeML: $0.totalVolume, goalTargetML: $0.goalTargetML)
    }

    return HealthFullExport(
        exportedAt: .now,
        weightEntries: weightEntries,
        sleepNights: sleepNights,
        stepsDistanceDays: stepsDistanceDays,
        energyDays: energyDays,
        heartDays: heartDays,
        respiratoryRateDays: respiratoryRateDays,
        wristTemperatureDays: wristTemperatureDays,
        hydrationDays: hydrationDays
    )
}

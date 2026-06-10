import Foundation
import SwiftData

nonisolated func heartRateDialog(for date: Date, context: ModelContext) throws -> String {
    try SetupGuard.requireReady(context: context)

    let day = Calendar.autoupdatingCurrent.startOfDay(for: date)
    let dayText = formattedRecentDay(day)
    let isToday = Calendar.autoupdatingCurrent.isDateInToday(day)

    guard let heart = try context.fetch(HealthHeart.forDay(day)).first else {
        return isToday ? String(localized: "You don't have heart rate data for today yet.") : String(localized: "You don't have heart rate data for \(dayText) yet.")
    }

    var parts: [String] = []
    if let resting = heart.restingHeartRate {
        parts.append(String(localized: "your resting heart rate is \(formattedHeartRateText(resting))"))
    }
    if let minRate = heart.minHeartRate, let maxRate = heart.maxHeartRate {
        parts.append(String(localized: "your heart rate ranged from \(formattedHeartRateValue(minRate)) to \(formattedHeartRateText(maxRate))"))
    }
    if let walking = heart.walkingHeartRateAverage {
        parts.append(String(localized: "your walking average is \(formattedHeartRateText(walking))"))
    }
    if let hrv = heart.heartRateVariabilitySDNN {
        parts.append(String(localized: "your heart rate variability is \(hrv.formatted(.number.precision(.fractionLength(0)))) ms"))
    }

    guard !parts.isEmpty else {
        return isToday ? String(localized: "You don't have heart rate data for today yet.") : String(localized: "You don't have heart rate data for \(dayText) yet.")
    }

    let joined = ListFormatter.localizedString(byJoining: parts)
    return isToday ? String(localized: "Today, \(joined).") : String(localized: "On \(dayText), \(joined).")
}

nonisolated func respiratoryRateDialog(for date: Date, context: ModelContext) throws -> String {
    try SetupGuard.requireReady(context: context)

    let day = Calendar.autoupdatingCurrent.startOfDay(for: date)
    let dayText = formattedRecentDay(day)
    let isToday = Calendar.autoupdatingCurrent.isDateInToday(day)

    guard let respiratory = try context.fetch(HealthRespiratoryRate.forDay(day)).first else {
        return isToday ? String(localized: "You don't have respiratory rate data for today yet.") : String(localized: "You don't have respiratory rate data for \(dayText) yet.")
    }

    let subject = isToday ? String(localized: "Today") : String(localized: "On \(dayText)")
    let unit = String(localized: "breaths per minute")
    switch (respiratory.minRate, respiratory.maxRate) {
    case let (minRate?, maxRate?):
        if minRate == maxRate {
            return String(localized: "\(subject), your respiratory rate is \(minRate.formatted(.number.precision(.fractionLength(0)))) \(unit).")
        }
        return String(localized: "\(subject), your respiratory rate ranged from \(minRate.formatted(.number.precision(.fractionLength(0)))) to \(maxRate.formatted(.number.precision(.fractionLength(0)))) \(unit).")
    case let (minRate?, nil):
        return String(localized: "\(subject), your lowest respiratory rate was \(minRate.formatted(.number.precision(.fractionLength(0)))) \(unit).")
    case let (nil, maxRate?):
        return String(localized: "\(subject), your highest respiratory rate was \(maxRate.formatted(.number.precision(.fractionLength(0)))) \(unit).")
    case (nil, nil):
        return isToday ? String(localized: "You don't have respiratory rate data for today yet.") : String(localized: "You don't have respiratory rate data for \(dayText) yet.")
    }
}

nonisolated func wristTemperatureDialog(for date: Date, context: ModelContext) throws -> String {
    try SetupGuard.requireReady(context: context)

    let day = Calendar.autoupdatingCurrent.startOfDay(for: date)
    let dayText = formattedRecentDay(day)
    let isToday = Calendar.autoupdatingCurrent.isDateInToday(day)

    guard let entry = try context.fetch(HealthWristTemperature.forDay(day)).first else {
        return isToday ? String(localized: "You don't have wrist temperature data for today yet.") : String(localized: "You don't have wrist temperature data for \(dayText) yet.")
    }

    let settings = AppSettingsSnapshot(settings: try context.fetch(AppSettings.single).first)
    return isToday
        ? String(localized: "Today, your sleeping wrist temperature is \(settings.temperatureUnit.display(entry.temperature)).")
        : String(localized: "On \(dayText), your sleeping wrist temperature was \(settings.temperatureUnit.display(entry.temperature)).")
}

nonisolated func hydrationDialog(for date: Date, context: ModelContext) throws -> String {
    try SetupGuard.requireReady(context: context)

    let day = Calendar.autoupdatingCurrent.startOfDay(for: date)
    let dayText = formattedRecentDay(day)
    let isToday = Calendar.autoupdatingCurrent.isDateInToday(day)
    let settings = AppSettingsSnapshot(settings: try context.fetch(AppSettings.single).first)
    let hydrationDay = try context.fetch(HydrationDay.forDay(day)).first
    let total = hydrationDay?.totalVolume ?? 0

    guard total > 0 else {
        return isToday ? String(localized: "You haven't logged any water today yet.") : String(localized: "You didn't log any water for \(dayText).")
    }

    let totalText = settings.hydrationUnit.display(total)
    if let target = hydrationDay?.goalTargetML, target > 0 {
        let targetText = settings.hydrationUnit.display(target)
        if hydrationDay?.goalCompleted == true {
            return isToday
                ? String(localized: "Today you've had \(totalText) of water and hit your \(targetText) goal.")
                : String(localized: "On \(dayText), you had \(totalText) of water and hit your \(targetText) goal.")
        }
        return isToday
            ? String(localized: "Today you've had \(totalText) of water, against your \(targetText) goal.")
            : String(localized: "On \(dayText), you had \(totalText) of water, against your \(targetText) goal.")
    }

    return isToday
        ? String(localized: "Today you've had \(totalText) of water.")
        : String(localized: "On \(dayText), you had \(totalText) of water.")
}

import AppIntents
import Foundation
import SwiftData

enum HealthMetric: String, AppEnum {
    case weight
    case sleep
    case steps
    case distance
    case caloriesBurned

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Health Metric")

    static let caseDisplayRepresentations: [HealthMetric: DisplayRepresentation] = [
        .weight: "Weight",
        .sleep: "Sleep",
        .steps: "Steps",
        .distance: "Distance",
        .caloriesBurned: "Calories Burned"
    ]
}

struct HealthDaySnapshot {
    let day: Date
    let settings: AppSettingsSnapshot
    let weightKg: Double?
    let sleepDuration: TimeInterval?
    let steps: Int?
    let distanceMeters: Double?
    let activeEnergyKilocalories: Double?
    let restingEnergyKilocalories: Double?

    nonisolated var totalEnergyKilocalories: Double? {
        guard let activeEnergyKilocalories, let restingEnergyKilocalories else { return nil }
        return activeEnergyKilocalories + restingEnergyKilocalories
    }
}

nonisolated func makeHealthIntentReadContext() -> ModelContext {
    let context = ModelContext(SharedModelContainer.container)
    context.autosaveEnabled = false
    return context
}

nonisolated func loadHealthDaySnapshot(for date: Date, context: ModelContext) throws -> HealthDaySnapshot {
    try SetupGuard.requireReady(context: context)

    let settings = AppSettingsSnapshot(settings: try context.fetch(AppSettings.single).first)
    let calendar = Calendar.autoupdatingCurrent
    let dayStart = calendar.startOfDay(for: date)
    let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

    let weightPredicate = #Predicate<WeightEntry> { entry in
        entry.date >= dayStart && entry.date < nextDay
    }
    var weightDescriptor = FetchDescriptor(predicate: weightPredicate, sortBy: [SortDescriptor(\.date, order: .reverse)])
    weightDescriptor.fetchLimit = 1

    return HealthDaySnapshot(
        day: dayStart,
        settings: settings,
        weightKg: try context.fetch(weightDescriptor).first?.weight,
        sleepDuration: try context.fetch(HealthSleepNight.forWakeDay(dayStart)).first?.timeAsleep,
        steps: try context.fetch(HealthStepsDistance.forDay(dayStart)).first?.stepCount,
        distanceMeters: try context.fetch(HealthStepsDistance.forDay(dayStart)).first?.distance,
        activeEnergyKilocalories: try context.fetch(HealthEnergy.forDay(dayStart)).first?.activeEnergyBurned,
        restingEnergyKilocalories: try context.fetch(HealthEnergy.forDay(dayStart)).first?.restingEnergyBurned
    )
}

nonisolated func healthMetricDialog(for metric: HealthMetric, snapshot: HealthDaySnapshot) -> String {
    let dayText = formattedRecentDay(snapshot.day)
    let isToday = Calendar.autoupdatingCurrent.isDateInToday(snapshot.day)

    switch metric {
    case .weight:
        guard let weightKg = snapshot.weightKg else {
            return isToday ? "You don't have a weight entry for today." : "You don't have a weight entry for \(dayText)."
        }
        return isToday
            ? "Your latest weight today is \(formattedWeightText(weightKg, unit: snapshot.settings.weightUnit))."
            : "On \(dayText), your latest weight was \(formattedWeightText(weightKg, unit: snapshot.settings.weightUnit))."

    case .sleep:
        guard let sleepDuration = snapshot.sleepDuration else {
            return isToday ? "You don't have sleep data from last night yet." : "You don't have sleep data for \(dayText)."
        }
        return isToday
            ? "Last night, you slept \(formattedSleepDurationText(sleepDuration))."
            : "On \(dayText), you slept \(formattedSleepDurationText(sleepDuration))."

    case .steps:
        guard let steps = snapshot.steps else {
            return isToday ? "You don't have steps data for today yet." : "You don't have steps data for \(dayText)."
        }
        return isToday
            ? "Today, you've taken \(steps.formatted(.number)) steps."
            : "On \(dayText), you took \(steps.formatted(.number)) steps."

    case .distance:
        guard let distanceMeters = snapshot.distanceMeters else {
            return isToday ? "You don't have distance data for today yet." : "You don't have distance data for \(dayText)."
        }
        return isToday
            ? "Today, you've covered \(snapshot.settings.distanceUnit.display(distanceMeters))."
            : "On \(dayText), you covered \(snapshot.settings.distanceUnit.display(distanceMeters))."

    case .caloriesBurned:
        guard let totalEnergy = snapshot.totalEnergyKilocalories,
              let activeEnergy = snapshot.activeEnergyKilocalories
        else {
            return isToday ? "You don't have calories burned data for today yet." : "You don't have calories burned data for \(dayText)."
        }
        let totalText = formattedEnergyText(totalEnergy, unit: snapshot.settings.energyUnit)
        let activeText = formattedEnergyText(activeEnergy, unit: snapshot.settings.energyUnit)
        return isToday
            ? "Today, you've burned \(totalText) total, including \(activeText) active."
            : "On \(dayText), you burned \(totalText) total, including \(activeText) active."
    }
}

nonisolated func healthDaySummaryDialog(for snapshot: HealthDaySnapshot) -> String {
    let dayText = formattedRecentDay(snapshot.day)
    let isToday = Calendar.autoupdatingCurrent.isDateInToday(snapshot.day)
    var todayParts: [String] = []
    var sleepPart: String?

    if let weightKg = snapshot.weightKg {
        let text = isToday
            ? "your latest weight is \(formattedWeightText(weightKg, unit: snapshot.settings.weightUnit))"
            : "your latest weight was \(formattedWeightText(weightKg, unit: snapshot.settings.weightUnit))"
        todayParts.append(text)
    }

    if let sleepDuration = snapshot.sleepDuration {
        sleepPart = isToday
            ? "Last night, you slept \(formattedSleepDurationText(sleepDuration))."
            : "You slept \(formattedSleepDurationText(sleepDuration))."
    }

    if let steps = snapshot.steps {
        todayParts.append(isToday ? "you've taken \(steps.formatted(.number)) steps" : "you took \(steps.formatted(.number)) steps")
    }

    if let distanceMeters = snapshot.distanceMeters {
        todayParts.append(isToday ? "you've covered \(snapshot.settings.distanceUnit.display(distanceMeters))" : "you covered \(snapshot.settings.distanceUnit.display(distanceMeters))")
    }

    if let totalEnergy = snapshot.totalEnergyKilocalories {
        todayParts.append(isToday ? "you've burned \(formattedEnergyText(totalEnergy, unit: snapshot.settings.energyUnit)) total" : "you burned \(formattedEnergyText(totalEnergy, unit: snapshot.settings.energyUnit)) total")
    }

    guard sleepPart != nil || !todayParts.isEmpty else {
        return isToday ? "You don't have health data for today yet." : "You don't have health data for \(dayText) yet."
    }

    let todaySummary = todayParts.isEmpty ? nil : ListFormatter.localizedString(byJoining: todayParts)

    if isToday {
        switch (sleepPart, todaySummary) {
        case let (.some(sleepPart), .some(todaySummary)):
            return "\(sleepPart) Today, \(todaySummary)."
        case let (.some(sleepPart), .none):
            return sleepPart
        case let (.none, .some(todaySummary)):
            return "Today, \(todaySummary)."
        case (.none, .none):
            return "You don't have health data for today yet."
        }
    }

    var parts: [String] = []
    if let sleepPart {
        parts.append(sleepPart.replacingOccurrences(of: ".", with: ""))
    }
    if let todaySummary {
        parts.append(todaySummary)
    }
    return "For \(dayText), \(ListFormatter.localizedString(byJoining: parts))."
}

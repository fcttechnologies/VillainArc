import Foundation
import SwiftData

@Model final class HealthSleepNight {
    #Index<HealthSleepNight>([\.wakeDay])

    var wakeDay: Date = Date()
    var sleepStart: Date?
    var sleepEnd: Date?
    var timeAsleep: TimeInterval = 0
    var timeInBed: TimeInterval = 0
    var awakeDuration: TimeInterval = 0
    var remDuration: TimeInterval = 0
    var coreDuration: TimeInterval = 0
    var deepDuration: TimeInterval = 0
    var asleepUnspecifiedDuration: TimeInterval = 0
    var napDuration: TimeInterval = 0
    var hasStageBreakdown: Bool = false
    var isAvailableInHealthKit: Bool = true

    private static let wakeDayStorageTimeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    private static let wakeDayStorageCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = wakeDayStorageTimeZone
        return calendar
    }()

    init(wakeDay: Date, timeZone: TimeZone = .autoupdatingCurrent) { self.wakeDay = Self.wakeDayKey(for: wakeDay, in: timeZone) }

    init(storedWakeDayKey: Date) { self.wakeDay = storedWakeDayKey }

    var awakeInBedDuration: TimeInterval { max(timeInBed - timeAsleep, 0) }

    var displayWakeDay: Date { Self.displayDate(forWakeDay: wakeDay) }

    static func wakeDayKey(for date: Date, in timeZone: TimeZone = .autoupdatingCurrent) -> Date {
        var sourceCalendar = Calendar(identifier: .gregorian)
        sourceCalendar.timeZone = timeZone
        let components = sourceCalendar.dateComponents([.year, .month, .day], from: date)
        var storageComponents = DateComponents()
        storageComponents.calendar = wakeDayStorageCalendar
        storageComponents.timeZone = wakeDayStorageTimeZone
        storageComponents.year = components.year
        storageComponents.month = components.month
        storageComponents.day = components.day
        return wakeDayStorageCalendar.date(from: storageComponents) ?? wakeDayStorageCalendar.startOfDay(for: date)
    }

    static func displayDate(forWakeDay wakeDay: Date, in timeZone: TimeZone = .autoupdatingCurrent) -> Date {
        let components = wakeDayStorageCalendar.dateComponents([.year, .month, .day], from: wakeDay)
        var displayCalendar = Calendar(identifier: .gregorian)
        displayCalendar.timeZone = timeZone
        var displayComponents = DateComponents()
        displayComponents.calendar = displayCalendar
        displayComponents.timeZone = timeZone
        displayComponents.year = components.year
        displayComponents.month = components.month
        displayComponents.day = components.day
        displayComponents.hour = 12
        return displayCalendar.date(from: displayComponents) ?? wakeDay
    }

    static func nextWakeDay(after wakeDay: Date) -> Date { wakeDayStorageCalendar.date(byAdding: .day, value: 1, to: wakeDay) ?? wakeDay }

    static func previousWakeDay(before wakeDay: Date) -> Date { wakeDayStorageCalendar.date(byAdding: .day, value: -1, to: wakeDay) ?? wakeDay }
}

extension HealthSleepNight {
    static var history: FetchDescriptor<HealthSleepNight> { FetchDescriptor(sortBy: [SortDescriptor(\.wakeDay, order: .reverse)]) }

    static var summary: FetchDescriptor<HealthSleepNight> {
        var descriptor = history
        descriptor.fetchLimit = 7
        return descriptor
    }

    static func forWakeDay(_ day: Date) -> FetchDescriptor<HealthSleepNight> {
        let normalizedDay = wakeDayKey(for: day)
        let predicate = #Predicate<HealthSleepNight> { $0.wakeDay == normalizedDay }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.wakeDay)])
        descriptor.fetchLimit = 1
        return descriptor
    }

    static func forStoredWakeDayKey(_ wakeDayKey: Date) -> FetchDescriptor<HealthSleepNight> {
        let predicate = #Predicate<HealthSleepNight> { $0.wakeDay == wakeDayKey }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.wakeDay)])
        descriptor.fetchLimit = 1
        return descriptor
    }

    static func inWakeDayRange(_ range: ClosedRange<Date>) -> FetchDescriptor<HealthSleepNight> {
        let lowerBound = wakeDayKey(for: range.lowerBound)
        let upperBound = wakeDayKey(for: range.upperBound)
        let predicate = #Predicate<HealthSleepNight> { $0.wakeDay >= lowerBound && $0.wakeDay <= upperBound }
        return FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.wakeDay)])
    }

    static func inStoredWakeDayRange(_ range: ClosedRange<Date>) -> FetchDescriptor<HealthSleepNight> {
        let predicate = #Predicate<HealthSleepNight> { $0.wakeDay >= range.lowerBound && $0.wakeDay <= range.upperBound }
        return FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.wakeDay)])
    }
}

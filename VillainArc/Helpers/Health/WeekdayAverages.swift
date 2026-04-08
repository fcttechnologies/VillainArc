import Foundation

enum Weekday: String, CaseIterable, Identifiable, Sendable {
    case sunday
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday

    var id: String { rawValue }

    init?(calendarWeekdayNumber: Int) {
        switch calendarWeekdayNumber {
        case 1: self = .sunday
        case 2: self = .monday
        case 3: self = .tuesday
        case 4: self = .wednesday
        case 5: self = .thursday
        case 6: self = .friday
        case 7: self = .saturday
        default: return nil
        }
    }

    var calendarWeekdayNumber: Int {
        switch self {
        case .sunday: 1
        case .monday: 2
        case .tuesday: 3
        case .wednesday: 4
        case .thursday: 5
        case .friday: 6
        case .saturday: 7
        }
    }

    func shortLabel(calendar: Calendar = .autoupdatingCurrent) -> String {
        let labels = calendar.shortStandaloneWeekdaySymbols
        return labels[max(0, min(calendarWeekdayNumber - 1, labels.count - 1))]
    }

    func fullLabel(calendar: Calendar = .autoupdatingCurrent) -> String {
        let labels = calendar.weekdaySymbols
        return labels[max(0, min(calendarWeekdayNumber - 1, labels.count - 1))]
    }

    func pluralLabel(calendar: Calendar = .autoupdatingCurrent) -> String {
        fullLabel(calendar: calendar)
    }
}

struct WeekdayAveragePoint: Identifiable, Equatable, Sendable {
    let weekday: Weekday
    let averageValue: Double
    let sampleCount: Int

    var id: Weekday { weekday }
}

func makeWeekdayAveragePoints<Entry>(from entries: [Entry], calendar: Calendar = .autoupdatingCurrent, date: (Entry) -> Date, value: (Entry) -> Double) -> [WeekdayAveragePoint] {
    let groupedEntries = Dictionary(grouping: entries) { Weekday(calendarWeekdayNumber: calendar.component(.weekday, from: date($0))) ?? .sunday }

    return orderedWeekdays(calendar: calendar).map { weekday in
        let weekdayEntries = groupedEntries[weekday] ?? []
        let averageValue = weekdayEntries.isEmpty ? 0 : (weekdayEntries.reduce(0) { $0 + value($1) } / Double(weekdayEntries.count))
        return WeekdayAveragePoint(weekday: weekday, averageValue: averageValue, sampleCount: weekdayEntries.count)
    }
}

func orderedWeekdays(calendar: Calendar = .autoupdatingCurrent) -> [Weekday] {
    let firstWeekday = max(1, min(calendar.firstWeekday, 7))
    return (0..<7).compactMap { Weekday(calendarWeekdayNumber: ((firstWeekday - 1 + $0) % 7) + 1) }
}

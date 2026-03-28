import Foundation

extension Calendar {
    func endOfDay(for date: Date) -> Date {
        let start = startOfDay(for: date)
        return self.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? date
    }
    
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? date
    }

    func startOfYear(for date: Date) -> Date {
        self.date(from: dateComponents([.year], from: date)) ?? date
    }

    func endOfYear(for date: Date) -> Date {
        let start = startOfYear(for: date)
        let nextYear = self.date(byAdding: .year, value: 1, to: start) ?? start
        return nextYear.addingTimeInterval(-1)
    }
}

extension DateInterval {
    var chartUpperBound: Date {
        end.addingTimeInterval(-1)
    }
}

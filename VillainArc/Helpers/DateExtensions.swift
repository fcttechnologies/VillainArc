import Foundation

extension Calendar {
    func endOfDay(for date: Date) -> Date {
        let start = startOfDay(for: date)
        return self.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? date
    }
    
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? date
    }
}

extension DateInterval {
    var chartUpperBound: Date {
        end.addingTimeInterval(-1)
    }
}

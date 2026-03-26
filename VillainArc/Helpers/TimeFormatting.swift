import Foundation

func secondsToTime(_ seconds: Int) -> String {
    let clampedSeconds = max(0, seconds)
    let minutes = clampedSeconds / 60
    let remainingSeconds = clampedSeconds % 60
    if minutes < 10 { return String(format: "%d:%02d", minutes, remainingSeconds) }
    return String(format: "%02d:%02d", minutes, remainingSeconds)
}

func secondsToTimeWithHours(_ seconds: Int) -> String {
    let clampedSeconds = max(0, seconds)
    let hours = clampedSeconds / 3_600
    let remainingMinutes = (clampedSeconds % 3_600) / 60
    let remainingSeconds = clampedSeconds % 60
    return "\(hours):\(String(format: "%02d", remainingMinutes)):\(String(format: "%02d", remainingSeconds))"
}

func formattedDateRange(start: Date, end: Date? = nil, includeTime: Bool = false) -> String {
    let endDate = normalizedEndDate(start: start, end: end)
    let dateText = formattedRecentDateRangeText(start: start, end: endDate)

    guard includeTime else { return dateText }

    let timeText = formattedTimeRangeText(start: start, end: endDate)
    return "\(dateText) • \(timeText)"
}

func formattedRecentDay(_ date: Date) -> String {
    let calendar = Calendar.autoupdatingCurrent

    if calendar.isDateInToday(date) || calendar.isDateInYesterday(date) {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.calendar = calendar
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.doesRelativeDateFormatting = true
        return formatter.string(from: date)
    }

    return formattedSingleDate(date)
}

func formattedRecentDayAndTime(_ date: Date) -> String { "\(formattedRecentDay(date)) • \(date.formatted(date: .omitted, time: .shortened))" }

func formattedAbsoluteDateRange(start: Date, end: Date? = nil) -> String {
    guard let end = normalizedEndDate(start: start, end: end) else { return formattedSingleDate(start) }

    let calendar = Calendar.autoupdatingCurrent

    if calendar.isDate(start, inSameDayAs: end) { return formattedSingleDate(start) }

    let startYear = calendar.component(.year, from: start)
    let endYear = calendar.component(.year, from: end)
    let startMonth = calendar.component(.month, from: start)
    let endMonth = calendar.component(.month, from: end)

    if startYear == endYear, startMonth == endMonth {
        let formatter = DateIntervalFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.calendar = calendar
        formatter.timeStyle = .none
        formatter.dateTemplate = "MMM d y"
        return formatter.string(from: start, to: end)
    }

    let formatter = DateIntervalFormatter()
    formatter.locale = .autoupdatingCurrent
    formatter.calendar = calendar
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter.string(from: start, to: end)
}

private func formattedRecentDateRangeText(start: Date, end: Date?) -> String {
    guard let end else { return formattedRecentDay(start) }

    if Calendar.current.isDate(start, inSameDayAs: end) { return formattedRecentDay(start) }

    let calendar = Calendar.autoupdatingCurrent
    if calendar.isDateInYesterday(start), calendar.isDateInToday(end) { return localizedDateRangeLabel(start: formattedRecentDay(start), end: formattedRecentDay(end)) }

    let formatter = DateIntervalFormatter()
    formatter.locale = .autoupdatingCurrent
    formatter.calendar = calendar
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter.string(from: start, to: end)
}

private func formattedSingleDate(_ date: Date) -> String { date.formatted(.dateTime.month(.abbreviated).day().year()) }

private func formattedTimeRangeText(start: Date, end: Date?) -> String {
    guard let end else { return start.formatted(date: .omitted, time: .shortened) }
    let formatter = DateIntervalFormatter()
    formatter.locale = .autoupdatingCurrent
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    return formatter.string(from: start, to: end)
}

private func localizedDateRangeLabel(start: String, end: String) -> String { String(format: String(localized: "%1$@ - %2$@"), locale: .autoupdatingCurrent, start, end) }

private func normalizedEndDate(start: Date, end: Date?) -> Date? {
    guard let end else { return nil }
    return end <= start ? nil : end
}

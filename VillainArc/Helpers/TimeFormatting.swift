import Foundation

func secondsToTime(_ seconds: Int) -> String {
    let clampedSeconds = max(0, seconds)
    let minutes = clampedSeconds / 60
    let remainingSeconds = clampedSeconds % 60
    if minutes < 10 {
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
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
    let dateText = formattedDateRangeText(start: start, end: endDate)

    guard includeTime else {
        return dateText
    }

    let timeText = formattedTimeRangeText(start: start, end: endDate)
    return "\(dateText) • \(timeText)"
}

private func formattedDateRangeText(start: Date, end: Date?) -> String {
    guard let end else {
        return formattedSingleDate(start)
    }

    if Calendar.current.isDate(start, inSameDayAs: end) {
        return formattedSingleDate(start)
    }

    let formatter = DateIntervalFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter.string(from: start, to: end)
}

private func formattedSingleDate(_ date: Date) -> String {
    date.formatted(.dateTime.month(.abbreviated).day().year())
}

private func formattedTimeRangeText(start: Date, end: Date?) -> String {
    guard let end else {
        return start.formatted(date: .omitted, time: .shortened)
    }
    let formatter = DateIntervalFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    return formatter.string(from: start, to: end)
}

private func normalizedEndDate(start: Date, end: Date?) -> Date? {
    guard let end else { return nil }
    return end <= start ? nil : end
}

import Foundation

func secondsToTime(_ seconds: Int) -> String {
    let clampedSeconds = max(0, seconds)
    let hours = clampedSeconds / 3600
    let minutes = (clampedSeconds % 3600) / 60
    let remainingSeconds = clampedSeconds % 60

    if hours > 0 {
        return "\(hours):" + String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    return "\(minutes):" + String(format: "%02d", remainingSeconds)
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

    let calendar = Calendar.current
    if calendar.isDate(start, inSameDayAs: end) {
        return formattedSingleDate(start)
    }

    let startComponents = calendar.dateComponents([.year, .month, .day], from: start)
    let endComponents = calendar.dateComponents([.year, .month, .day], from: end)

    let startYear = startComponents.year ?? 0
    let endYear = endComponents.year ?? 0
    let startMonth = monthAbbreviation(for: start)
    let endMonth = monthAbbreviation(for: end)
    let startDay = startComponents.day ?? 0
    let endDay = endComponents.day ?? 0

    if startYear == endYear {
        if startComponents.month == endComponents.month {
            return "\(startMonth) \(startDay) - \(endDay), \(startYear)"
        }
        return "\(startMonth) \(startDay) - \(endMonth) \(endDay), \(startYear)"
    }

    return "\(startMonth) \(startDay), \(startYear) - \(endMonth) \(endDay), \(endYear)"
}

private func formattedSingleDate(_ date: Date) -> String {
    date.formatted(.dateTime.month(.abbreviated).day().year())
}

private func formattedTimeRangeText(start: Date, end: Date?) -> String {
    guard let end else {
        return formattedTime(start, includePeriod: true)
    }

    let startPeriod = dayPeriod(for: start)
    let endPeriod = dayPeriod(for: end)

    if startPeriod == endPeriod {
        return "\(formattedTime(start, includePeriod: false)) - \(formattedTime(end, includePeriod: true))"
    }

    return "\(formattedTime(start, includePeriod: true)) - \(formattedTime(end, includePeriod: true))"
}

private func formattedTime(_ date: Date, includePeriod: Bool) -> String {
    let components = Calendar.current.dateComponents([.hour, .minute], from: date)
    let hour24 = components.hour ?? 0
    let minute = components.minute ?? 0
    let hour12 = hour24 % 12
    let displayHour = hour12 == 0 ? 12 : hour12
    let minuteString = minute == 0 ? "" : String(format: ":%02d", minute)

    if includePeriod {
        return "\(displayHour)\(minuteString) \(dayPeriod(for: date))"
    }

    return "\(displayHour)\(minuteString)"
}

private func dayPeriod(for date: Date) -> String {
    let hour = Calendar.current.component(.hour, from: date)
    return hour < 12 ? "am" : "pm"
}

private func monthAbbreviation(for date: Date) -> String {
    date.formatted(.dateTime.month(.abbreviated))
}

private func normalizedEndDate(start: Date, end: Date?) -> Date? {
    guard let end else { return nil }
    return end <= start ? nil : end
}

import Foundation

nonisolated func secondsToTime(_ seconds: Int) -> String {
    let clampedSeconds = max(0, seconds)
    let minutes = clampedSeconds / 60
    let remainingSeconds = clampedSeconds % 60
    if minutes < 10 { return String(format: "%d:%02d", minutes, remainingSeconds) }
    return String(format: "%02d:%02d", minutes, remainingSeconds)
}

nonisolated func secondsToTimeWithHours(_ seconds: Int) -> String {
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

nonisolated func formattedRecentDay(_ date: Date) -> String {
    formattedRecentDay(date, relativeTo: .now)
}

nonisolated func formattedRecentDay(_ date: Date, relativeTo referenceDate: Date, calendar: Calendar = .autoupdatingCurrent, locale: Locale = .autoupdatingCurrent) -> String {
    let startOfDate = calendar.startOfDay(for: date)
    let startOfReferenceDate = calendar.startOfDay(for: referenceDate)
    let dayOffset = calendar.dateComponents([.day], from: startOfDate, to: startOfReferenceDate).day ?? .min

    if dayOffset == 0 || dayOffset == 1 {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.doesRelativeDateFormatting = true
        return formatter.string(from: date)
    }

    if (2...5).contains(dayOffset) {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.setLocalizedDateFormatFromTemplate("EEEE")
        return formatter.string(from: date)
    }

    return formattedSingleDate(date, calendar: calendar, locale: locale)
}

nonisolated func formattedRecentDayAndTime(_ date: Date) -> String { "\(formattedRecentDay(date)) • \(date.formatted(date: .omitted, time: .shortened))" }

nonisolated func localizedCountText(_ count: Int, singular: String.LocalizationValue, plural: String.LocalizationValue) -> String {
    let noun = count == 1 ? String(localized: singular) : String(localized: plural)
    return "\(count) \(noun)"
}

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

nonisolated func formattedWeightValue(_ kg: Double, unit: WeightUnit, fractionDigits: ClosedRange<Int> = 0...1) -> String {
    unit.fromKg(kg).formatted(.number.precision(.fractionLength(fractionDigits)))
}

nonisolated func roundedDisplayValue(_ value: Double, fractionDigits: Int) -> Double {
    guard fractionDigits >= 0 else { return value }
    let scale = pow(10.0, Double(fractionDigits))
    guard scale.isFinite, scale > 0 else { return value }
    return (value * scale).rounded() / scale
}

nonisolated func roundedWeightDisplayValue(_ kg: Double, unit: WeightUnit, fractionDigits: Int = 2) -> Double {
    roundedDisplayValue(unit.fromKg(kg), fractionDigits: fractionDigits)
}

nonisolated func formattedWeightText(_ kg: Double, unit: WeightUnit, fractionDigits: ClosedRange<Int> = 0...1) -> String {
    unit.display(kg, fractionDigits: fractionDigits)
}

nonisolated func formattedWeightPerWeekText(_ kgPerWeek: Double, unit: WeightUnit, fractionDigits: ClosedRange<Int> = 0...1) -> String {
    "\(formattedWeightValue(kgPerWeek, unit: unit, fractionDigits: fractionDigits)) \(unit.perWeekUnitLabel)"
}

nonisolated func formattedDistanceValue(_ meters: Double, unit: DistanceUnit, fractionDigits: ClosedRange<Int> = 0...2) -> String {
    unit.fromMeters(meters).formatted(.number.precision(.fractionLength(fractionDigits)))
}

nonisolated func formattedDistanceText(_ meters: Double, unit: DistanceUnit, fractionDigits: ClosedRange<Int> = 0...2) -> String {
    "\(formattedDistanceValue(meters, unit: unit, fractionDigits: fractionDigits)) \(unit.unitLabel)"
}

nonisolated func formattedPaceText(duration: TimeInterval, distanceMeters: Double, distanceUnit: DistanceUnit) -> String? {
    guard duration > 0, distanceMeters > 0 else { return nil }

    let unitDistance = distanceUnit.fromMeters(distanceMeters)
    guard unitDistance > 0 else { return nil }

    let secondsPerUnit = duration / unitDistance
    let timeText = secondsPerUnit >= 3_600
        ? secondsToTimeWithHours(Int(secondsPerUnit.rounded()))
        : secondsToTime(Int(secondsPerUnit.rounded()))

    return "\(timeText) \(distanceUnit.paceUnitLabel)"
}

nonisolated func heartRateUnitLabel() -> String {
    String(localized: "bpm")
}

nonisolated func formattedHeartRateText(_ bpm: Double?, fractionDigits: ClosedRange<Int> = 0...0) -> String {
    guard let bpm else { return "-" }
    return "\(bpm.formatted(.number.precision(.fractionLength(fractionDigits)))) \(heartRateUnitLabel())"
}

nonisolated func formattedHeartRateValue(_ bpm: Double, fractionDigits: ClosedRange<Int> = 0...0) -> String {
    bpm.formatted(.number.precision(.fractionLength(fractionDigits)))
}

nonisolated func formattedHeartRateRangeText(lower: Int?, upper: Int?) -> String {
    switch (lower, upper) {
    case let (nil, upper?):
        return String(localized: "Under \(upper) \(heartRateUnitLabel())")
    case let (lower?, nil):
        return String(localized: "\(lower)+ \(heartRateUnitLabel())")
    case let (lower?, upper?):
        return String(localized: "\(lower)-\(upper) \(heartRateUnitLabel())")
    case (nil, nil):
        return String(localized: "Estimated range")
    }
}

nonisolated func formattedEnergyValue(_ kilocalories: Double, unit: EnergyUnit, fractionDigits: ClosedRange<Int> = 0...0) -> String {
    unit.fromKilocalories(kilocalories).formatted(.number.precision(.fractionLength(fractionDigits)))
}

nonisolated func formattedEnergyText(_ kilocalories: Double, unit: EnergyUnit, fractionDigits: ClosedRange<Int> = 0...0) -> String {
    "\(formattedEnergyValue(kilocalories, unit: unit, fractionDigits: fractionDigits)) \(unit.unitLabel)"
}

nonisolated func formattedEnergyAccessibilityText(_ kilocalories: Double, unit: EnergyUnit, fractionDigits: ClosedRange<Int> = 0...0) -> String {
    "\(formattedEnergyValue(kilocalories, unit: unit, fractionDigits: fractionDigits)) \(unit.accessibilityUnitLabel)"
}

func workoutEffortTitle(_ value: Int) -> String {
    switch value {
    case 1...2: String(localized: "Very Easy")
    case 3...4: String(localized: "Light")
    case 5...6: String(localized: "Moderate")
    case 7...8: String(localized: "Hard")
    case 9: String(localized: "Near Max")
    case 10: String(localized: "All Out")
    default: String(localized: "Workout Effort")
    }
}

func workoutEffortDescription(_ value: Int) -> String {
    switch value {
    case 1...2: String(localized: "Very easy, minimal exertion.")
    case 3...4: String(localized: "Light effort, could do much more.")
    case 5...6: String(localized: "Moderate effort, comfortable pace.")
    case 7...8: String(localized: "Hard effort, pushing your limits.")
    case 9: String(localized: "Near maximal, barely completed.")
    case 10: String(localized: "Absolute maximum effort.")
    default: String(localized: "How hard was this workout?")
    }
}

nonisolated private func formattedRecentDateRangeText(start: Date, end: Date?) -> String {
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

nonisolated private func formattedSingleDate(_ date: Date, calendar: Calendar = .autoupdatingCurrent, locale: Locale = .autoupdatingCurrent) -> String {
    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.calendar = calendar
    formatter.setLocalizedDateFormatFromTemplate("MMMdyyyy")
    return formatter.string(from: date)
}

nonisolated private func formattedTimeRangeText(start: Date, end: Date?) -> String {
    guard let end else { return start.formatted(date: .omitted, time: .shortened) }
    let formatter = DateIntervalFormatter()
    formatter.locale = .autoupdatingCurrent
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    return formatter.string(from: start, to: end)
}

nonisolated private func localizedDateRangeLabel(start: String, end: String) -> String { String(format: String(localized: "%1$@ - %2$@"), locale: .autoupdatingCurrent, start, end) }

nonisolated private func normalizedEndDate(start: Date, end: Date?) -> Date? {
    guard let end else { return nil }
    return end <= start ? nil : end
}

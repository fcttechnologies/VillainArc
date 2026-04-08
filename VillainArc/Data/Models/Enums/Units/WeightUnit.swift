import Foundation

enum WeightUnit: String, CaseIterable, Codable, Hashable {
    case kg
    case lbs

    nonisolated static var systemDefault: WeightUnit { Locale.current.measurementSystem == .us ? .lbs : .kg }

    nonisolated var unitLabel: String { rawValue }

    nonisolated var perWeekUnitLabel: String { "\(unitLabel)/wk" }

    nonisolated var accessibilityUnitLabel: String {
        switch self {
        case .kg:
            return String(localized: "kilograms")
        case .lbs:
            return String(localized: "pounds")
        }
    }

    nonisolated func fromKg(_ kg: Double) -> Double { self == .lbs ? kg * 2.20462 : kg }

    nonisolated func toKg(_ value: Double) -> Double { self == .lbs ? value * 0.453592 : value }

    nonisolated func display(_ kg: Double, fractionDigits: ClosedRange<Int> = 0...1) -> String { "\(fromKg(kg).formatted(.number.precision(.fractionLength(fractionDigits)))) \(unitLabel)" }
}

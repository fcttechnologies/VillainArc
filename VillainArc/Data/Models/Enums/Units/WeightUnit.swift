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

    /// Exact pound↔kilogram factor (1 lb = 0.45359237 kg). One source of truth so kg↔lb round-trips don't drift.
    nonisolated static let kilogramsPerPound = 0.45359237

    nonisolated func fromKg(_ kg: Double) -> Double { self == .lbs ? kg / Self.kilogramsPerPound : kg }

    nonisolated func toKg(_ value: Double) -> Double { self == .lbs ? value * Self.kilogramsPerPound : value }

    nonisolated func display(_ kg: Double, fractionDigits: ClosedRange<Int> = 0...1) -> String { "\(fromKg(kg).formatted(.number.precision(.fractionLength(fractionDigits)))) \(unitLabel)" }
}

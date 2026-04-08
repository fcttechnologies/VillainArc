import Foundation

enum DistanceUnit: String, CaseIterable, Codable {
    case km
    case mi

    nonisolated static var systemDefault: DistanceUnit { Locale.current.measurementSystem == .us ? .mi : .km }

    nonisolated var unitLabel: String { rawValue }

    nonisolated var paceUnitLabel: String { "/\(unitLabel)" }

    nonisolated var accessibilityUnitLabel: String {
        switch self {
        case .km:
            return String(localized: "kilometers")
        case .mi:
            return String(localized: "miles")
        }
    }

    nonisolated func fromMeters(_ meters: Double) -> Double {
        switch self {
        case .km: return meters / 1_000
        case .mi: return meters / 1_609.344
        }
    }

    nonisolated func toMeters(_ value: Double) -> Double {
        switch self {
        case .km: return value * 1_000
        case .mi: return value * 1_609.344
        }
    }

    nonisolated func display(_ meters: Double, fractionDigits: ClosedRange<Int> = 0...2) -> String { "\(fromMeters(meters).formatted(.number.precision(.fractionLength(fractionDigits)))) \(unitLabel)" }
}

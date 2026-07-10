import Foundation

enum SpeedUnit: String, CaseIterable, Codable, Hashable {
    case kmh
    case mph

    nonisolated static var systemDefault: SpeedUnit {
        Locale.current.measurementSystem == .us ? .mph : .kmh
    }

    nonisolated var unitLabel: String {
        switch self {
        case .kmh: "km/h"
        case .mph: "mph"
        }
    }

    nonisolated var displayName: String {
        switch self {
        case .kmh: "Kilometers per Hour (km/h)"
        case .mph: "Miles per Hour (mph)"
        }
    }

    nonisolated func fromKPH(_ kph: Double) -> Double {
        switch self {
        case .kmh: kph
        case .mph: kph / 1.60934
        }
    }

    nonisolated func toKPH(_ value: Double) -> Double {
        switch self {
        case .kmh: value
        case .mph: value * 1.60934
        }
    }

    nonisolated func display(_ kph: Double, fractionDigits: ClosedRange<Int> = 1...1) -> String {
        "\(fromKPH(kph).formatted(.number.precision(.fractionLength(fractionDigits)))) \(unitLabel)"
    }

    /// Canonical treadmill speed cap, unit-independent (25 km/h ≈ 15.5 mph).
    /// Clamping in km/h keeps the ceiling the same for every user; a cap applied in
    /// display units would limit metric users to 15 km/h (≈ 9.3 mph) — below a real sprint.
    nonisolated static let maxTreadmillSpeedKPH = 25.0

    /// Clamps a treadmill speed typed in this display unit to 0.1...(25 km/h in this unit),
    /// rounded to one decimal place.
    nonisolated func clampedTreadmillInput(_ value: Double) -> Double {
        let cap = fromKPH(Self.maxTreadmillSpeedKPH)
        return (min(cap, max(0.1, value)) * 10).rounded() / 10
    }
}

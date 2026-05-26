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
}

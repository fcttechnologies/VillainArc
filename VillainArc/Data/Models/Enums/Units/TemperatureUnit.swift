import Foundation

enum TemperatureUnit: String, CaseIterable, Codable, Hashable {
    case celsius = "C"
    case fahrenheit = "F"

    nonisolated static var systemDefault: TemperatureUnit {
        Locale.current.measurementSystem == .us ? .fahrenheit : .celsius
    }

    nonisolated var unitLabel: String { "°\(rawValue)" }

    nonisolated var accessibilityUnitLabel: String {
        switch self {
        case .celsius:
            return String(localized: "degrees Celsius")
        case .fahrenheit:
            return String(localized: "degrees Fahrenheit")
        }
    }

    nonisolated func fromCelsius(_ celsius: Double) -> Double {
        switch self {
        case .celsius:
            return celsius
        case .fahrenheit:
            return (celsius * 9 / 5) + 32
        }
    }

    nonisolated func toCelsius(_ value: Double) -> Double {
        switch self {
        case .celsius:
            return value
        case .fahrenheit:
            return (value - 32) * 5 / 9
        }
    }

    nonisolated func display(_ celsius: Double, fractionDigits: ClosedRange<Int> = 0...1) -> String {
        "\(fromCelsius(celsius).formatted(.number.precision(.fractionLength(fractionDigits)))) \(unitLabel)"
    }
}

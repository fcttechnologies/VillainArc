import Foundation

enum HydrationUnit: String, CaseIterable, Codable, Hashable {
    case ml
    case flOz

    nonisolated static var systemDefault: HydrationUnit {
        Locale.current.measurementSystem == .us ? .flOz : .ml
    }

    nonisolated var unitLabel: String {
        switch self {
        case .ml: "mL"
        case .flOz: "fl oz"
        }
    }

    nonisolated var displayName: String {
        switch self {
        case .ml: "Milliliters (mL)"
        case .flOz: "Fluid Ounces (fl oz)"
        }
    }

    nonisolated func fromML(_ ml: Double) -> Double {
        switch self {
        case .ml: ml
        case .flOz: ml / 29.5735
        }
    }

    nonisolated func toML(_ value: Double) -> Double {
        switch self {
        case .ml: value
        case .flOz: value * 29.5735
        }
    }

    nonisolated func display(_ ml: Double, fractionDigits: ClosedRange<Int> = 0...1) -> String {
        let converted = fromML(ml)
        let formatted: String
        switch self {
        case .ml:
            formatted = Int(converted.rounded()).formatted(.number)
        case .flOz:
            formatted = converted.formatted(.number.precision(.fractionLength(fractionDigits)))
        }
        return "\(formatted) \(unitLabel)"
    }
}

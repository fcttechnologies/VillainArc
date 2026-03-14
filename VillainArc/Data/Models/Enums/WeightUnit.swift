import Foundation

enum WeightUnit: String, CaseIterable, Codable {
    case kg
    case lbs

    nonisolated static var systemDefault: WeightUnit {
        Locale.current.measurementSystem == .us ? .lbs : .kg
    }

    nonisolated func fromKg(_ kg: Double) -> Double {
        self == .lbs ? kg * 2.20462 : kg
    }

    nonisolated func toKg(_ value: Double) -> Double {
        self == .lbs ? value * 0.453592 : value
    }

    func display(_ kg: Double, fractionDigits: ClosedRange<Int> = 0...1) -> String {
        "\(fromKg(kg).formatted(.number.precision(.fractionLength(fractionDigits)))) \(rawValue)"
    }
}

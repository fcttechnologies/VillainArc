import Foundation

enum EnergyUnit: String, CaseIterable, Codable, Hashable {
    case kcal
    case kJ

    // There is no reliable locale-level Apple API for a user's preferred dietary/workout energy unit.
    // Keep the default predictable and let the user opt into kJ explicitly.
    nonisolated static let systemDefault: EnergyUnit = .kcal

    func fromKilocalories(_ kilocalories: Double) -> Double {
        switch self {
        case .kcal: return kilocalories
        case .kJ: return kilocalories * 4.184
        }
    }

    func toKilocalories(_ value: Double) -> Double {
        switch self {
        case .kcal: return value
        case .kJ: return value / 4.184
        }
    }

    var unitLabel: String { rawValue }

    var perDayUnitLabel: String { "\(unitLabel)/day" }

    var accessibilityUnitLabel: String {
        switch self {
        case .kcal: return "kilocalories"
        case .kJ: return "kilojoules"
        }
    }
}

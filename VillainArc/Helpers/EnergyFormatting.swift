import Foundation

func formattedEnergyValue(_ kilocalories: Double, unit: EnergyUnit, fractionDigits: ClosedRange<Int> = 0...0) -> String {
    unit.fromKilocalories(kilocalories).formatted(.number.precision(.fractionLength(fractionDigits)))
}

func formattedEnergyText(_ kilocalories: Double, unit: EnergyUnit, fractionDigits: ClosedRange<Int> = 0...0) -> String {
    "\(formattedEnergyValue(kilocalories, unit: unit, fractionDigits: fractionDigits)) \(unit.unitLabel)"
}

func formattedEnergyAccessibilityText(_ kilocalories: Double, unit: EnergyUnit, fractionDigits: ClosedRange<Int> = 0...0) -> String {
    "\(formattedEnergyValue(kilocalories, unit: unit, fractionDigits: fractionDigits)) \(unit.accessibilityUnitLabel)"
}

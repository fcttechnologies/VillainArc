import Foundation

func formattedWeightValue(_ kg: Double, unit: WeightUnit, fractionDigits: ClosedRange<Int> = 0...1) -> String {
    unit.fromKg(kg).formatted(.number.precision(.fractionLength(fractionDigits)))
}

nonisolated func formattedWeightText(_ kg: Double, unit: WeightUnit, fractionDigits: ClosedRange<Int> = 0...1) -> String {
    unit.display(kg, fractionDigits: fractionDigits)
}

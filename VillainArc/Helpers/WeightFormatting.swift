import Foundation

func formattedWeightValue(_ value: Double, fractionDigits: ClosedRange<Int> = 0...1) -> String {
    value.formatted(.number.precision(.fractionLength(fractionDigits)))
}

func formattedWeightText(_ value: Double, fractionDigits: ClosedRange<Int> = 0...1) -> String {
    "\(formattedWeightValue(value, fractionDigits: fractionDigits)) lbs"
}

import Foundation

enum HeightUnit: String, CaseIterable, Codable {
    case cm
    case imperial

    nonisolated static var systemDefault: HeightUnit { Locale.current.measurementSystem == .us ? .imperial : .cm }

    func toCm(feet: Int, inches: Double) -> Double { (Double(feet) * 12.0 + inches) * 2.54 }

    func fromCm(_ cm: Double) -> (feet: Int, inches: Double) {
        let totalInches = cm / 2.54
        let feet = Int(totalInches / 12)
        let inches = totalInches.truncatingRemainder(dividingBy: 12)
        return (feet, inches)
    }

    func displayString(cm: Double) -> String {
        switch self {
        case .cm: return "\(Int(cm.rounded())) cm"
        case .imperial:
            let (feet, inches) = fromCm(cm)
            return "\(feet)'\(Int(inches.rounded()))\""
        }
    }
}

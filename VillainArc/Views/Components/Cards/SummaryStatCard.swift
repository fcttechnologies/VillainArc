import SwiftUI

struct SummaryStatCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let title: String
    let text: String
    let date: Date?
    private let number: Double?
    private let fractionDigits: ClosedRange<Int>
    private let placeholderText: String
    private let usesNumericLayout: Bool

    init(title: String, text: String, date: Date? = nil) {
        self.title = title
        self.text = text
        self.date = date
        self.number = nil
        self.fractionDigits = 0...0
        self.placeholderText = text
        self.usesNumericLayout = false
    }

    init(title: String, number: Int, text: String = "", date: Date? = nil) {
        self.title = title
        self.text = text
        self.date = date
        self.number = Double(number)
        self.fractionDigits = 0...0
        self.placeholderText = "-"
        self.usesNumericLayout = true
    }

    init(title: String, number: Double, text: String = "", date: Date? = nil) {
        self.title = title
        self.text = text
        self.date = date
        self.number = number
        self.fractionDigits = 0...1
        self.placeholderText = "-"
        self.usesNumericLayout = true
    }

    init(title: String, number: Int?, text: String = "", placeholderText: String = "-", date: Date? = nil) {
        self.title = title
        self.text = text
        self.date = date
        self.number = number.map(Double.init)
        self.fractionDigits = 0...0
        self.placeholderText = placeholderText
        self.usesNumericLayout = true
    }

    init(title: String, number: Double?, text: String = "", placeholderText: String = "-", date: Date? = nil) {
        self.title = title
        self.text = text
        self.date = date
        self.number = number
        self.fractionDigits = 0...1
        self.placeholderText = placeholderText
        self.usesNumericLayout = true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let date {
                Text(date, style: .timer)
            } else if usesNumericLayout {
                HStack(alignment: .firstTextBaseline, spacing: text.isEmpty ? 0 : 4) {
                    if let number {
                        Text(number, format: .number.precision(.fractionLength(fractionDigits)))
                            .contentTransition(.numericText(value: number))
                    } else {
                        Text(placeholderText)
                    }

                    if !text.isEmpty, number != nil {
                        Text(text)
                    }
                }
                .animation(reduceMotion ? nil : .smooth(duration: 0.2), value: number)
            } else {
                Text(text)
            }
        }
        .fontDesign(.rounded)
        .font(.title3)
        .fontWeight(.semibold)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}

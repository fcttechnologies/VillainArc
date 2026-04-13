import SwiftUI

struct PeriodComparisonHighlightCard: View {
    let summary: Text
    let accessibilitySummary: String
    let currentValue: Double
    let previousValue: Double
    let currentLabel: String
    let previousLabel: String
    let unitText: String
    let tint: Color
    let valueText: (Double) -> String
    let accessibilityValueText: (Double) -> String

    init(summary: Text, accessibilitySummary: String, currentValue: Double, previousValue: Double, currentLabel: String, previousLabel: String, unitText: String, tint: Color, valueText: @escaping (Double) -> String = { Int($0.rounded()).formatted(.number) }, accessibilityValueText: ((Double) -> String)? = nil) {
        self.summary = summary
        self.accessibilitySummary = accessibilitySummary
        self.currentValue = currentValue
        self.previousValue = previousValue
        self.currentLabel = currentLabel
        self.previousLabel = previousLabel
        self.unitText = unitText
        self.tint = tint
        self.valueText = valueText
        self.accessibilityValueText = accessibilityValueText ?? { "\(Int($0.rounded()).formatted(.number)) \(unitText)" }
    }

    private var maxValue: Double { max(currentValue, previousValue, 1) }

    private var accessibilityValue: String {
        "\(accessibilitySummary) \(currentLabel): \(accessibilityValueText(currentValue)). \(previousLabel): \(accessibilityValueText(previousValue))."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            summary
                .font(.title3)
                .fontWeight(.semibold)
            Divider()
            ComparisonBarRow(value: currentValue, label: currentLabel, unitText: unitText, maxValue: maxValue, fillStyle: AnyShapeStyle(tint.gradient), valueTextStyle: AnyShapeStyle(.primary), labelTextStyle: AnyShapeStyle(.white), valueText: valueText)
            ComparisonBarRow(value: previousValue, label: previousLabel, unitText: unitText, maxValue: maxValue, fillStyle: AnyShapeStyle(Color.secondary.opacity(0.18)), valueTextStyle: AnyShapeStyle(.primary), labelTextStyle: AnyShapeStyle(.primary), valueText: valueText)
        }
        .padding()
        .appCardStyle()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityValue(accessibilityValue)
    }
}

private struct ComparisonBarRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let value: Double
    let label: String
    let unitText: String
    let maxValue: Double
    let fillStyle: AnyShapeStyle
    let valueTextStyle: AnyShapeStyle
    let labelTextStyle: AnyShapeStyle
    let valueText: (Double) -> String

    private var widthRatio: CGFloat { CGFloat(min(max(value / maxValue, 0), 1)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(valueText(value))
                    .font(.title)
                    .bold()
                    .fontDesign(.rounded)
                    .contentTransition(.numericText(value: value))
                if !unitText.isEmpty {
                    Text(unitText)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .fontWeight(.semibold)
                }
            }

            GeometryReader { proxy in
                let barWidth = max(proxy.size.width * widthRatio, 56)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(fillStyle)
                    .frame(width: min(barWidth, proxy.size.width))
                    .overlay(alignment: .leading) {
                        Text(label)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(labelTextStyle)
                            .padding(.horizontal, 12)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
            }
            .frame(height: 28)
        }
        .animation(reduceMotion ? nil : .smooth, value: value)
    }
}

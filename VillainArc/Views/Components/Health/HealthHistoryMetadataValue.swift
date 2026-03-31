import SwiftUI

struct HealthHistoryMetadataValue: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let title: String
    let text: String
    let animationValue: Double?

    init(title: String, text: String, animationValue: Double? = nil) {
        self.title = title
        self.text = text
        self.animationValue = animationValue
    }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Group {
                if let animationValue {
                    Text(text)
                        .contentTransition(.numericText(value: animationValue))
                } else {
                    Text(text)
                }
            }
            .font(.subheadline)
            .fontDesign(.rounded)
        }
        .fontWeight(.semibold)
        .animation(reduceMotion ? nil : .smooth, value: animationValue ?? 0)
        .accessibilityElement(children: .combine)
    }
}

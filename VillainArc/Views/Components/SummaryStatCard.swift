import SwiftUI

struct SummaryStatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fontWeight(.semibold)
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
        }
        .fontDesign(.rounded)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AccessibilityText.summaryStatCardLabel(title: title, value: value))
    }
}

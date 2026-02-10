import SwiftUI

struct HomeSectionHeaderButton: View {
    let title: String
    let accessibilityIdentifier: String
    let accessibilityHint: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 1) {
                Text(title)
                    .font(.title2)
                    .fontDesign(.rounded)
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
                    .font(.title3)
            }
            .fontWeight(.semibold)
            .accessibilityElement(children: .combine)
        }
        .buttonStyle(.plain)
        .padding(.leading, 10)
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityHint(accessibilityHint)
    }
}

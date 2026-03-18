import SwiftUI

struct MetadataChipItem: Identifiable, Hashable {
    let systemImage: String
    let text: String

    var id: String {
        "\(systemImage)-\(text)"
    }
}

struct MetadataChipRow: View {
    let items: [MetadataChipItem]

    var body: some View {
        HStack(spacing: 0) {
            if items.count > 1 {
                Spacer(minLength: 0)
            }

            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                MetadataChip(item: item)

                if index < items.count - 1 {
                    Spacer(minLength: 0)
                }
            }

            Spacer(minLength: 0)
        }
    }
}

struct MetadataChip: View {
    let item: MetadataChipItem

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: item.systemImage)
                .accessibilityHidden(true)
            Text(item.text)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
    }
}

import SwiftUI

struct MetadataChipItem: Identifiable, Hashable {
    let systemImage: String
    let text: String
    let tint: Color

    var id: String {
        "\(systemImage)-\(text)"
    }

    init(systemImage: String, text: String, tint: Color = .secondary) {
        self.systemImage = systemImage
        self.text = text
        self.tint = tint
    }
}

struct MetadataChipRow: View {
    let items: [MetadataChipItem]

    var body: some View {
        HStack(spacing: 3) {
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
        HStack(spacing: 0) {
            Spacer()
            Image(systemName: item.systemImage)
                .foregroundStyle(item.tint)
                .accessibilityHidden(true)
                .padding(.trailing, 3)
            Text(item.text)
            Spacer()
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
    }
}

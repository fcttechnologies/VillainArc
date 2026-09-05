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

/// A row's numbers as capsules — a duration, a distance, a pace — side by side while they fit and
/// stacked when they do not. Three of them across a narrow phone at an accessibility size is more
/// than any one line holds, and a truncated duration is a number that says nothing.
struct MetadataChipRow: View {
    let items: [MetadataChipItem]

    var body: some View {
        ViewThatFits(in: .horizontal) {
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

            VStack(spacing: 6) {
                ForEach(items) { item in
                    MetadataChip(item: item)
                }
            }
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

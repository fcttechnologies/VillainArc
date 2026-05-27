import SwiftUI

/// Shared "icon + caption + bold value" tile used across Cardio and Health Trends surfaces.
/// Pass `subCaption: " "` (single space) to preserve a placeholder row for grid height consistency.
struct MetricTile<Accessory: View>: View {
    let title: String
    let value: String
    let systemImage: String
    var tint: Color = .secondary
    var subCaption: String? = nil
    let accessory: Accessory

    init(
        title: String,
        value: String,
        systemImage: String,
        tint: Color = .secondary,
        subCaption: String? = nil,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() }
    ) {
        self.title = title
        self.value = value
        self.systemImage = systemImage
        self.tint = tint
        self.subCaption = subCaption
        self.accessory = accessory()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.caption)
                    .foregroundStyle(tint.gradient)
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(tint.gradient)
            }

            if value.isEmpty {
                accessory
                    .font(.title3.bold())
            } else {
                Text(value)
                    .font(.title3.bold())
                    .fontDesign(.rounded)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            if let subCaption {
                Text(subCaption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .appCardStyle()
    }
}

import SwiftUI

struct RPEBadge: View {
    enum Style {
        case actual
        case target

        var tint: Color {
            switch self {
            case .actual: .orange
            case .target: .blue
            }
        }

        var accessibilityPrefix: String {
            switch self {
            case .actual: "RPE"
            case .target: "Target RPE"
            }
        }
    }

    let value: Int
    var style: Style = .actual

    var body: some View {
        Text(value, format: .number)
            .font(.caption)
            .fontWeight(.semibold)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(style.tint)
            .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 12) {
        RPEBadge(value: 8)
        RPEBadge(value: 8, style: .target)
    }
    .padding()
}

import SwiftUI

struct RPEBadge: View {
    enum Style {
        case actual
        case target

        func tint(for value: Int) -> Color {
            switch self {
            case .actual: RPEValue.actualTint(for: value)
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
            .font(value == 10 ? .caption2 : .caption)
            .minimumScaleFactor(value == 10 ? 0.5 : 1)
            .lineLimit(1)
            .foregroundStyle(style.tint(for: value))
            .accessibilityHidden(true)
    }
}

enum RPEValue {
    static let selectableValues = [6, 7, 8, 9, 10]

    static func actualTint(for value: Int) -> Color {
        switch value {
        case 6: .green
        case 7: .mint
        case 8: .yellow
        case 9: .orange
        case 10: .red
        default: .orange
        }
    }

    static func pickerDescription(for value: Int, style: RPEBadge.Style) -> String {
        switch value {
        case 6: return "4+ reps in the tank"
        case 7: return "3 reps in the tank"
        case 8: return "2 reps in the tank"
        case 9: return "1 rep in the tank"
        case 10:
            switch style {
            case .actual: return "Nothing in the tank"
            case .target: return "Maximum effort"
            }
        default: return " "
        }
    }

    static func menuSubtitle(for value: Int?, style: RPEBadge.Style) -> String {
        guard let value, value > 0 else {
            return style == .target ? "Aim for" : "Left"
        }

        switch style {
        case .target:
            switch value {
            case 6: return "Aim for 4+ reps left in the tank"
            case 7: return "Aim for 3 reps left in the tank"
            case 8: return "Aim for 2 reps left in the tank"
            case 9: return "Aim for 1 rep left in the tank"
            case 10: return "Aim for maximum effort"
            default: return "Aim for"
            }
        case .actual:
            switch value {
            case 6: return "Left 4+ reps in the tank"
            case 7: return "Left 3 reps in the tank"
            case 8: return "Left 2 reps in the tank"
            case 9: return "Left 1 rep in the tank"
            case 10: return "Left 0 reps in the tank"
            default: return "Left"
            }
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        RPEBadge(value: 10)
        RPEBadge(value: 8, style: .target)
    }
    .padding()
}

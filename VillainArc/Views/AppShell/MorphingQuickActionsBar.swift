import SwiftUI
import TipKit

enum ExpandedActionKind {
    case generic
    case cardio
}

struct ExpandedAction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let accessibilityIdentifier: String
    let accessibilityHint: String
    let kind: ExpandedActionKind
    let contextMenu: AnyView?
    let showsCardioFavoriteTip: Bool
    let action: () -> Void

    init(_ title: String, icon: String, accessibilityIdentifier: String, accessibilityHint: String, kind: ExpandedActionKind = .generic, contextMenu: AnyView? = nil, showsCardioFavoriteTip: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.accessibilityIdentifier = accessibilityIdentifier
        self.accessibilityHint = accessibilityHint
        self.kind = kind
        self.contextMenu = contextMenu
        self.showsCardioFavoriteTip = showsCardioFavoriteTip
        self.action = action
    }
}

struct MorphingQuickActionsBar: View {
    @Binding var activeTab: AppTab
    @Binding var isExpanded: Bool
    let actions: [ExpandedAction]
    /// Read here rather than inside the grid: this is above the cap below, so it is the person's
    /// real setting and not the clamped one the grid would see.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            MorphingTabBar(activeTab: $activeTab, isExpanded: $isExpanded) {
                // Three columns at an accessibility size, where four leaves each title too narrow
                // to fit on one line and every label truncates.
                MorphingQuickActionsGrid(actions: actions, columnCount: dynamicTypeSize.isAccessibilitySize ? 3 : 4)
            }

            MorphingQuickActionsToggleButton(isExpanded: $isExpanded)
        }
        .padding(.horizontal, 15)
        // The floating bar is fixed-height chrome over the content it floats above, so its type
        // scales with the person's setting up to the largest non-accessibility size and then
        // holds — the same trade the system tab bar makes. Everything inside is sized relative to
        // a text style, so the cap is what keeps a glyph inside its 52-point row and the grid's
        // labels legible instead of either frozen at a caption size or overflowing the bar.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

private struct MorphingQuickActionsGrid: View {
    let actions: [ExpandedAction]
    let columnCount: Int
    private let cardioFavoriteTip = CardioFavoriteTip()
    /// Two lines of the label at whatever size it currently is, so a wrapped title keeps its
    /// second line instead of being clipped by a frame measured at the default size.
    @ScaledMetric(relativeTo: .caption2) private var labelMinHeight: CGFloat = 22

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .topLeading), count: columnCount), alignment: .leading, spacing: 10) {
            ForEach(actions) { action in
                VStack(alignment: .leading, spacing: 6) {
                    actionButton(for: action)

                    Text(action.title)
                        .font(.caption2)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, minHeight: labelMinHeight, alignment: .top)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .padding(10)
    }

    @ViewBuilder
    private func actionButton(for action: ExpandedAction) -> some View {
        let button = Button {
            Haptics.selection()
            action.action()
        } label: {
            Image(systemName: action.icon)
                .font(.title3)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .foregroundStyle(Color.primary)
                .background(.gray.opacity(0.09), in: .rect(cornerRadius: 16))
        }
        .buttonStyle(PlainGlassButtonEffect(shape: .rect(cornerRadius: 16)))
        .accessibilityLabel(action.title)
        .accessibilityHint(action.accessibilityHint)
        .accessibilityIdentifier(action.accessibilityIdentifier)

        if let contextMenu = action.contextMenu {
            if action.showsCardioFavoriteTip {
                button
                    .contextMenu { contextMenu }
                    .popoverTip(cardioFavoriteTip)
            } else {
                button
                    .contextMenu { contextMenu }
            }
        } else {
            button
        }
    }
}

private struct MorphingQuickActionsToggleButton: View {
    @Binding var isExpanded: Bool
    @ScaledMetric(relativeTo: .title3) private var glyphSize: CGFloat = 19

    var body: some View {
        Button {
            withAnimation(.bouncy(duration: 0.5, extraBounce: 0.05)) {
                Haptics.selection()
                isExpanded.toggle()
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: glyphSize, weight: .medium))
                .rotationEffect(.degrees(isExpanded ? 45 : 0))
                .frame(width: 52, height: 52)
                .foregroundStyle(Color.primary)
                .contentShape(.circle)
        }
        .buttonStyle(PlainGlassButtonEffect(shape: .circle))
        .contentShape(.circle)
        .accessibilityLabel(isExpanded ? AccessibilityText.morphingCollapseToolbarLabel : AccessibilityText.morphingExpandToolbarLabel)
        .accessibilityHint(AccessibilityText.morphingToolbarHint)
        .accessibilityIdentifier(AccessibilityIdentifiers.morphingToolbarToggleButton)
    }
}

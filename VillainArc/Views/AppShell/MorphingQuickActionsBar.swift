import SwiftUI

struct ExpandedAction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let accessibilityIdentifier: String
    let accessibilityHint: String
    let action: () -> Void

    init(_ title: String, icon: String, accessibilityIdentifier: String, accessibilityHint: String, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.accessibilityIdentifier = accessibilityIdentifier
        self.accessibilityHint = accessibilityHint
        self.action = action
    }
}

struct MorphingQuickActionsBar<Tab: MorphingTabProtocol>: View {
    @Binding var activeTab: Tab
    @Binding var isExpanded: Bool
    let actions: [ExpandedAction]

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            MorphingTabBar(activeTab: $activeTab, isExpanded: $isExpanded) {
                MorphingQuickActionsGrid(actions: actions)
            }

            MorphingQuickActionsToggleButton(isExpanded: $isExpanded)
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 5)
    }
}

private struct MorphingQuickActionsGrid: View {
    let actions: [ExpandedAction]

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .topLeading), count: 4),
            alignment: .leading,
            spacing: 10
        ) {
            ForEach(actions) { action in
                VStack(alignment: .leading, spacing: 6) {
                    Button {
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

                    Text(action.title)
                        .font(.system(size: 9))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, minHeight: 22, alignment: .top)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .padding(10)
    }
}

private struct MorphingQuickActionsToggleButton: View {
    @Binding var isExpanded: Bool

    var body: some View {
        Button {
            withAnimation(.bouncy(duration: 0.5, extraBounce: 0.05)) {
                Haptics.selection()
                isExpanded.toggle()
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 19, weight: .medium))
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

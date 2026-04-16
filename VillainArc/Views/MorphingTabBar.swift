import SwiftUI

struct MorphingTabBar<ExpandedContent: View>: View {
    @Binding var activeTab: AppTab
    @Binding var isExpanded: Bool
    @ViewBuilder var expandedContent: ExpandedContent

    @State private var viewWidth: CGFloat?

    var body: some View {
        ZStack {
            if let viewWidth {
                morphingBar(width: viewWidth)
            }
        }
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { viewWidth = $0 }
        .frame(height: viewWidth == nil ? 52 : nil)
    }

    private func morphingBar(width: CGFloat) -> some View {
        let progress: CGFloat = isExpanded ? 1 : 0
        let labelSize = CGSize(width: width, height: 52)
        let cornerRadius = labelSize.height / 2

        return ExpandableGlassEffect(alignment: .center, progress: progress, labelSize: labelSize, cornerRadius: cornerRadius) {
            expandedContent
        } label: {
            MorphingTabButtons(activeTab: $activeTab, isExpanded: isExpanded)
                .frame(height: 48)
        }
    }
}

private struct MorphingTabButtons: View {
    @Binding var activeTab: AppTab
    let isExpanded: Bool
    @Namespace private var selectionNamespace

    var body: some View {
        HStack(spacing: 6) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                let isSelected = activeTab == tab
                let accessibilityIdentifier = "morphingTabButton-\(tab.symbolImage)"

                Button {
                    withAnimation(.smooth) {
                        Haptics.selection()
                        activeTab = tab
                    }
                } label: {
                    ZStack {
                        if isSelected {
                            Capsule()
                                .fill(.thinMaterial)
                                .matchedGeometryEffect(id: "activeTab", in: selectionNamespace)
                        }

                        Image(systemName: tab.symbolImage)
                            .font(.system(size: 19, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .contentShape(.rect)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isExpanded)
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                .accessibilityLabel(tab.title)
                .accessibilityHint("Switches tabs.")
                .accessibilityIdentifier(accessibilityIdentifier)
                .accessibilityRemoveTraits(.isSelected)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }
}

struct PlainGlassButtonEffect<S: Shape>: ButtonStyle {
    var shape: S

    func makeBody(configuration: Configuration) -> some View {
        configuration.label.glassEffect(.regular.interactive(), in: shape)
    }
}

struct ExpandableGlassEffect<Content: View, Label: View>: View, Animatable {
    var alignment: Alignment
    var progress: CGFloat
    var labelSize: CGSize = .init(width: 55, height: 55)
    var cornerRadius: CGFloat = 30
    @ViewBuilder var content: Content
    @ViewBuilder var label: Label

    @State private var contentSize: CGSize = .zero

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        GlassEffectContainer {
            let widthDiff = contentSize.width - labelSize.width
            let heightDiff = contentSize.height - labelSize.height

            ZStack(alignment: .bottom) {
                content
                    .compositingGroup()
                    .scaleEffect(contentScale)
                    .blur(radius: 14 * blurProgress)
                    .opacity(contentOpacity)
                    .onGeometryChange(for: CGSize.self) { $0.size } action: { contentSize = $0 }
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: labelSize.width + widthDiff * contentOpacity, height: labelSize.height + heightDiff * contentOpacity)

                label
                    .compositingGroup()
                    .blur(radius: 14 * blurProgress)
                    .opacity(1 - labelOpacity)
                    .frame(width: labelSize.width, height: labelSize.height)
            }
            .compositingGroup()
            .clipShape(.rect(cornerRadius: cornerRadius))
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        }
        .scaleEffect(x: 1 - (blurProgress * 0.5), y: 1 + (blurProgress * 0.35), anchor: scaleAnchor)
        .offset(y: offset * blurProgress)
    }
}

private extension ExpandableGlassEffect {
    var labelOpacity: CGFloat {
        min(progress / 0.35, 1)
    }

    var contentOpacity: CGFloat {
        max(progress - 0.35, 0) / 0.65
    }

    var blurProgress: CGFloat {
        progress > 0.5 ? (1 - progress) / 0.5 : progress / 0.5
    }

    var contentScale: CGFloat {
        let minAspectScale = min(labelSize.width / contentSize.width, labelSize.height / contentSize.height)
        return minAspectScale + (1 - minAspectScale) * progress
    }

    var offset: CGFloat {
        switch alignment {
        case .bottom, .bottomLeading, .bottomTrailing: -80
        case .top, .topLeading, .topTrailing: 80
        default: -10
        }
    }

    var scaleAnchor: UnitPoint {
        switch alignment {
        case .bottomLeading: .bottomLeading
        case .bottom: .bottom
        case .bottomTrailing: .bottomTrailing
        case .topLeading: .topLeading
        case .top: .top
        case .topTrailing: .topTrailing
        case .leading: .leading
        case .trailing: .trailing
        default: .center
        }
    }
}

#Preview {
    MorphingTabBarPreview()
}

private struct MorphingTabBarPreview: View {
    @State private var activeTab: AppTab = .home
    @State private var isExpanded = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle().foregroundStyle(.clear)

            MorphingTabBar(activeTab: $activeTab, isExpanded: $isExpanded) {
                Rectangle()
                    .foregroundStyle(.clear)
                    .frame(width: 260, height: 180)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .ignoresSafeArea(.all, edges: .bottom)
    }
}

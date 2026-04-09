import SwiftUI

protocol MorphingTabProtocol: CaseIterable, Hashable {
    var title: String { get }
    var symbolImage: String { get }
}

struct MorphingTabBar<Tab: MorphingTabProtocol, ExpandedContent: View>: View {
    @Binding var activeTab: Tab
    @Binding var isExpanded: Bool
    @ViewBuilder var expandedContent: ExpandedContent

    @State private var viewWidth: CGFloat?

    private var symbols: [String] {
        Array(Tab.allCases).map(\.symbolImage)
    }

    private var selectedIndex: Binding<Int> {
        Binding(
            get: { symbols.firstIndex(of: activeTab.symbolImage) ?? 0 },
            set: { activeTab = Array(Tab.allCases)[$0] }
        )
    }

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
            ZStack {
                MorphingSegmentedTabBar(symbols: symbols, index: selectedIndex)
                    .allowsHitTesting(false)

                MorphingTabButtons(activeTab: $activeTab, isExpanded: isExpanded)
            }
            .frame(height: 48)
            .padding(.horizontal, 2)
            .offset(y: -0.7)
        }
    }
}

private struct MorphingTabButtons<Tab: MorphingTabProtocol>: View {
    @Binding var activeTab: Tab
    let isExpanded: Bool

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(Tab.allCases), id: \.self) { tab in
                Button {
                    Haptics.selection()
                    activeTab = tab
                } label: {
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .disabled(isExpanded)
                .accessibilityLabel(tab.title)
                .accessibilityHint("Switches tabs.")
                .accessibilityIdentifier("morphingTabButton-\(tab.symbolImage)")
                .accessibilityRemoveTraits(.isSelected)
                .accessibilityAddTraits(activeTab == tab ? .isSelected : [])
            }
        }
    }
}

private struct MorphingSegmentedTabBar: UIViewRepresentable {
    var tint: Color = .gray.opacity(0.15)
    var symbols: [String]
    @Binding var index: Int

    func makeUIView(context: Context) -> UISegmentedControl {
        let control = UISegmentedControl(items: symbols)
        control.selectedSegmentIndex = index
        control.selectedSegmentTintColor = UIColor(tint)
        control.isUserInteractionEnabled = false

        for (index, symbol) in symbols.enumerated() {
            control.setImage(symbolImage(symbol), forSegmentAt: index)
        }

        DispatchQueue.main.async {
            for view in control.subviews.dropLast() where view is UIImageView {
                view.alpha = 0
            }
        }

        return control
    }

    func updateUIView(_ uiView: UISegmentedControl, context: Context) {
        if uiView.selectedSegmentIndex != index {
            uiView.selectedSegmentIndex = index
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UISegmentedControl, context: Context) -> CGSize? {
        proposal.replacingUnspecifiedDimensions()
    }

    private func symbolImage(_ name: String) -> UIImage? {
        let configuration = UIImage.SymbolConfiguration(font: .systemFont(ofSize: 19))
        return UIImage(systemName: name, withConfiguration: configuration)
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
    @State private var isExpanded = true

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

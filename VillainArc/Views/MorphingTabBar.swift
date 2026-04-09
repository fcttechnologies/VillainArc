import SwiftUI

protocol MorphingTabProtocol: CaseIterable, Hashable {
    var symbolImage: String { get }
}

struct MorphingTabBar<Tab: MorphingTabProtocol, ExpandedContent: View>: View {
    @Binding var activeTab: Tab
    @Binding var isExpanded: Bool
    @ViewBuilder var expandedContent: ExpandedContent
    @State private var viewWidth: CGFloat?
    
    var body: some View {
        ZStack {
            let symbols = Array(Tab.allCases).compactMap({ $0.symbolImage })
            let selectedIndex = Binding {
                return symbols.firstIndex(of: activeTab.symbolImage) ?? 0
            } set: { index in
                activeTab = Array(Tab.allCases)[index]
            }
            
            if let viewWidth {
                let progress: CGFloat = isExpanded ? 1 : 0
                let labelSize: CGSize = CGSize(width: viewWidth, height: 52)
                let cornerRadius: CGFloat = labelSize.height / 2
                
                ExpandableGlassEffect(alignment: .center, progress: progress, labelSize: labelSize, cornerRadius: cornerRadius) {
                    expandedContent
                } label: {
                    CustomTabBar(symbols: symbols, index: selectedIndex) { image in
                        let font = UIFont.systemFont(ofSize: 19)
                        let configuration = UIImage.SymbolConfiguration(font: font)
                        
                        return UIImage(systemName: image, withConfiguration: configuration)
                    }
                    .frame(height: 48)
                    .padding(.horizontal, 2)
                    .offset(y: -0.7)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) {
            $0.size.width
        } action: { newValue in
            viewWidth = newValue
        }
        .frame(height: viewWidth == nil ? 52 : nil)
    }
}

fileprivate struct CustomTabBar: UIViewRepresentable {
    var tint: Color = .gray.opacity(0.15)
    var symbols: [String]
    @Binding var index: Int
    var image: (String) -> UIImage?
    func makeUIView(context: Context) -> UISegmentedControl {
        let control = UISegmentedControl(items: symbols)
        control.selectedSegmentIndex = index
        control.selectedSegmentTintColor = UIColor(tint)
        for (index, symbol) in symbols.enumerated() {
            control.setImage(image(symbol), forSegmentAt: index)
        }
        
        control.addTarget(context.coordinator, action: #selector(context.coordinator.didSelect(_:)), for: .valueChanged)
        
        DispatchQueue.main.async {
            for view in control.subviews.dropLast() {
                if view is UIImageView {
                    view.alpha = 0
                }
            }
        }
        
        return control
    }
    
    func updateUIView(_ uiView: UISegmentedControl, context: Context) {
        if uiView.selectedSegmentIndex != index {
            uiView.selectedSegmentIndex = index
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject {
        var parent: CustomTabBar
        init(parent: CustomTabBar) {
            self.parent = parent
        }
        
        @objc
        func didSelect(_ control: UISegmentedControl) {
            parent.index = control.selectedSegmentIndex
        }
    }
    
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UISegmentedControl, context: Context) -> CGSize? {
        return proposal.replacingUnspecifiedDimensions()
    }
}

struct TestingView: View {
    @State private var activeTab: AppTab = .home
    @State private var isExpanded: Bool = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // ContentView content
            Rectangle()
                .foregroundStyle(.clear)
            
            HStack(alignment: .bottom, spacing: 12) {
                MorphingTabBar(activeTab: $activeTab, isExpanded: $isExpanded) {
                    Rectangle()
                        .foregroundStyle(.clear)
                        .frame(height: 250)
                }
                
                Button {
                    withAnimation(.bouncy(duration: 0.5, extraBounce: 0.05)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 19, weight: .medium))
                        .rotationEffect(.init(degrees: isExpanded ? 45 : 0))
                        .frame(width: 52, height: 52)
                        .foregroundStyle(Color.primary)
                }
                .buttonStyle(PlainGlassButtonEffect(shape: .circle))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 25)
        }
        .ignoresSafeArea(.all, edges: .bottom)
    }
}

struct PlainGlassButtonEffect<S: Shape>: ButtonStyle {
    var shape: S
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .glassEffect(.regular.interactive(), in: shape)
    }
}

#Preview {
    TestingView()
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
            
            let rWidth = widthDiff * contentOpacity
            let rHeight = heightDiff * contentOpacity
            
            ZStack(alignment: .bottom) {
                content
                    .compositingGroup()
                    .scaleEffect(contentScale)
                    .blur(radius: 14 * blurProgress)
                    .opacity(contentOpacity)
                    .onGeometryChange(for: CGSize.self) {
                        $0.size
                    } action: { newValue in
                        contentSize = newValue
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: labelSize.width + rWidth, height: labelSize.height + rHeight)
                
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
    
    var labelOpacity: CGFloat {
        min(progress / 0.35, 1)
    }
    
    var contentOpacity: CGFloat {
        max(progress - 0.35, 0) / 0.65
    }
    
    var blurProgress: CGFloat {
        return progress > 0.5 ? (1 - progress) / 0.5 : progress / 0.5
    }
    
    var contentScale: CGFloat {
        let minAspectScale = min(labelSize.width / contentSize.width, labelSize.height / contentSize.height)
        
        return minAspectScale + (1 - minAspectScale) * progress
    }
    
    var offset: CGFloat {
        switch alignment {
        case .bottom, .bottomLeading, .bottomTrailing: return -80
        case .top, .topLeading, .topTrailing: return 80
        default: return -10
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

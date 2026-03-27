import SwiftUI

struct InlineLargeTitle: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.largeTitle)
            .bold()
            .fontDesign(.rounded)
    }
}

struct CloseButton: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Button(role: .close) {
            Haptics.selection()
            dismiss()
        } label: {
            Label("Close", systemImage: "xmark")
                .font(.title2)
                .labelStyle(.iconOnly)
                .padding(5)
        }
        .buttonBorderShape(.circle)
        .buttonStyle(.glass)
        .accessibilityIdentifier(AccessibilityIdentifiers.navBarCloseButton)
        .accessibilityHint(AccessibilityText.closeButtonHint)
    }
}

struct SheetTitleBar<Trailing: View>: View {
    let title: String
    let includePadding: Bool
    let trailing: Trailing
    
    init(title: String, includePadding: Bool, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.includePadding = includePadding
        self.trailing = trailing()
    }
    
    var body: some View {
        HStack(spacing: 0) {
            InlineLargeTitle(title: title)
            Spacer()
            trailing
        }
        .padding(.top, includePadding ? 20 : 0)
        .padding(.leading, 20)
        .padding(.trailing, 15)
    }
}

extension View {
    func navBar<Trailing: View>(title: String, includePadding: Bool = true, @ViewBuilder trailing: () -> Trailing) -> some View {
        safeAreaBar(edge: .top) {
            SheetTitleBar(title: title, includePadding: includePadding, trailing: trailing)
        }
    }
    
    func navBar(title: String, includePadding: Bool = true) -> some View {
        navBar(title: title, includePadding: includePadding) {
            EmptyView()
        }
    }
}

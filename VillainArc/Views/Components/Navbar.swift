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
    }
}

struct SheetTitleBar<Trailing: View>: View {
    let title: String
    let trailing: Trailing
    
    init(title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }
    
    var body: some View {
        HStack(spacing: 0) {
            InlineLargeTitle(title: title)
            Spacer()
            trailing
        }
        .padding(.top, 20)
        .padding(.leading, 20)
        .padding(.trailing, 15)
    }
}

extension View {
    func navBar<Trailing: View>(title: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        safeAreaBar(edge: .top) {
            SheetTitleBar(title: title, trailing: trailing)
        }
    }
    
    func navBar(title: String) -> some View {
        navBar(title: title) {
            EmptyView()
        }
    }
}

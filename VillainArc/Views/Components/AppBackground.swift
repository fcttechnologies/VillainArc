import SwiftUI

struct AppBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.bg.ignoresSafeArea())
    }
}

struct SheetBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.sheetBg.ignoresSafeArea())
    }
}

extension View {
    func appBackground() -> some View {
        modifier(AppBackground())
    }

    func sheetBackground() -> some View {
        modifier(SheetBackground())
    }
}

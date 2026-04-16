import SwiftUI

let quickActionContentBottomMargin: CGFloat = 52
let quickActionContentBottomMarginWithActiveFlow: CGFloat = 114

private struct QuickActionContentBottomInsetModifier: ViewModifier {
    @State private var router = AppRouter.shared

    private var bottomInset: CGFloat {
        let hasVisibleActiveFlowBar = !router.isQuickActionsBarHidden && router.hasHiddenActiveFlowPresentation
        return hasVisibleActiveFlowBar ? quickActionContentBottomMarginWithActiveFlow : quickActionContentBottomMargin
    }

    func body(content: Content) -> some View {
        content
            .contentMargins(.bottom, bottomInset, for: .scrollContent)
    }
}

extension View {
    func quickActionContentBottomInset() -> some View {
        modifier(QuickActionContentBottomInsetModifier())
    }
}

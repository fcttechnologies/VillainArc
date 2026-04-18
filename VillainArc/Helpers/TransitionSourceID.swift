import SwiftUI

enum TransitionSourceID {
    static let toolbar = "toolbarSource"
}

extension View {
    @ViewBuilder
    func matchedTransitionIfPossible(id: some Hashable, in namespace: Namespace.ID?) -> some View {
        if let namespace {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }
}

import SwiftUI

enum TransitionSourceID {
    static let toolbar = "toolbarSource"
}

extension AnyTransition {
    /// The slide the session shells advance a stage with, collapsed to a cross-fade under Reduce
    /// Motion.
    ///
    /// Built from the `Transition` types rather than the `AnyTransition` statics: the statics
    /// (`.opacity`, `.move(edge:)`) are `nonisolated(unsafe)` in SwiftUI, so reading one is an
    /// unsafe expression under strict memory safety, while `OpacityTransition()` and
    /// `MoveTransition(edge:)` construct the same effect safely.
    static func sessionAdvance(reduceMotion: Bool) -> AnyTransition {
        reduceMotion
            ? AnyTransition(OpacityTransition())
            : AnyTransition(MoveTransition(edge: .trailing).combined(with: OpacityTransition()))
    }
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

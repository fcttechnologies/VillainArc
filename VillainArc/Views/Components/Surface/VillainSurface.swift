import SwiftUI

private struct AppSurfaceStyle<S: InsettableShape>: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let shape: S
    let fillColor: Color

    private var ringWidth: CGFloat {
        colorScheme == .dark ? 0.5 : 1.5
    }

    func body(content: Content) -> some View {
        content
            .background {
                shape
                    .fill(Color.cardRing)
                    .overlay {
                        shape
                            .inset(by: ringWidth)
                            .fill(fillColor)
                    }
            }
            .clipShape(shape)
    }
}

private struct AppSubSurfaceStyle<S: InsettableShape>: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let shape: S

    private var fillColor: Color {
        colorScheme == .dark ? .black : .white
    }

    func body(content: Content) -> some View {
        content
            .background {
                shape
                    .fill(fillColor)
            }
            .clipShape(shape)
    }
}

extension View {
    func appSurfaceStyle<S: InsettableShape>(
        in shape: S,
        fillColor: Color = Color.cardFill
    ) -> some View {
        modifier(AppSurfaceStyle(shape: shape, fillColor: fillColor))
    }

    func appCardStyle(cornerRadius: CGFloat = 16) -> some View {
        appSurfaceStyle(in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    func appCapsuleStyle() -> some View {
        appSurfaceStyle(in: Capsule())
    }

    func appCircleStyle() -> some View {
        appSurfaceStyle(in: Circle())
    }

    func appSubCardStyle(cornerRadius: CGFloat = 16) -> some View {
        modifier(AppSubSurfaceStyle(shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)))
    }

    func appSubCapsuleStyle() -> some View {
        modifier(AppSubSurfaceStyle(shape: Capsule()))
    }
}

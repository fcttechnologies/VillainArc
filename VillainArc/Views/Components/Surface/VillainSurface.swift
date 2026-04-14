import SwiftUI

private struct AppSurfaceStyle<S: InsettableShape>: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let shape: S
    let fillColor: Color?

    private var resolvedFillColor: Color {
        fillColor ?? (colorScheme == .dark
            ? Color(.sRGB, red: 15.0 / 255.0, green: 15.0 / 255.0, blue: 15.0 / 255.0, opacity: 1)
            : .white)
    }

    private var darkModeRingColor: Color {
        Color(.sRGB, red: 51.0 / 255.0, green: 51.0 / 255.0, blue: 51.0 / 255.0, opacity: 1)
    }

    func body(content: Content) -> some View {
        content
            .background {
                if colorScheme == .dark {
                    shape
                        .fill(darkModeRingColor)
                        .overlay {
                            shape
                                .inset(by: 0.5)
                                .fill(resolvedFillColor)
                        }
                } else {
                    shape
                        .fill(resolvedFillColor)
                }
            }
            .clipShape(shape)
    }
}

private struct AppSubSurfaceStyle<S: InsettableShape>: ViewModifier {
    let shape: S

    func body(content: Content) -> some View {
        content
            .background {
                shape
                    .fill(.thinMaterial)
            }
            .clipShape(shape)
    }
}

extension View {
    func appSurfaceStyle<S: InsettableShape>(in shape: S, fillColor: Color? = nil) -> some View {
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

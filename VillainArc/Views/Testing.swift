import SwiftUI

struct Testing: View {
    private let cardHeight: CGFloat = 156

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 24) {
                Text("Light Ring Surface")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(.black)

                RingSurfaceCard(height: cardHeight, style: .light)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 28)
            .padding(.vertical, 36)
            .background(RingSurfaceStyle.light.stageBackground)

            VStack(alignment: .leading, spacing: 24) {
                Text("Dark Ring Surface")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(Color(white: 0.9))

                RingSurfaceCard(height: cardHeight, style: .dark)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 28)
            .padding(.vertical, 36)
            .background(RingSurfaceStyle.dark.stageBackground)
        }
    }
}

#Preview {
    Testing()
}

private struct RingSurfaceCard: View {
    let height: CGFloat
    let style: RingSurfaceStyle

    var body: some View {
        RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
            .fill(style.ringColor)
            .overlay {
                RoundedRectangle(
                    cornerRadius: style.cornerRadius - style.ringWidth,
                    style: .continuous
                )
                .fill(style.fillColor)
                .padding(style.ringWidth)
            }
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Villain Arc")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(style.titleColor)

                    Text("Focused lifting. Cleaner surfaces.")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(style.subtitleColor)

                    HStack(spacing: 10) {
                        SurfaceCapsule(
                            label: "Surface",
                            systemImage: "square.grid.2x2.fill",
                            style: style.neutralCapsuleStyle,
                            action: {}
                        )

                        SurfaceCapsule(
                            label: "PR Ready",
                            systemImage: "flame.fill",
                            style: style.tintCapsuleStyle,
                            action: {}
                        )
                    }
                }
                .padding(18)
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
    }
}

private struct RingSurfaceStyle {
    let stageBackground: Color
    let ringColor: Color
    let fillColor: Color
    let titleColor: Color
    let subtitleColor: Color
    let ringWidth: CGFloat
    let cornerRadius: CGFloat
    let neutralBackgroundColor: Color
    let neutralForegroundColor: Color
    let tintPalette: TintPalette
    let tintedTextColor: Color

    var neutralCapsuleStyle: SurfaceCapsuleStyle {
        SurfaceCapsuleStyle(
            backgroundColor: neutralBackgroundColor,
            iconColor: neutralForegroundColor,
            textColor: neutralForegroundColor,
            horizontalPadding: 12,
            verticalPadding: 8
        )
    }

    var tintCapsuleStyle: SurfaceCapsuleStyle {
        SurfaceCapsuleStyle(
            backgroundColor: tintPalette.background,
            iconColor: tintPalette.icon,
            textColor: tintedTextColor,
            horizontalPadding: 12,
            verticalPadding: 8
        )
    }

    static let light = RingSurfaceStyle(
        stageBackground: Color(white: 0.925),
        ringColor: .white,
        fillColor: Color(white: 0.97),
        titleColor: .black,
        subtitleColor: Color(white: 0.42),
        ringWidth: 3,
        cornerRadius: 16,
        neutralBackgroundColor: .white,
        neutralForegroundColor: .black,
        tintPalette: TintPalette(
            background: Color(red: 1.0, green: 0.85, blue: 0.68),
            icon: .orange
        ), tintedTextColor: .black
    )

    static let dark = RingSurfaceStyle(
        stageBackground: .black,
        ringColor: Color(white: 0.2),
        fillColor: Color(white: 0.06),
        titleColor: Color.white.opacity(0.9),
        subtitleColor: Color(white: 0.62),
        ringWidth: 1,
        cornerRadius: 16,
        neutralBackgroundColor: Color(white: 0.12),
        neutralForegroundColor: Color.white.opacity(0.9),
        tintPalette: TintPalette(
            background: Color(red: 0.78, green: 0.42, blue: 0.11),
            icon: .orange
        ), tintedTextColor: Color.white.opacity(0.9)
    )
}

private struct SurfaceCapsule: View {
    let label: String
    let systemImage: String
    let style: SurfaceCapsuleStyle
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Capsule()
                .fill(style.backgroundColor)
                .overlay {
                    HStack(spacing: 7) {
                        Image(systemName: systemImage)
                            .font(.system(.title3, weight: .bold))
                            .foregroundStyle(style.iconColor)

                        Text(label)
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(style.textColor)
                    }
                    .padding(.horizontal, style.horizontalPadding)
                    .padding(.vertical, style.verticalPadding)
                }
        }
        .buttonStyle(.plain)
    }
}

private struct SurfaceCapsuleStyle {
    let backgroundColor: Color
    let iconColor: Color
    let textColor: Color
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
}

private struct TintPalette {
    let background: Color
    let icon: Color
}

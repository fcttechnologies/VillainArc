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

private struct AppGroupedSurfaceStyle<S: InsettableShape>: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let shape: S
    let fillColor: Color?
    let hidesTopEdge: Bool
    let hidesBottomEdge: Bool
    let showsBottomDivider: Bool
    let dividerInset: CGFloat

    private var resolvedFillColor: Color {
        fillColor ?? (colorScheme == .dark
            ? Color(.sRGB, red: 15.0 / 255.0, green: 15.0 / 255.0, blue: 15.0 / 255.0, opacity: 1)
            : .white)
    }

    private var darkModeRingColor: Color {
        Color(.sRGB, red: 51.0 / 255.0, green: 51.0 / 255.0, blue: 51.0 / 255.0, opacity: 1)
    }

    private var seamInset: CGFloat {
        0.5
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
            .overlay(alignment: .top) {
                if colorScheme == .dark, hidesTopEdge {
                    Rectangle()
                        .fill(resolvedFillColor)
                        .frame(height: 1)
                        .padding(.horizontal, seamInset)
                }
            }
            .overlay(alignment: .bottom) {
                if hidesBottomEdge {
                    ZStack {
                        if colorScheme == .dark {
                            Rectangle()
                                .fill(resolvedFillColor)
                                .frame(height: 1)
                                .padding(.horizontal, seamInset)
                        }

                        if showsBottomDivider {
                            Divider()
                                .padding(.horizontal, dividerInset)
                        }
                    }
                }
            }
            .clipShape(shape)
    }
}

private struct AppListRowChrome: ViewModifier {
    let horizontalInset: CGFloat
    let verticalSpacing: CGFloat

    func body(content: Content) -> some View {
        content
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: verticalSpacing, leading: horizontalInset, bottom: verticalSpacing, trailing: horizontalInset))
    }
}

enum AppGroupedListRowPosition {
    case single
    case top
    case middle
    case bottom

    var defaultShowsDivider: Bool {
        switch self {
        case .single, .bottom:
            return false
        case .top, .middle:
            return true
        }
    }
}

private struct AppGroupedListRowStyle: ViewModifier {
    let position: AppGroupedListRowPosition
    let fillColor: Color?
    let showsDivider: Bool?
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let rowInset: CGFloat
    let rowSpacing: CGFloat
    let cornerRadius: CGFloat
    let alignment: Alignment

    private var resolvedShowsDivider: Bool {
        showsDivider ?? position.defaultShowsDivider
    }

    @ViewBuilder
    private func surface<Content: View>(for content: Content) -> some View {
        switch position {
        case .single:
            content.appGroupedSurfaceStyle(in: UnevenRoundedRectangle(topLeadingRadius: cornerRadius, bottomLeadingRadius: cornerRadius, bottomTrailingRadius: cornerRadius, topTrailingRadius: cornerRadius, style: .continuous), fillColor: fillColor, dividerInset: horizontalPadding)
        case .top:
            content.appGroupedSurfaceStyle(in: UnevenRoundedRectangle(topLeadingRadius: cornerRadius, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: cornerRadius, style: .continuous), fillColor: fillColor, hidesBottomEdge: true, showsBottomDivider: resolvedShowsDivider, dividerInset: horizontalPadding)
        case .middle:
            content.appGroupedSurfaceStyle(in: UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 0, style: .continuous), fillColor: fillColor, hidesTopEdge: true, hidesBottomEdge: true, showsBottomDivider: resolvedShowsDivider, dividerInset: horizontalPadding)
        case .bottom:
            content.appGroupedSurfaceStyle(in: UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: cornerRadius, bottomTrailingRadius: cornerRadius, topTrailingRadius: 0, style: .continuous), fillColor: fillColor, hidesTopEdge: true, dividerInset: horizontalPadding)
        }
    }

    func body(content: Content) -> some View {
        surface(for: content.frame(maxWidth: .infinity, alignment: alignment).padding(.horizontal, horizontalPadding).padding(.vertical, verticalPadding))
        .modifier(AppListRowChrome(horizontalInset: rowInset, verticalSpacing: rowSpacing))
    }
}

private struct AppGroupedStackRowStyle: ViewModifier {
    let position: AppGroupedListRowPosition
    let fillColor: Color?
    let showsDivider: Bool?
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let cornerRadius: CGFloat
    let alignment: Alignment

    private var resolvedShowsDivider: Bool {
        showsDivider ?? position.defaultShowsDivider
    }

    @ViewBuilder
    private func surface<Content: View>(for content: Content) -> some View {
        switch position {
        case .single:
            content.appGroupedSurfaceStyle(in: UnevenRoundedRectangle(topLeadingRadius: cornerRadius, bottomLeadingRadius: cornerRadius, bottomTrailingRadius: cornerRadius, topTrailingRadius: cornerRadius, style: .continuous), fillColor: fillColor, dividerInset: horizontalPadding)
        case .top:
            content.appGroupedSurfaceStyle(in: UnevenRoundedRectangle(topLeadingRadius: cornerRadius, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: cornerRadius, style: .continuous), fillColor: fillColor, hidesBottomEdge: true, showsBottomDivider: resolvedShowsDivider, dividerInset: horizontalPadding)
        case .middle:
            content.appGroupedSurfaceStyle(in: UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 0, style: .continuous), fillColor: fillColor, hidesTopEdge: true, hidesBottomEdge: true, showsBottomDivider: resolvedShowsDivider, dividerInset: horizontalPadding)
        case .bottom:
            content.appGroupedSurfaceStyle(in: UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: cornerRadius, bottomTrailingRadius: cornerRadius, topTrailingRadius: 0, style: .continuous), fillColor: fillColor, hidesTopEdge: true, dividerInset: horizontalPadding)
        }
    }

    func body(content: Content) -> some View {
        surface(for: content.frame(maxWidth: .infinity, alignment: alignment).padding(.horizontal, horizontalPadding).padding(.vertical, verticalPadding))
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

    func appGroupedSurfaceStyle<S: InsettableShape>(in shape: S, fillColor: Color? = nil, hidesTopEdge: Bool = false, hidesBottomEdge: Bool = false, showsBottomDivider: Bool = false, dividerInset: CGFloat = 16) -> some View {
        modifier(AppGroupedSurfaceStyle(shape: shape, fillColor: fillColor, hidesTopEdge: hidesTopEdge, hidesBottomEdge: hidesBottomEdge, showsBottomDivider: showsBottomDivider, dividerInset: dividerInset))
    }

    func appGroupedListRow(position: AppGroupedListRowPosition, fillColor: Color? = nil, showsDivider: Bool? = nil, horizontalPadding: CGFloat = 17, verticalPadding: CGFloat = 17, rowInset: CGFloat = 8, rowSpacing: CGFloat = 0, cornerRadius: CGFloat = 22, alignment: Alignment = .leading) -> some View {
        modifier(AppGroupedListRowStyle(position: position, fillColor: fillColor, showsDivider: showsDivider, horizontalPadding: horizontalPadding, verticalPadding: verticalPadding, rowInset: rowInset, rowSpacing: rowSpacing, cornerRadius: cornerRadius, alignment: alignment))
    }

    func appGroupedStackRow(position: AppGroupedListRowPosition, fillColor: Color? = nil, showsDivider: Bool? = nil, horizontalPadding: CGFloat = 17, verticalPadding: CGFloat = 17, cornerRadius: CGFloat = 22, alignment: Alignment = .leading) -> some View {
        modifier(AppGroupedStackRowStyle(position: position, fillColor: fillColor, showsDivider: showsDivider, horizontalPadding: horizontalPadding, verticalPadding: verticalPadding, cornerRadius: cornerRadius, alignment: alignment))
    }
}

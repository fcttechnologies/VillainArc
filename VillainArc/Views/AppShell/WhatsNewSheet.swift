import FCTMetrics
import SwiftUI

// What's New sheet: the highlights of every release this user hasn't seen yet.
// What to present is decided by WhatsNewPreferences.presentationOnLaunch; this
// view only renders it. Feature/release/catalog types live in WhatsNewCatalog.swift.
struct WhatsNewSheet: View {
    let presentation: WhatsNewPresentation
    let onDismiss: () -> Void
    /// The icon column tracks the title beside it, so at an accessibility size the row still reads
    /// as an icon and a heading rather than a stamp-sized tile next to very large text.
    @ScaledMetric(relativeTo: .title3) private var iconTileSize: CGFloat = 60
    @ScaledMetric(relativeTo: .title3) private var iconGlyphSize: CGFloat = 30

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    header
                    featuresSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollContentBackground(.hidden)
            .sheetBackground()
            .navigationTitle("What's New")
            .toolbarTitleDisplayMode(.inlineLarge)
            .safeAreaBar(edge: .bottom) {
                continueBar
            }
            .accessibilityIdentifier("whats_new_sheet")
        }
        .diagScreen(VACrumb.whatsNew)
    }

    private var header: some View {
        Text("Version \(presentation.version)")
            .font(.headline.weight(.semibold))
            .foregroundStyle(.secondary)
            .fontDesign(.rounded)
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 28) {
            ForEach(presentation.features) { feature in
                featureRow(feature)
            }
        }
    }

    private func featureRow(_ feature: WhatsNewFeature) -> some View {
        HStack(alignment: .center, spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(feature.iconColor.opacity(0.15))
                    .frame(width: iconTileSize, height: iconTileSize)
                Image(systemName: feature.icon)
                    .font(.system(size: iconGlyphSize))
                    .foregroundStyle(feature.iconColor)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(feature.title)
                    .font(.title3.weight(.semibold))
                    .fontDesign(.rounded)
                Text(feature.description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var continueBar: some View {
        Button {
            onDismiss()
        } label: {
            Text("Continue")
                .fontWeight(.semibold)
                .font(.title3)
                .padding(.vertical, 5)
        }
        .buttonStyle(.glassProminent)
        .buttonSizing(.flexible)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .accessibilityIdentifier("whats_new_continue_button")
        .accessibilityHint(Text("Closes the What's New sheet and continues to the app."))
    }
}

#Preview("What's New") {
    WhatsNewSheet(presentation: WhatsNewPresentation(version: "1.4", features: WhatsNewCatalog.releases.first?.features ?? [])) {}
        .presentationBackground(Color.sheetBg)
}

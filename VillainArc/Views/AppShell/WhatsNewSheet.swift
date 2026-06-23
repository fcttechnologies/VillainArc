import SwiftUI

// Welcome / What's New sheet. The presentation (welcome vs whatsNew + its features)
// is decided by WhatsNewPreferences.presentationOnLaunch; this view only renders it.
// Feature/release/catalog types live in WhatsNewCatalog.swift.
struct WhatsNewSheet: View {
    let presentation: WhatsNewPresentation
    let onDismiss: () -> Void

    private var isWelcome: Bool {
        presentation.kind == .welcome
    }

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
            .navigationTitle(isWelcome ? "Welcome to Villain Arc" : "What's New")
            .toolbarTitleDisplayMode(.inlineLarge)
            .safeAreaBar(edge: .bottom) {
                continueBar
            }
            .accessibilityIdentifier("whats_new_sheet")
        }
    }

    @ViewBuilder
    private var header: some View {
        switch presentation.kind {
        case .welcome:
            Text("Here's what you can do.")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)
                .fontDesign(.rounded)
        case .whatsNew(let version):
            Text("Version \(version)")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)
                .fontDesign(.rounded)
        }
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
                    .frame(width: 60, height: 60)
                Image(systemName: feature.icon)
                    .font(.system(size: 30))
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
            Text(isWelcome ? "Get Started" : "Continue")
                .fontWeight(.semibold)
                .font(.title3)
                .padding(.vertical, 5)
        }
        .buttonStyle(.glassProminent)
        .buttonSizing(.flexible)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .accessibilityIdentifier("whats_new_continue_button")
        .accessibilityHint(Text(isWelcome ? "Closes the welcome screen and enters the app." : "Closes the What's New sheet and continues to the app."))
    }
}

#Preview("Welcome") {
    WhatsNewSheet(presentation: WhatsNewPresentation(kind: .welcome, features: WhatsNewCatalog.welcomeHighlights)) {}
        .presentationBackground(Color.sheetBg)
}

#Preview("What's New") {
    WhatsNewSheet(presentation: WhatsNewPresentation(kind: .whatsNew(version: "1.4"), features: WhatsNewCatalog.releases.first?.features ?? [])) {}
        .presentationBackground(Color.sheetBg)
}

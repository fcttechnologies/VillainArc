import SwiftUI

struct WhatsNewFeature: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let title: LocalizedStringResource
    let description: LocalizedStringResource
}

struct WhatsNewSheet: View {
    let version: String
    let onDismiss: () -> Void

    private let features: [WhatsNewFeature] = [
        WhatsNewFeature(icon: "figure.run.treadmill", iconColor: .orange, title: "Cardio with Routes", description: "Run, walk, or treadmill, mapped live."),
        WhatsNewFeature(icon: "sparkles", iconColor: .yellow, title: "AI Plan Generation", description: "Build a full program from a sentence. (Pro)"),
        WhatsNewFeature(icon: "arrow.triangle.2.circlepath", iconColor: .blue, title: "AI Exercise Swaps", description: "Smart replacements for your goal and level. (Pro)"),
        WhatsNewFeature(icon: "chart.xyaxis.line", iconColor: .pink, title: "Health Insights", description: "Trends, sleep timing, and correlations. (Pro)"),
        WhatsNewFeature(icon: "drop.fill", iconColor: .cyan, title: "Hydration Tracking", description: "Log water and hit a daily goal."),
        WhatsNewFeature(icon: "person.crop.circle.fill", iconColor: .indigo, title: "Profile & Streaks", description: "Stats, muscle map, and a complete-day heatmap.")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    versionHeader
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
    }

    private var versionHeader: some View {
        Text("Version \(version)")
            .font(.headline.weight(.semibold))
            .foregroundStyle(.secondary)
            .fontDesign(.rounded)
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 28) {
            ForEach(features) { feature in
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

#Preview {
    WhatsNewSheet(version: "1.3") {}
        .presentationBackground(Color.sheetBg)
}

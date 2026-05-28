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
        WhatsNewFeature(icon: "figure.run.treadmill", iconColor: .orange, title: "Cardio Sessions", description: "Track outdoor runs and walks with route maps, log treadmill intervals, and follow it live on the Lock Screen."),
        WhatsNewFeature(icon: "heart.text.square.fill", iconColor: .red, title: "Pre-Workout Check-In", description: "Log how you're feeling before each session and bring last night's sleep and resting heart rate along."),
        WhatsNewFeature(icon: "timer.circle.fill", iconColor: .blue, title: "Rest Timer Redesign", description: "A circular countdown with skip, extend, and pause controls always within reach."),
        WhatsNewFeature(icon: "line.3.horizontal.decrease.circle.fill", iconColor: .purple, title: "Smarter Exercise Picker", description: "Today's split surfaces relevant exercises first when you add or replace, with muscle and equipment matches up top."),
        WhatsNewFeature(icon: "sparkles", iconColor: .yellow, title: "Workout Outcome & Patterns", description: "Rate how each session went and watch Villain Arc highlight what's making your best workouts click.")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    versionHeader
                    featuresSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollContentBackground(.hidden)
            .sheetBackground()
            .navigationTitle("What's New")
            .toolbarTitleDisplayMode(.inlineLarge)
            .safeAreaInset(edge: .bottom) {
                continueBar
            }
            .accessibilityIdentifier("whats_new_sheet")
        }
    }

    private var versionHeader: some View {
        Text("Version \(version)")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .fontDesign(.rounded)
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(features) { feature in
                featureRow(feature)
            }
        }
    }

    private func featureRow(_ feature: WhatsNewFeature) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(feature.iconColor.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: feature.icon)
                    .font(.system(size: 22))
                    .foregroundStyle(feature.iconColor)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(feature.title)
                    .font(.headline)
                    .fontDesign(.rounded)
                Text(feature.description)
                    .font(.subheadline)
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
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .accessibilityIdentifier("whats_new_continue_button")
        .accessibilityHint(Text("Closes the What's New sheet and continues to the app."))
    }
}

#Preview {
    WhatsNewSheet(version: "1.3") {}
        .presentationBackground(Color.sheetBg)
}

import SwiftUI

struct WhatsNewFeature: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
}

struct WhatsNewSheet: View {
    let version: String
    let onDismiss: () -> Void

    private let features: [WhatsNewFeature] = [
        WhatsNewFeature(icon: "figure.run.treadmill", iconColor: .orange, title: "Cardio Sessions", description: "Track outdoor runs, walks, and treadmill sessions with route maps and interval data."),
        WhatsNewFeature(icon: "chart.line.uptrend.xyaxis", iconColor: .blue, title: "Progression Charts", description: "View your 1RM, max weight, reps, and volume history with rich per-exercise charts."),
        WhatsNewFeature(icon: "drop.fill", iconColor: .cyan, title: "Hydration Tracking", description: "Log daily water intake and set hydration goals synced with Apple Health."),
        WhatsNewFeature(icon: "waveform.path.ecg", iconColor: .red, title: "Heart & Health Vitals", description: "Monitor resting heart rate, HRV, respiratory rate, and wrist temperature trends."),
        WhatsNewFeature(icon: "lightbulb.fill", iconColor: .yellow, title: "Smart Suggestions", description: "Villain Arc analyzes your logs and suggests load or rep adjustments to keep you progressing.")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    headerSection
                    featuresSection
                    Spacer(minLength: 16)
                    continueButton
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)
                .padding(.bottom, 24)
            }
            .scrollContentBackground(.hidden)
            .sheetBackground()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onDismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What's New")
                .font(.largeTitle)
                .bold()
                .fontDesign(.rounded)
            Text("Version \(version)")
                .font(.headline)
                .foregroundStyle(.secondary)
                .fontDesign(.rounded)
        }
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
    }

    private var continueButton: some View {
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
    }
}

#Preview {
    WhatsNewSheet(version: "1.3") {}
        .presentationBackground(Color.sheetBg)
}

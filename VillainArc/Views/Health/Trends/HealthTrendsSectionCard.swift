import SwiftUI

struct HealthTrendsSectionCard: View {
    let router = AppRouter.shared

    var body: some View {
        Button {
            router.push(to: .healthTrends)
            Task { await IntentDonations.donateShowHealthTrends() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title3)
                    .foregroundStyle(.teal.gradient)
                    .frame(width: 36, height: 36)
                    .background(Color.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Trends")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text("Weight, sleep, energy, steps, volume")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .appCardStyle()
            .tint(.primary)
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier(AccessibilityIdentifiers.healthTrendsSectionCard)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Trends. Weight, sleep, energy, steps, and workout volume."))
        .accessibilityHint(Text("Opens trends view"))
    }
}

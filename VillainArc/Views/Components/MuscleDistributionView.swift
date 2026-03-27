import SwiftUI
import Charts

struct MuscleDistributionView: View {
    let slices: [MuscleDistributionSlice]

    private var topSlice: MuscleDistributionSlice? {
        slices.first
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            chartColumn

            legendColumn
        }
    }

    private var chartColumn: some View {
        ZStack {
            Chart(slices) { slice in
                SectorMark(angle: .value("Percentage", slice.percentage), innerRadius: .ratio(0.64), angularInset: 3)
                    .cornerRadius(8)
                    .foregroundStyle(slice.muscle.distributionColor)
            }
            .chartLegend(.hidden)
            .chartBackground { _ in
                Color.clear
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Muscle distribution chart")
            .accessibilityValue(chartAccessibilityValue)

            VStack(spacing: 2) {
                Text(topSlice?.muscle.displayName ?? "")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .fontWeight(.semibold)

                Text(percentageText(for: topSlice?.percentage ?? 0))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 18)
            .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
    }

    private var legendColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(slices) { slice in
                HStack(spacing: 12) {
                    Circle()
                        .fill(slice.muscle.distributionColor)
                        .frame(width: 12, height: 12)
                        .accessibilityHidden(true)

                    Text(slice.muscle.displayName)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Spacer()

                    Text(percentageText(for: slice.percentage))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .fontWeight(.semibold)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(slice.muscle.displayName)
                .accessibilityValue(percentageText(for: slice.percentage))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var chartAccessibilityValue: String {
        slices
            .map { "\($0.muscle.displayName) \(percentageText(for: $0.percentage))" }
            .joined(separator: ", ")
    }

    private func percentageText(for percentage: Double) -> String {
        (percentage / 100).formatted(.percent.precision(.fractionLength(0)))
    }
}

private extension Muscle {
    var distributionColor: Color {
        switch self {
        case .chest:
            return .pink
        case .back:
            return .teal
        case .shoulders:
            return .orange
        case .biceps:
            return .blue
        case .triceps:
            return .indigo
        case .abs:
            return .mint
        case .glutes:
            return .purple
        case .quads:
            return .yellow
        case .hamstrings:
            return .brown
        case .calves:
            return .cyan
        case .forearms:
            return .blue
        case .adductors:
            return .yellow
        case .abductors:
            return .purple
        case .upperChest, .lowerChest, .midChest:
            return .pink
        case .lats, .lowerBack, .upperTraps, .lowerTraps, .midTraps, .rhomboids:
            return .teal
        case .frontDelt, .sideDelt, .rearDelt, .rotatorCuff:
            return .orange
        case .longHeadBiceps, .shortHeadBiceps, .brachialis, .wrists:
            return .blue
        case .longHeadTriceps, .lateralHeadTriceps, .medialHeadTriceps:
            return .indigo
        case .upperAbs, .lowerAbs, .obliques:
            return .mint
        }
    }
}

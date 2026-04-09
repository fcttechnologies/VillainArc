import SwiftUI
import Charts

struct MuscleDistributionView: View {
    let slices: [MuscleDistributionSlice]

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            chartColumn

            legendColumn
        }
    }

    private var chartColumn: some View {
        Chart(slices) { slice in
            SectorMark(angle: .value("Percentage", slice.percentage), innerRadius: .ratio(0.64), angularInset: 3)
                .cornerRadius(8)
                .foregroundStyle(slice.muscle.distributionColor)
        }
        .chartLegend(.hidden)
        .chartBackground { _ in
            Color.clear
        }
        .accessibilityIdentifier(AccessibilityIdentifiers.muscleDistributionChart)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AccessibilityText.muscleDistributionChartLabel)
        .accessibilityValue(chartAccessibilityValue)
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
                        .foregroundStyle(.secondary)
                }
                .fontWeight(.semibold)
                .accessibilityIdentifier(AccessibilityIdentifiers.muscleDistributionLegendRow(slice.muscle))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(slice.muscle.displayName)
                .accessibilityValue(AccessibilityText.muscleDistributionLegendRowValue(muscleName: slice.muscle.displayName, percentageText: percentageText(for: slice.percentage)))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var chartAccessibilityValue: String {
        AccessibilityText.muscleDistributionChartValue(rows: slices.map { AccessibilityText.muscleDistributionLegendRowValue(muscleName: $0.muscle.displayName, percentageText: percentageText(for: $0.percentage)) })
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

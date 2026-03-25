import SwiftUI
import SwiftData

struct WeightGoalHistoryView: View {
    @Query(WeightGoal.history) private var goals: [WeightGoal]

    let weightUnit: WeightUnit

    @State private var showNewWeightGoalSheet = false

    var body: some View {
        List {
            ForEach(goals) { goal in
                WeightGoalHistoryRowView(goal: goal, weightUnit: weightUnit)
                    .accessibilityIdentifier(AccessibilityIdentifiers.healthWeightGoalRow(goal))
                    .accessibilityHint(AccessibilityText.healthWeightGoalRowHint)
            }
        }
        .accessibilityIdentifier(AccessibilityIdentifiers.healthWeightGoalHistoryList)
        .navigationTitle("Weight Goals")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Haptics.selection()
                    showNewWeightGoalSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title3)
                }
                .accessibilityLabel(AccessibilityText.healthWeightGoalHistoryAddLabel)
                .accessibilityIdentifier(AccessibilityIdentifiers.healthWeightGoalHistoryAddButton)
                .accessibilityHint(AccessibilityText.healthWeightGoalHistoryAddHint)
            }
        }
        .sheet(isPresented: $showNewWeightGoalSheet) {
            NewWeightGoalView(weightUnit: weightUnit)
                .presentationDetents([.fraction(0.7), .large])
                .presentationBackground(Color(.systemBackground))
        }
        .overlay {
            if goals.isEmpty {
                ContentUnavailableView("No Weight Goals", systemImage: "target", description: Text("Your saved and previous weight goals will appear here."))
            }
        }
    }
}

private struct WeightGoalHistoryRowView: View {
    let goal: WeightGoal
    let weightUnit: WeightUnit

    private var isActive: Bool {
        goal.endedAt == nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(goal.type.title)
                    .font(.headline)

                if isActive {
                    Text("Active")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.green.opacity(0.15), in: Capsule())
                }

                Spacer()

                Text(formattedWeightText(goal.targetWeight, unit: weightUnit))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

            Text("Started \(formattedRecentDay(goal.startedAt))")
                .foregroundStyle(.secondary)

            if let endedAt = goal.endedAt {
                Text("Ended \(formattedRecentDay(endedAt))")
                    .foregroundStyle(.secondary)
            }

            if let targetDate = goal.targetDate {
                Text("Target Date \(formattedRecentDay(targetDate))")
                    .foregroundStyle(.secondary)
            }

            if let targetRatePerWeek = goal.targetRatePerWeek {
                Text("Target Pace \(formattedWeightValue(targetRatePerWeek, unit: weightUnit, fractionDigits: 0...1)) \(weightUnit.rawValue)/wk")
                    .foregroundStyle(.secondary)
            }
        }
        .fontWeight(.semibold)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityLabel: String {
        "\(goal.type.title) weight goal"
    }

    private var accessibilityValue: String {
        var parts = [
            "Target \(formattedWeightText(goal.targetWeight, unit: weightUnit))",
            "Started \(formattedRecentDay(goal.startedAt))"
        ]

        if let endedAt = goal.endedAt {
            parts.append("Ended \(formattedRecentDay(endedAt))")
        } else {
            parts.append("Active")
        }

        if let targetDate = goal.targetDate {
            parts.append("Target date \(formattedRecentDay(targetDate))")
        }

        return parts.joined(separator: ", ")
    }
}

#Preview {
    NavigationStack {
        WeightGoalHistoryView(weightUnit: .lbs)
    }
    .sampleDataContainer()
}

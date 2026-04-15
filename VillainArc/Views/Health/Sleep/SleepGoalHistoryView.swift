import SwiftData
import SwiftUI

struct SleepGoalHistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(SleepGoal.history) private var goals: [SleepGoal]
    @State private var router = AppRouter.shared

    var body: some View {
        List {
            ForEach(goals) { goal in
                SleepGoalHistoryRow(goal: goal)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            deleteGoal(goal)
                        }
                    }
            }
        }
        .contentMargins(.bottom, quickActionContentBottomMargin, for: .scrollContent)
        .navigationTitle("Sleep Goals")
        .toolbarTitleDisplayMode(.inline)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .appBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.presentHealthSheet(.newSleepGoal)
                } label: {
                    Image(systemName: "plus")
                        .font(.title3)
                }
                .accessibilityLabel(AccessibilityText.healthSleepGoalHistoryAddLabel)
                .accessibilityIdentifier(AccessibilityIdentifiers.healthSleepGoalHistoryAddButton)
                .accessibilityHint(AccessibilityText.healthSleepGoalHistoryAddHint)
            }
        }
        .overlay {
            if goals.isEmpty {
                ContentUnavailableView("No Sleep Goals", systemImage: "target", description: Text("Your saved and previous sleep goals will appear here."))
            }
        }
    }

    private func deleteGoal(_ goal: SleepGoal) {
        Haptics.selection()
        context.delete(goal)
        saveContext(context: context)
        HealthMetricWidgetReloader.reloadSleep()
    }
}

private struct SleepGoalHistoryRow: View {
    let goal: SleepGoal

    private var isActive: Bool {
        goal.endedOnDay == nil
    }

    private var periodText: String {
        if let endedOnDay = goal.endedOnDay {
            return "\(formattedRecentDay(goal.startedOnDay)) - \(formattedRecentDay(endedOnDay))"
        }
        return String(localized: "Started \(formattedRecentDay(goal.startedOnDay))")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(formattedSleepDurationText(goal.targetSleepDuration))
                            .font(.headline)
                            .fontWeight(.bold)
                            .fontDesign(.rounded)

                        Text(isActive ? String(localized: "Active") : String(localized: "Ended"))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background((isActive ? Color.green : Color.secondary).gradient, in: Capsule())
                            .foregroundStyle(.white)
                    }

                    Text(periodText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fontWeight(.semibold)
                }

                Spacer()
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12, alignment: .top)], spacing: 12) {
                SummaryStatCard(title: String(localized: "Target Sleep"), text: formattedSleepDurationText(goal.targetSleepDuration), usesSubStyle: true)
                if let endedOnDay = goal.endedOnDay {
                    SummaryStatCard(title: String(localized: "Ended"), text: formattedRecentDay(endedOnDay), usesSubStyle: true)
                }
            }
        }
        .padding(16)
        .appCardStyle()
    }
}

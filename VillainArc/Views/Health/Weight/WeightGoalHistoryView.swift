import SwiftUI
import SwiftData

struct WeightGoalHistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(WeightGoal.history) private var goals: [WeightGoal]
    @Query(WeightEntry.history) private var entries: [WeightEntry]
    @Query(AppSettings.single) private var appSettings: [AppSettings]
    @State private var router = AppRouter.shared

    @State private var showNewWeightGoalSheet = false

    private var weightUnit: WeightUnit {
        appSettings.first?.weightUnit ?? .systemDefault
    }

    var body: some View {
        List {
            ForEach(goals) { goal in
                WeightGoalHistoryRowView(goal: goal, entries: entries, weightUnit: weightUnit)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier(AccessibilityIdentifiers.healthWeightGoalRow(goal))
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        if goal.endedAt == nil {
                            Button("Complete", systemImage: "checkmark.circle") {
                                Haptics.selection()
                                router.presentWeightGoalCompletion(for: goal, trigger: .manualCompletion)
                            }
                            .tint(.blue)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            deleteGoal(goal)
                        }
                    }
            }
        }
        .accessibilityIdentifier(AccessibilityIdentifiers.healthWeightGoalHistoryList)
        .navigationTitle("Weight Goals")
        .toolbarTitleDisplayMode(.inline)
        .listStyle(.plain)
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

    private func deleteGoal(_ goal: WeightGoal) {
        Haptics.selection()
        context.delete(goal)
        saveContext(context: context)
        HealthMetricWidgetReloader.reloadWeight()
    }
}

private struct WeightGoalHistoryRowView: View {
    let goal: WeightGoal
    let entries: [WeightEntry]
    let weightUnit: WeightUnit

    private var isActive: Bool {
        goal.endedAt == nil
    }
    
    private var progressModel: WeightGoalProgressChartModel? {
        WeightGoalProgressChartModel(goal: goal, entries: entries, now: goal.endedAt ?? .now)
    }
    
    private var latestGoalWeight: Double? {
        progressModel?.latestPoint?.value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(goalTitle)
                            .font(.headline)
                            .fontWeight(.bold)
                            .fontDesign(.rounded)

                        Text(goalStatusBadgeTitle)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(goalStatusBadgeColor.gradient, in: Capsule())
                            .foregroundStyle(.white)
                    }

                    Text(periodText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fontWeight(.semibold)
                }

                Spacer(minLength: 12)
                
                if let progressModel {
                    WeightGoalProgressChart(model: progressModel, weightUnit: weightUnit)
                        .frame(width: 180, height: 90)
                        .accessibilityHidden(true)
                }
            }

            Divider()

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12, alignment: .top)], spacing: 12) {
                SummaryStatCard(title: "Starting Weight", text: formattedWeightText(goal.startWeight, unit: weightUnit))
                SummaryStatCard(title: "Target Weight", text: formattedWeightText(goal.targetWeight, unit: weightUnit))
                
                if let latestGoalWeight {
                    SummaryStatCard(title: "Progress", text: weightGoalProgressText(goal: goal, currentWeight: latestGoalWeight, unit: weightUnit))
                }

                if let targetDate = goal.targetDate {
                    SummaryStatCard(title: "Target Date", text: formattedRecentDay(targetDate))
                }

                if let targetRatePerWeek = goal.targetRatePerWeek, goal.type != .maintain {
                    SummaryStatCard(title: "Target Pace", text: "\(formattedWeightValue(targetRatePerWeek, unit: weightUnit, fractionDigits: 0...1)) \(weightUnit.rawValue)/wk")
                }

                if let endedAt = goal.endedAt {
                    SummaryStatCard(title: "Ended", text: formattedRecentDay(endedAt))
                }
            }
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AccessibilityText.healthWeightGoalRowLabel(typeTitle: goal.type.title))
        .accessibilityValue(accessibilityValue)
    }

    private var goalTitle: String {
        if goal.type == .maintain {
            return "Maintain Goal"
        }

        return "\(goal.type.title) Goal"
    }
    
    private var goalStatusBadgeTitle: String {
        if isActive { return "Active" }
        
        switch goal.endReason {
        case .achieved:
            return "Completed"
        case .manualOverride:
            return "Ended Early"
        case .replaced:
            return "Replaced"
        case nil:
            return "Ended"
        }
    }
    
    private var goalStatusBadgeColor: Color {
        if isActive { return .green }
        
        switch goal.endReason {
        case .achieved:
            return .blue
        case .manualOverride:
            return .purple
        case .replaced:
            return .orange
        case nil:
            return .secondary
        }
    }

    private var periodText: String {
        if let endedAt = goal.endedAt {
            return "\(formattedRecentDay(goal.startedAt))- \(formattedRecentDay(endedAt))"
        }

        return "Started \(formattedRecentDay(goal.startedAt))"
    }

    private var accessibilityValue: String {
        AccessibilityText.healthWeightGoalRowValue(targetText: formattedWeightText(goal.targetWeight, unit: weightUnit), startedText: formattedRecentDay(goal.startedAt), endedText: goal.endedAt.map(formattedRecentDay), targetDateText: goal.targetDate.map(formattedRecentDay), progressText: latestGoalWeight.map { weightGoalProgressText(goal: goal, currentWeight: $0, unit: weightUnit) }, chartSummary: progressModel?.accessibilitySummary(unit: weightUnit), isActive: isActive)
    }
}

#Preview {
    NavigationStack {
        WeightGoalHistoryView()
    }
    .sampleDataContainer()
}

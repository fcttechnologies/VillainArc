import SwiftUI
import SwiftData

struct WeightGoalHistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(WeightGoal.history) private var goals: [WeightGoal]
    @Query(WeightEntry.history) private var entries: [WeightEntry]
    @Query(AppSettings.single) private var appSettings: [AppSettings]
    @State private var router = AppRouter.shared

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
        .contentMargins(.bottom, quickActionContentBottomMargin, for: .scrollContent)
        .accessibilityIdentifier(AccessibilityIdentifiers.healthWeightGoalHistoryList)
        .navigationTitle("Weight Goals")
        .toolbarTitleDisplayMode(.inline)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .appBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.presentHealthSheet(.newWeightGoal)
                } label: {
                    Image(systemName: "plus")
                        .font(.title3)
                }
                .accessibilityLabel(AccessibilityText.healthWeightGoalHistoryAddLabel)
                .accessibilityIdentifier(AccessibilityIdentifiers.healthWeightGoalHistoryAddButton)
                .accessibilityHint(AccessibilityText.healthWeightGoalHistoryAddHint)
            }
        }
        .sheet(isPresented: newWeightGoalSheetBinding) {
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

    private var newWeightGoalSheetBinding: Binding<Bool> {
        Binding(
            get: { router.activeHealthSheet == .newWeightGoal },
            set: { isPresented in
                if !isPresented, router.activeHealthSheet == .newWeightGoal {
                    router.activeHealthSheet = nil
                }
            }
        )
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
        VStack(alignment: .leading, spacing: 10) {
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

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12, alignment: .top)], spacing: 12) {
                SummaryStatCard(title: String(localized: "Starting Weight"), text: formattedWeightText(goal.startWeight, unit: weightUnit), usesSubStyle: true)
                SummaryStatCard(title: String(localized: "Target Weight"), text: formattedWeightText(goal.targetWeight, unit: weightUnit), usesSubStyle: true)
                
                if let latestGoalWeight {
                    SummaryStatCard(title: String(localized: "Progress"), text: weightGoalProgressText(goal: goal, currentWeight: latestGoalWeight, unit: weightUnit), usesSubStyle: true)
                }

                if let targetDate = goal.targetDate {
                    SummaryStatCard(title: String(localized: "Target Date"), text: formattedRecentDay(targetDate), usesSubStyle: true)
                }

                if let targetRatePerWeek = goal.targetRatePerWeek, goal.type != .maintain {
                    SummaryStatCard(title: String(localized: "Target Pace"), text: formattedWeightPerWeekText(targetRatePerWeek, unit: weightUnit, fractionDigits: 0...1), usesSubStyle: true)
                }

                if let endedAt = goal.endedAt {
                    SummaryStatCard(title: String(localized: "Ended"), text: formattedRecentDay(endedAt), usesSubStyle: true)
                }
            }
        }
        .padding(16)
        .appCardStyle()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AccessibilityText.healthWeightGoalRowLabel(typeTitle: goal.type.title))
        .accessibilityValue(accessibilityValue)
    }

    private var goalTitle: String {
        if goal.type == .maintain {
            return String(localized: "Maintain Goal")
        }

        return String(localized: "\(goal.type.title) Goal")
    }
    
    private var goalStatusBadgeTitle: String {
        if isActive { return String(localized: "Active") }
        
        switch goal.endReason {
        case .achieved:
            return String(localized: "Completed")
        case .manualOverride:
            return String(localized: "Ended Early")
        case .replaced:
            return String(localized: "Replaced")
        case nil:
            return String(localized: "Ended")
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

        return String(localized: "Started \(formattedRecentDay(goal.startedAt))")
    }

    private var accessibilityValue: String {
        AccessibilityText.healthWeightGoalRowValue(targetText: formattedWeightText(goal.targetWeight, unit: weightUnit), startedText: formattedRecentDay(goal.startedAt), endedText: goal.endedAt.map(formattedRecentDay), targetDateText: goal.targetDate.map(formattedRecentDay), progressText: latestGoalWeight.map { weightGoalProgressText(goal: goal, currentWeight: $0, unit: weightUnit) }, chartSummary: progressModel?.accessibilitySummary(unit: weightUnit), isActive: isActive)
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        WeightGoalHistoryView()
    }
}

import SwiftUI
import SwiftData

struct HydrationGoalSummaryCard: View {
    let activeGoal: HydrationGoal?
    let todayTotal: HydrationDailyTotal?
    let hasGoalHistory: Bool
    let hydrationUnit: HydrationUnit
    let action: () -> Void

    private var titleText: String {
        guard let activeGoal else { return String(localized: "No active goal") }
        let converted = hydrationUnit.fromML(activeGoal.targetML)
        let formatted = hydrationUnit == .ml ? Int(converted.rounded()).formatted(.number) : converted.formatted(.number.precision(.fractionLength(0...1)))
        return "\(formatted) \(hydrationUnit.unitLabel)"
    }

    private var subtitleText: String? {
        guard let activeGoal, let todayTotal else { return nil }
        let remaining = max(activeGoal.targetML - todayTotal.totalVolume, 0)
        if remaining == 0 {
            return String(localized: "Goal reached today")
        }
        let converted = hydrationUnit.fromML(remaining)
        let formatted = hydrationUnit == .ml ? Int(converted.rounded()).formatted(.number) : converted.formatted(.number.precision(.fractionLength(0...1)))
        return "\(formatted) \(hydrationUnit.unitLabel) left today"
    }

    private var emptyStateText: String {
        hasGoalHistory ? String(localized: "Tap to view your goal history.") : String(localized: "Tap to create a hydration goal.")
    }

    var body: some View {
        Button(action: action) {
            Group {
                if activeGoal != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "target")
                                .font(.subheadline)
                            Text("Hydration Goal")
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.secondary)

                        Text(titleText)
                            .font(.title3)
                            .fontWeight(.bold)
                            .fontDesign(.rounded)

                        if let subtitleText {
                            Text(subtitleText)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "target")
                                .font(.subheadline)
                            Text("Hydration Goal")
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.secondary)

                        Text("No active goal")
                            .font(.title3)
                            .bold()
                            .fontDesign(.rounded)

                        Text(emptyStateText)
                            .foregroundStyle(.secondary)
                            .fontWeight(.semibold)
                    }
                }
            }
            .padding(4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.roundedRectangle(radius: 12))
        .accessibilityIdentifier(AccessibilityIdentifiers.healthHydrationGoalSummaryButton)
    }
}

struct HydrationGoalHistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(HydrationGoal.history) private var goals: [HydrationGoal]
    @Query(HydrationEntry.history, animation: .smooth) private var entries: [HydrationEntry]
    @Query(AppSettings.single) private var appSettings: [AppSettings]
    @State private var router = AppRouter.shared

    private var hydrationUnit: HydrationUnit { appSettings.first?.hydrationUnit ?? .systemDefault }

    var body: some View {
        List {
            ForEach(goals) { goal in
                HydrationGoalHistoryRow(goal: goal, entries: entries, hydrationUnit: hydrationUnit)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            deleteGoal(goal)
                        }
                        .accessibilityIdentifier(AccessibilityIdentifiers.healthHydrationGoalDeleteButton(goal))
                    }
            }
        }
        .quickActionContentBottomInset()
        .navigationTitle("Hydration Goals")
        .toolbarTitleDisplayMode(.inline)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .appBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.presentHealthSheet(.newHydrationGoal)
                } label: {
                    Image(systemName: "plus")
                        .font(.title3)
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.healthHydrationGoalHistoryAddButton)
            }
        }
        .overlay {
            if goals.isEmpty {
                ContentUnavailableView("No Hydration Goals", systemImage: "target", description: Text("Your saved and previous hydration goals will appear here."))
            }
        }
    }

    private func deleteGoal(_ goal: HydrationGoal) {
        Haptics.selection()
        context.delete(goal)
        try? HydrationDay.reconcileAll(context: context)
        saveContext(context: context)
        HealthMetricWidgetReloader.reloadHydration()
    }
}

private struct HydrationGoalHistoryRow: View {
    let goal: HydrationGoal
    let entries: [HydrationEntry]
    let hydrationUnit: HydrationUnit

    private var isActive: Bool { goal.endedOnDay == nil }

    private var achievedDays: Int {
        let dailyTotals = HydrationEntry.dailyTotals(from: entries, goalML: goal.targetML)
        return dailyTotals.filter { $0.goalProgress >= 1.0 && goal.contains(day: $0.date) }.count
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
                        Text(hydrationUnit.display(goal.targetML, fractionDigits: 0...1))
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
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12, alignment: .top)], spacing: 12) {
                SummaryStatCard(title: String(localized: "Target"), text: hydrationUnit.display(goal.targetML, fractionDigits: 0...1), usesSubStyle: true)
                SummaryStatCard(title: String(localized: "Achieved Days"), text: achievedDays.formatted(.number), usesSubStyle: true)
            }
        }
        .padding(16)
        .appCardStyle()
    }

    private var goalStatusBadgeTitle: String {
        isActive ? String(localized: "Active") : String(localized: "Ended")
    }

    private var goalStatusBadgeColor: Color {
        isActive ? .green : .secondary
    }
}

struct NewHydrationGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(HydrationEntry.last7Days()) private var summaryEntries: [HydrationEntry]
    @Query(HydrationGoal.active) private var activeGoals: [HydrationGoal]
    @Query(AppSettings.single) private var appSettings: [AppSettings]
    @FocusState private var isFieldFocused: Bool

    @State private var targetText = ""

    private var hydrationUnit: HydrationUnit { appSettings.first?.hydrationUnit ?? .systemDefault }

    private var parsedTargetML: Double? {
        let trimmed = targetText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let formatter = NumberFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.numberStyle = .decimal
        guard let value = formatter.number(from: trimmed)?.doubleValue else { return nil }
        return hydrationUnit.toML(value)
    }

    private var canSave: Bool {
        guard let parsedTargetML else { return false }
        return parsedTargetML > 0
    }

    private var todayTotalML: Double {
        let calendar = Calendar.autoupdatingCurrent
        return summaryEntries
            .filter { calendar.isDateInToday($0.date) }
            .reduce(0) { $0 + max(0, $1.volume) }
    }

    private var footerText: String? {
        let currentGoalText = activeGoals.first.map { String(localized: "Current goal: \(hydrationUnit.display($0.targetML, fractionDigits: 0...1)).") }
        let todayTotalText = String(localized: "Today's total so far is \(hydrationUnit.display(todayTotalML, fractionDigits: 0...1)).")
        guard let currentGoalText else { return todayTotalText }
        return "\(todayTotalText) \(currentGoalText)"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        TextField("Target", text: $targetText)
                            .keyboardType(.decimalPad)
                            .focused($isFieldFocused)
                            .accessibilityIdentifier(AccessibilityIdentifiers.healthNewHydrationGoalTargetField)

                        Text(hydrationUnit.unitLabel)
                            .foregroundStyle(.secondary)
                            .fontWeight(.semibold)
                    }
                    .appGroupedListRow(position: .single)
                } footer: {
                    if let footerText {
                        Text(footerText)
                    }
                }
            }
            .navigationTitle("Hydration Goal")
            .toolbarTitleDisplayMode(.inlineLarge)
            .scrollContentBackground(.hidden)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", systemImage: "checkmark", role: .confirm) {
                        save()
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.healthNewHydrationGoalSaveButton)
                    .labelStyle(.iconOnly)
                    .disabled(!canSave)
                }
            }
            .onAppear {
                if targetText.isEmpty, let activeGoal = activeGoals.first {
                    let converted = hydrationUnit.fromML(activeGoal.targetML)
                    targetText = hydrationUnit == .ml
                        ? Int(converted.rounded()).formatted(.number)
                        : converted.formatted(.number.precision(.fractionLength(0...1)))
                }
                isFieldFocused = true
            }
            .simultaneousGesture(
                TapGesture().onEnded {
                    dismissKeyboard()
                }
            )
        }
    }

    private func save() {
        guard let parsedTargetML, parsedTargetML > 0 else { return }

        let calendar = Calendar.autoupdatingCurrent
        let todayStart = calendar.startOfDay(for: .now)

        if let activeGoal = activeGoals.first {
            if activeGoal.startedOnDay == todayStart {
                context.delete(activeGoal)
            } else {
                activeGoal.endedOnDay = calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
            }
        }

        let goal = HydrationGoal(startedOnDay: todayStart, targetML: parsedTargetML)
        context.insert(goal)
        try? HydrationDay.reconcileAll(context: context)
        saveContext(context: context)
        HealthMetricWidgetReloader.reloadHydration()
        Haptics.selection()
        dismiss()
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        HydrationGoalHistoryView()
    }
}

import SwiftUI
import SwiftData

func compactStepsText(_ steps: Int) -> String {
    steps.formatted(.number.notation(.compactName).precision(.fractionLength(0...1))).lowercased()
}

struct StepsGoalSummaryCard: View {
    let activeGoal: StepsGoal?
    let todayEntry: HealthStepsDistance?
    let hasGoalHistory: Bool
    let action: () -> Void

    private var titleText: String {
        guard let activeGoal else { return String(localized: "No active goal") }
        return String(localized: "\(compactStepsText(activeGoal.targetSteps)) steps")
    }

    private var subtitleText: String? {
        guard let activeGoal else { return nil }
        guard let todayEntry else { return nil }
        if todayEntry.goalCompleted { return String(localized: "Achieved today") }
        let remainingSteps = max(activeGoal.targetSteps - todayEntry.stepCount, 0)
        return String(localized: "\(remainingSteps.formatted(.number)) steps left today")
    }

    private var emptyStateText: String {
        hasGoalHistory ? String(localized: "Tap to view your goal history.") : String(localized: "Tap to create a steps goal.")
    }

    var body: some View {
        Button(action: action) {
            Group {
                if activeGoal != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "target")
                                .font(.subheadline)
                            Text("Steps Goal")
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
                            Text("Steps Goal")
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
    }
}

struct StepsGoalHistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(StepsGoal.history) private var goals: [StepsGoal]
    @Query(HealthStepsDistance.history) private var entries: [HealthStepsDistance]

    @State private var showNewStepsGoalSheet = false

    var body: some View {
        List {
            ForEach(goals) { goal in
                StepsGoalHistoryRow(goal: goal, entries: entries)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            deleteGoal(goal)
                        }
                    }
            }
        }
        .navigationTitle("Steps Goals")
        .toolbarTitleDisplayMode(.inline)
        .listStyle(.plain)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Haptics.selection()
                    showNewStepsGoalSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title3)
                }
            }
        }
        .sheet(isPresented: $showNewStepsGoalSheet) {
            NewStepsGoalView()
                .presentationDetents([.fraction(0.35)])
                .presentationBackground(Color(.systemBackground))
        }
        .overlay {
            if goals.isEmpty {
                ContentUnavailableView("No Steps Goals", systemImage: "target", description: Text("Your saved and previous steps goals will appear here."))
            }
        }
    }

    private func deleteGoal(_ goal: StepsGoal) {
        Haptics.selection()
        let wasActive = goal.endedOnDay == nil
        context.delete(goal)
        if wasActive {
            try? StepsGoalEvaluator.reevaluateAchievement(forDay: .now, context: context, trigger: .goalChange)
            try? StepsCoachingEvaluator.reconcileTodayForGoalChange(context: context)
        }
        saveContext(context: context)
        HealthMetricWidgetReloader.reloadSteps()
    }
}

private struct StepsGoalHistoryRow: View {
    let goal: StepsGoal
    let entries: [HealthStepsDistance]

    private var isActive: Bool {
        goal.endedOnDay == nil
    }

    private var achievedDays: Int {
        entries.filter { $0.goalCompleted && goal.contains(day: $0.date) }.count
    }

    private var periodText: String {
        if let endedOnDay = goal.endedOnDay {
            return "\(formattedRecentDay(goal.startedOnDay)) - \(formattedRecentDay(endedOnDay))"
        }
        return String(localized: "Started \(formattedRecentDay(goal.startedOnDay))")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("\(compactStepsText(goal.targetSteps)) steps")
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

            Divider()

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12, alignment: .top)], spacing: 12) {
                SummaryStatCard(title: String(localized: "Target"), text: "\(goal.targetSteps.formatted(.number)) steps")
                SummaryStatCard(title: String(localized: "Achieved Days"), text: achievedDays.formatted(.number))
            }
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
    }

    private var goalStatusBadgeTitle: String {
        isActive ? String(localized: "Active") : String(localized: "Ended")
    }

    private var goalStatusBadgeColor: Color {
        isActive ? .green : .secondary
    }
}

struct NewStepsGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(HealthStepsDistance.summary) private var summaryEntries: [HealthStepsDistance]
    @Query(StepsGoal.active) private var activeGoals: [StepsGoal]
    @FocusState private var isFieldFocused: Bool

    @State private var targetStepsText = ""

    private var parsedTargetSteps: Int? {
        let trimmed = targetStepsText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let formatter = NumberFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.numberStyle = .decimal
        return formatter.number(from: trimmed)?.intValue
    }

    private var canSave: Bool {
        guard let parsedTargetSteps else { return false }
        return parsedTargetSteps > 0
    }

    private var latestEntry: HealthStepsDistance? {
        summaryEntries.first
    }

    private var footerText: String? {
        let calendar = Calendar.autoupdatingCurrent
        let currentGoalText = activeGoals.first.map { String(localized: "Current goal: \($0.targetSteps.formatted(.number)) steps.") }

        guard let latestEntry else {
            return currentGoalText
        }

        let stepsText: String
        if calendar.isDateInToday(latestEntry.date) {
            stepsText = String(localized: "Today's current total is \(latestEntry.stepCount.formatted(.number)) steps.")
        } else {
            stepsText = String(localized: "Latest total on \(formattedRecentDay(latestEntry.date)) was \(latestEntry.stepCount.formatted(.number)) steps.")
        }

        guard let currentGoalText else { return stepsText }
        return "\(stepsText) \(currentGoalText)"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        TextField("Target Steps", text: $targetStepsText)
                            .keyboardType(.numberPad)
                            .focused($isFieldFocused)

                        Text("steps")
                            .foregroundStyle(.secondary)
                            .fontWeight(.semibold)
                    }
                } footer: {
                    if let footerText {
                        Text(footerText)
                    }
                }
            }
            .navigationTitle("Steps Goal")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", systemImage: "checkmark", role: .confirm) {
                        save()
                    }
                    .labelStyle(.iconOnly)
                    .disabled(!canSave)
                }
            }
            .onAppear {
                if targetStepsText.isEmpty, let activeGoal = activeGoals.first {
                    targetStepsText = activeGoal.targetSteps.formatted(.number)
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
        guard let parsedTargetSteps, parsedTargetSteps > 0 else { return }

        let calendar = Calendar.autoupdatingCurrent
        let todayStart = calendar.startOfDay(for: .now)

        if let activeGoal = activeGoals.first {
            if activeGoal.startedOnDay == todayStart {
                context.delete(activeGoal)
            } else {
                activeGoal.endedOnDay = calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
            }
        }

        let goal = StepsGoal(startedOnDay: todayStart, targetSteps: parsedTargetSteps)
        context.insert(goal)
        try? StepsGoalEvaluator.reevaluateAchievement(forDay: todayStart, context: context, trigger: .goalChange)
        try? StepsCoachingEvaluator.reconcileTodayForGoalChange(context: context)
        saveContext(context: context)
        HealthMetricWidgetReloader.reloadSteps()
        Haptics.selection()
        dismiss()
    }
}

#Preview {
    NavigationStack {
        StepsGoalHistoryView()
            .sampleDataContainer()
    }
}

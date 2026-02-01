import SwiftUI
import SwiftData

struct WorkoutSplitView: View {
    @Environment(\.modelContext) private var context
    @Query private var splits: [WorkoutSplit]
    private let appRouter = AppRouter.shared
    @State private var showInactiveSplits = false
    @State private var planPickerDay: WorkoutSplitDay?

    private var activeSplit: WorkoutSplit? {
        splits.first { $0.isActive }
    }

    private var inactiveSplits: [WorkoutSplit] {
        splits.filter { !$0.isActive }
    }

    var body: some View {
        List {
            if !splits.isEmpty {
                Section {
                    if let activeSplit {
                        SplitRowView(split: activeSplit, allSplits: splits)
                        .accessibilityIdentifier("workoutSplitActiveRow")
                        ActiveSplitSummaryView(split: activeSplit, planPickerDay: $planPickerDay)
                    } else {
                        ContentUnavailableView("No Active Split", systemImage: "calendar.badge.plus", description: Text("Set one of your other splits as active or make a new one."))
                            .accessibilityIdentifier("workoutSplitNoActiveView")
                    }
                }
                .listRowSeparator(.hidden)

                if !inactiveSplits.isEmpty {
                    Section {
                        if showInactiveSplits {
                            ForEach(inactiveSplits) { split in
                                SplitRowView(split: split, allSplits: splits)
                                .accessibilityIdentifier("workoutSplitInactiveRow-\(split.title)")
                            }
                            .onDelete(perform: deleteInactiveSplits)
                        }
                    } header: {
                        otherSplitsHeader
                    }
                    .listRowSeparator(.hidden)
                }
            }
        }
        .accessibilityIdentifier("workoutSplitList")
        .navigationTitle("Workout Split")
        .toolbarTitleDisplayMode(.inline)
        .listStyle(.plain)
        .safeAreaBar(edge: .bottom, alignment: .trailing) {
            Menu("Create New Split", systemImage: "plus") {
                Button {
                    createSplit(mode: .weekly)
                } label: {
                        Label("Weekly Split", systemImage: "calendar.badge")
                        Text("Same workout on the same day every week.")
                }
                .accessibilityIdentifier("workoutSplitCreateWeeklyButton")
                Button {
                    createSplit(mode: .rotation)
                } label: {
                        Label("Rotation Split", systemImage: "arrow.2.circlepath")
                        Text("A repeating workout cycle not tied to the calendar.")
                }
                .accessibilityIdentifier("workoutSplitCreateRotationButton")
            }
            .menuOrder(.fixed)
            .font(.title3)
            .fontWeight(.semibold)
            .buttonStyle(.glassProminent)
            .labelStyle(.titleAndIcon)
            .accessibilityIdentifier("workoutSplitCreateButton")
            .accessibilityHint("Creates a new workout split.")
            .padding()
        }
        .overlay {
            if splits.isEmpty {
                ContentUnavailableView("No Splits", systemImage: "calendar.badge.plus", description: Text("Create a workout split to plan your training routine."))
                    .accessibilityIdentifier("workoutSplitEmptyState")
            }
        }
        .sheet(item: $planPickerDay) { day in
            SplitDayPlanPickerSheet(splitDay: day)
        }
    }

    private var otherSplitsHeader: some View {
        Button {
            withAnimation(.snappy) {
                showInactiveSplits.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Text("Inactive Splits")
                    .bold()
                if !inactiveSplits.isEmpty {
                    Text("(\(inactiveSplits.count))")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: showInactiveSplits ? "chevron.down" : "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .font(.title3)
            .fontWeight(.semibold)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("workoutSplitInactiveToggle")
        .accessibilityLabel(showInactiveSplits ? "Collapse other splits" : "Expand other splits")
        .accessibilityHint("Shows or hides inactive splits.")
    }

    private func createSplit(mode: SplitMode) {
        Haptics.selection()
        let split = WorkoutSplit(mode: mode)
        if splits.isEmpty {
            split.isActive = true
        }

        switch mode {
        case .weekly:
            split.days = (1...7).map { weekday in
                WorkoutSplitDay(weekday: weekday, split: split)
            }
        case .rotation:
            split.days = [
                WorkoutSplitDay(index: 0, split: split)
            ]
        }
        context.insert(split)
        saveContext(context: context)
        appRouter.navigate(to: .splitDettail(split))
    }

    private func deleteInactiveSplits(at offsets: IndexSet) {
        guard !offsets.isEmpty else { return }
        Haptics.selection()
        let splitsToDelete = offsets.map { inactiveSplits[$0] }
        for split in splitsToDelete {
            context.delete(split)
        }
        saveContext(context: context)
    }
}

private struct SplitDayPlanPickerSheet: View {
    @Bindable var splitDay: WorkoutSplitDay

    var body: some View {
        WorkoutPlanPickerView(selectedPlan: $splitDay.workoutPlan)
    }
}

private struct ActiveSplitSummaryView: View {
    let split: WorkoutSplit
    @Binding var planPickerDay: WorkoutSplitDay?

    var body: some View {
        let day = split.todaysSplitDay

        VStack(alignment: .leading, spacing: 8) {
            if let day {
                if day.isRestDay {
                    ContentUnavailableView("Enjoy your day off!", systemImage: "zzz")
                        .accessibilityIdentifier("workoutSplitRestDayUnavailable")
                } else if let plan = day.workoutPlan {
                    WorkoutPlanRowView(workoutPlan: plan, showsUseOnly: true)
                        .accessibilityIdentifier("workoutSplitActivePlanRow")
                } else {
                    noPlanSelectedView(for: day)
                }
            } else {
                ContentUnavailableView("No split day configured", systemImage: "calendar.badge.exclamationmark")
                    .accessibilityIdentifier("workoutSplitNoDayConfigured")
            }
        }
        .padding(.vertical, 6)
        .accessibilityIdentifier("workoutSplitActiveSummary")
    }

    private func noPlanSelectedView(for day: WorkoutSplitDay) -> some View {
        Button {
            Haptics.selection()
            planPickerDay = day
        } label: {
            ContentUnavailableView(
                "No plan selected for this day",
                systemImage: "list.bullet.clipboard",
                description: Text("Tap to choose a workout plan.")
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("workoutSplitSelectPlanButton")
        .accessibilityHint("Selects a workout plan for this day.")
    }
}

private struct SplitRowView: View {
    @Environment(\.modelContext) private var context
    let split: WorkoutSplit
    let allSplits: [WorkoutSplit]
    private let appRouter = AppRouter.shared

    var body: some View {
        Button {
            appRouter.navigate(to: .splitDettail(split))
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(titleText)
                        .font(.headline)
                    Text(subtitleText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if split.isActive {
                    activeControls
                } else {
                    setActiveButton
                }
            }
        }
        .swipeActions(edge: .trailing) {
            if split.isActive {
                Button {
                    setInactive()
                } label: {
                    Label("Set Inactive", systemImage: "xmark.circle")
                }
                .tint(.orange)
                .accessibilityIdentifier("workoutSplitSetInactiveButton")
                .accessibilityHint("Makes this split inactive.")
            }
        }
    }

    private var titleText: String {
        if split.isActive {
            return activeSplitTitle
        }
        return split.title.isEmpty ? "Untitled Split" : split.title
    }

    private var subtitleText: String {
        if split.isActive {
            return activeSplitSubtitle
        }
        switch split.mode {
        case .weekly:
            return "Weekly"
        case .rotation:
            return "Rotation · \(split.days.count) day cycle"
        }
    }

    private var activeSplitTitle: String {
        guard let day = split.todaysSplitDay else { return "Unnamed split day" }
        if day.isRestDay {
            return "Rest Day"
        }
        let name = day.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Unnamed split day" : name
    }

    private var activeSplitSubtitle: String {
        switch split.mode {
        case .weekly:
            return "Weekly · \(weeklyScheduleStatus)"
        case .rotation:
            let count = max(1, split.sortedDays.count)
            let dayNumber = (split.todaysDayIndex ?? 0) + 1
            return "Rotation · Cycle Day \(dayNumber) of \(count)"
        }
    }

    private var weeklyScheduleStatus: String {
        let offset = split.normalizedWeeklyOffset
        let behindDays = abs(offset)
        return behindDays == 0 ? "On schedule" : "\(behindDays) day\(behindDays == 1 ? "" : "s") behind"
    }

    private var activeControls: some View {
        Group {
            if split.mode == .weekly {
                weeklyOffsetControls
            } else {
                rotationAdvanceControls
            }
        }
    }

    private var weeklyOffsetControls: some View {
        HStack(spacing: 8) {
            Button("Missed Day", systemImage: "calendar.badge.exclamationmark") {
                Haptics.selection()
                split.missedDay()
                saveContext(context: context)
            }
            .accessibilityIdentifier("workoutSplitMissedDayButton")
            .accessibilityHint("Moves the weekly split back by one day.")

            Button("Reset Offset", systemImage: "arrow.counterclockwise") {
                Haptics.selection()
                split.resetSplit()
                saveContext(context: context)
            }
            .disabled(split.normalizedWeeklyOffset == 0)
            .accessibilityIdentifier("workoutSplitResetOffsetButton")
            .accessibilityHint("Resets the weekly split offset to today.")
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .controlSize(.small)
        .fontWeight(.semibold)
    }

    private var rotationAdvanceControls: some View {
        HStack(spacing: 8) {
            Button("Previous", systemImage: "chevron.left") {
                Haptics.selection()
                split.updateCurrentIndex(advanced: false)
                saveContext(context: context)
            }
            .accessibilityIdentifier("workoutSplitRotationPreviousButton")
            .accessibilityHint("Moves back one day in the rotation.")

            Button("Advance", systemImage: "chevron.right") {
                Haptics.selection()
                split.updateCurrentIndex(advanced: true)
                saveContext(context: context)
            }
            .accessibilityIdentifier("workoutSplitRotationAdvanceButton")
            .accessibilityHint("Moves forward one day in the rotation.")
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .controlSize(.small)
        .fontWeight(.semibold)
    }

    private var setActiveButton: some View {
        Button("Set Active", systemImage: "checkmark.circle") {
            withAnimation(.smooth) {
                setActive()
            }
        }
        .buttonStyle(.glassProminent)
        .foregroundStyle(.blue)
        .fontWeight(.semibold)
        .labelStyle(.titleOnly)
        .accessibilityIdentifier("workoutSplitSetActiveButton")
        .accessibilityHint("Makes this split active.")
    }

    private func setActive() {
        Haptics.selection()
        for item in allSplits where item !== split {
            if item.isActive {
                item.isActive = false
            }
        }
        split.isActive = true
        if split.mode == .rotation {
            split.rotationCurrentIndex = 0
            split.rotationLastUpdatedDate = Calendar.current.startOfDay(for: .now)
        }
        saveContext(context: context)
    }

    private func setInactive() {
        Haptics.selection()
        withAnimation(.smooth) {
            split.isActive = false
        }
        saveContext(context: context)
    }
}

#Preview {
    NavigationStack {
        WorkoutSplitView()
    }
    .sampleDataContainer()
}

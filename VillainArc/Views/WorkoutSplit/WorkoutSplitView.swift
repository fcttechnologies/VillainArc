import SwiftUI
import SwiftData

struct WorkoutSplitView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query private var splits: [WorkoutSplit]
    private let appRouter = AppRouter.shared
    @State private var planPickerDay: WorkoutSplitDay?
    @State private var showSplitBuilder = false

    private var activeSplit: WorkoutSplit? {
        splits.first { $0.isActive }
    }

    private var inactiveSplits: [WorkoutSplit] {
        splits.filter { !$0.isActive }
    }

    init(autoPresentBuilder: Bool = false) {
        _showSplitBuilder = State(initialValue: autoPresentBuilder)
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
                        ForEach(inactiveSplits) { split in
                            SplitRowView(split: split, allSplits: splits)
                                .accessibilityIdentifier("workoutSplitInactiveRow-\(split.title)")
                        }
                        .onDelete(perform: deleteInactiveSplits)
                    } header: {
                        Text("Inactive Splits")
                            .font(.title3)
                            .bold()
                            .foregroundStyle(.primary)
                            .textCase(nil)
                    }
                    .listRowSeparator(.hidden)
                }
            }
        }
        .accessibilityIdentifier("workoutSplitList")
        .navigationTitle("Workout Split")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            if let activeSplit {
                ToolbarItem(placement: .topBarTrailing) {
                    activeSplitActionsMenu(for: activeSplit)
                }
            }
            ToolbarSpacer(.flexible, placement: .bottomBar)
            ToolbarItem(placement: .bottomBar) {
                Button("Create New Split", systemImage: "plus") {
                    Haptics.selection()
                    showSplitBuilder = true
                }
                .accessibilityIdentifier("workoutSplitCreateButton")
                .accessibilityHint("Creates a new workout split.")
            }
        }
        .listStyle(.plain)
        .overlay {
            if splits.isEmpty {
                ContentUnavailableView("No Splits", systemImage: "calendar.badge.plus", description: Text("Create a workout split to plan your training routine."))
                    .accessibilityIdentifier("workoutSplitEmptyState")
            }
        }
        .onAppear {
            refreshRotationIfNeeded()
            Task { await IntentDonations.donateTrainingSummary() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            refreshRotationIfNeeded()
        }
        .sheet(item: $planPickerDay) { day in
            SplitDayPlanPickerSheet(splitDay: day)
        }
        .sheet(isPresented: $showSplitBuilder) {
            SplitBuilderView()
        }
    }



    @ViewBuilder
    private func activeSplitActionsMenu(for split: WorkoutSplit) -> some View {
        Menu("Split Actions", systemImage: "ellipsis") {
            switch split.mode {
            case .weekly:
                Button {
                    missedDay(for: split)
                } label: {
                    Label("Missed a Day", systemImage: "calendar.badge.exclamationmark")
                    Text("Moves the weekly split back by one day.")
                }
                .accessibilityIdentifier("workoutSplitMissedDayButton")
                .accessibilityHint("Moves the weekly split back by one day.")

                if split.normalizedWeeklyOffset != 0 {
                    Button {
                        resetOffset(for: split)
                    } label: {
                        Label("Reset Offset", systemImage: "arrow.counterclockwise")
                        Text("Returns the weekly split to today.")
                    }
                    .accessibilityIdentifier("workoutSplitResetOffsetButton")
                    .accessibilityHint("Resets the weekly split offset to today.")
                }
            case .rotation:
                Button {
                    updateRotation(for: split, advanced: false)
                } label: {
                    Label("Missed One Day", systemImage: "chevron.left")
                    Text("Moves back one day in the rotation.")
                }
                .accessibilityIdentifier("workoutSplitRotationPreviousButton")
                .accessibilityHint("Moves back one day in the rotation.")

                Button {
                    updateRotation(for: split, advanced: true)
                } label: {
                    Label("Skip Day", systemImage: "chevron.right")
                    Text("Moves forward one day in the rotation.")
                }
                .accessibilityIdentifier("workoutSplitRotationAdvanceButton")
                .accessibilityHint("Moves forward one day in the rotation.")
            }
        }
        .menuOrder(.fixed)
        .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitActiveActionsButton)
        .accessibilityLabel("Split actions")
        .accessibilityHint("Shows actions for the active split.")
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

    private func refreshRotationIfNeeded() {
        guard let split = splits.first(where: { $0.isActive }), split.mode == .rotation else { return }
        split.refreshRotationIfNeeded(context: context)
    }

    private func missedDay(for split: WorkoutSplit) {
        Haptics.selection()
        split.missedDay()
        saveContext(context: context)
    }

    private func resetOffset(for split: WorkoutSplit) {
        Haptics.selection()
        split.resetSplit()
        saveContext(context: context)
    }

    private func updateRotation(for split: WorkoutSplit, advanced: Bool) {
        Haptics.selection()
        split.updateCurrentIndex(advanced: advanced)
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
                    ContentUnavailableView("Enjoy your day off!", systemImage: "zzz", description: Text("Rest days are perfect for unwinding and recharging."))
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
                        .font(split.isActive ? .title : .title3)
                        .bold()
                        .lineLimit(1)
                    Text(subtitleText)
                        .font(split.isActive ? .title3 : .headline)
                        .foregroundStyle(.secondary)
                        .fontWeight(.semibold)
                }
                Spacer()
                if !split.isActive {
                    setActiveButton
                }
            }
            .fontDesign(.rounded)
        }
        .swipeActions(edge: .trailing) {
            if split.isActive {
                Button("Set Inactive", systemImage: "xmark", role: .destructive) {
                    setInactive()
                }
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

    private var setActiveButton: some View {
        Button("Set Active", systemImage: "checkmark.circle") {
            withAnimation(.smooth) {
                setActive()
            }
        }
        .buttonStyle(.glassProminent)
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

import SwiftUI
import SwiftData

struct WorkoutSplitView: View {
    @Environment(\.modelContext) private var context
    @Query private var splits: [WorkoutSplit]
    private let appRouter = AppRouter.shared
    @State private var showInactiveSplits = false

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
                        splitRow(for: activeSplit, isActive: true)
                            .accessibilityIdentifier("workoutSplitActiveRow")
                        activeSplitSummary(for: activeSplit)
                    } else {
                        Text("No active split.")
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("workoutSplitNoActiveRow")
                    }
                } header: {
                    Text("Active Split")
                        .bold()
                        .font(.title3)
                }
                .listRowSeparator(.hidden)

                Section {
                    if showInactiveSplits {
                        if inactiveSplits.isEmpty {
                            Text("No other splits yet.")
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("workoutSplitNoInactiveRow")
                        } else {
                            ForEach(Array(inactiveSplits.enumerated()), id: \.element) { index, split in
                                splitRow(for: split, isActive: false)
                                    .accessibilityIdentifier("workoutSplitInactiveRow-\(index)")
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button("Set Active", systemImage: "checkmark.circle") {
                                            setActive(split)
                                        }
                                        .tint(.green)
                                    }
                            }
                        }
                    }
                } header: {
                    otherSplitsHeader
                }
                .listRowSeparator(.hidden)
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
    }

    @ViewBuilder
    private func splitRow(for split: WorkoutSplit, isActive: Bool) -> some View {
        Button {
            appRouter.navigate(to: .splitDettail(split))
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(splitTitle(for: split))
                        .font(.headline)
                    Text(splitSubtitle(for: split))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isActive {
                    Button("Active", systemImage: "checkmark.circle.fill") {
                        withAnimation(.smooth) {
                            split.isActive = false
                        }
                        saveContext(context: context)
                    }
                    .buttonStyle(.glassProminent)
                    .labelStyle(.titleOnly)
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("workoutSplitSetInactiveButton")
                    .accessibilityHint("Makes this split inactive.")
                } else {
                    Button("Set Active", systemImage: "checkmark.circle") {
                        withAnimation(.smooth) {
                            setActive(split)
                        }
                    }
                    .buttonStyle(.glass)
                    .foregroundStyle(.blue)
                    .fontWeight(.semibold)
                    .labelStyle(.titleOnly)
                    .accessibilityIdentifier("workoutSplitSetActiveButton")
                    .accessibilityHint("Makes this split active.")
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func splitTitle(for split: WorkoutSplit) -> String {
        split.title.isEmpty ? "Untitled Split" : split.title
    }

    private func splitSubtitle(for split: WorkoutSplit) -> String {
        switch split.mode {
        case .weekly:
            return "Weekly"
        case .rotation:
            return "Rotation · \(split.days.count) day cycle"
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

    @ViewBuilder
    private func activeSplitSummary(for split: WorkoutSplit) -> some View {
        let summary = activeSplitSummaryInfo(for: split)

        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(summary.title)
                if let secondary = summary.secondary {
                    Text("•")
                    Text(secondary)
                }
            }
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            
            Text(summary.detail)
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.bottom)

            if split.mode == .weekly {
                weeklyOffsetControls(for: split)
            } else {
                rotationAdvanceControls(for: split)
            }
        }
        .padding(.vertical, 6)
        .accessibilityIdentifier("workoutSplitActiveSummary")
    }

    private func activeSplitSummaryInfo(for split: WorkoutSplit) -> (title: String, detail: String, secondary: String?) {
        switch split.mode {
        case .weekly:
            let detail = splitDayLabel(for: split.todaysSplitDay)
            let offset = split.normalizedWeeklyOffset
            let behindDays = abs(offset)
            let offsetText = behindDays == 0 ? "On schedule" : "\(behindDays) day\(behindDays == 1 ? "" : "s") behind"
            return (title: "Today", detail: detail, secondary: offsetText)
        case .rotation:
            let count = max(1, split.sortedDays.count)
            let dayNumber = (split.todaysDayIndex ?? 0) + 1
            let detail = splitDayLabel(for: split.todaysSplitDay)
            return (title: "Cycle Day \(dayNumber) of \(count)", detail: detail, secondary: nil)
        }
    }

    private func splitDayLabel(for day: WorkoutSplitDay?) -> String {
        guard let day else { return "No day configured" }
        if day.isRestDay {
            return "Rest Day"
        }
        if !day.name.isEmpty {
            return day.name
        }
        if let template = day.template {
            return template.name
        }
        return "No template assigned"
    }

    private func weeklyOffsetControls(for split: WorkoutSplit) -> some View {
        HStack(spacing: 12) {
            Button("Missed Day", systemImage: "calendar.badge.exclamationmark") {
                Haptics.selection()
                split.missedDay()
                saveContext(context: context)
            }
            .buttonSizing(.flexible)
            .accessibilityIdentifier("workoutSplitMissedDayButton")
            .accessibilityHint("Moves the weekly split back by one day.")

            Button("Reset Offset", systemImage: "arrow.counterclockwise") {
                Haptics.selection()
                split.resetSplit()
                saveContext(context: context)
            }
            .buttonSizing(.flexible)
            .disabled(split.normalizedWeeklyOffset == 0)
            .accessibilityIdentifier("workoutSplitResetOffsetButton")
            .accessibilityHint("Resets the weekly split offset to today.")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func rotationAdvanceControls(for split: WorkoutSplit) -> some View {
        HStack(spacing: 12) {
            Button("Previous", systemImage: "chevron.left") {
                Haptics.selection()
                split.updateCurrentIndex(advanced: false)
                saveContext(context: context)
            }
            .buttonSizing(.flexible)
            .accessibilityIdentifier("workoutSplitRotationPreviousButton")
            .accessibilityHint("Moves back one day in the rotation.")

            Button("Advance", systemImage: "chevron.right") {
                Haptics.selection()
                split.updateCurrentIndex(advanced: true)
                saveContext(context: context)
            }
            .buttonSizing(.flexible)
            .accessibilityIdentifier("workoutSplitRotationAdvanceButton")
            .accessibilityHint("Moves forward one day in the rotation.")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func weekdayName(for weekday: Int) -> String {
        let names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return names[max(1, min(weekday, 7)) - 1]
    }

    private func setActive(_ split: WorkoutSplit) {
        Haptics.selection()
        for item in splits where item !== split {
            if item.isActive {
                item.isActive = false
            }
        }
        split.isActive = true
        saveContext(context: context)
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
}

#Preview {
    NavigationStack {
        WorkoutSplitView()
    }
    .sampleDataConainer()
}

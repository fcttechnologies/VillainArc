import SwiftUI
import SwiftData

struct WorkoutSplitView: View {
    @Environment(\.modelContext) private var context
    @Query private var splits: [WorkoutSplit]
    @State private var showCreateSplit = false
    @State private var splitToEdit: WorkoutSplit?

    private var activeSplit: WorkoutSplit? {
        splits.first { $0.isActive }
    }

    private var inactiveSplits: [WorkoutSplit] {
        splits.filter { !$0.isActive }
    }

    var body: some View {
        List {
            if !splits.isEmpty {
                Section("Active Split") {
                    if let activeSplit {
                        splitRow(for: activeSplit, isActive: true)
                            .accessibilityIdentifier("workoutSplitActiveRow")
                    } else {
                        Text("No active split.")
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("workoutSplitNoActiveRow")
                    }
                }

                Section("Other Splits") {
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
        .navigationDestination(isPresented: $showCreateSplit) {
            if let splitToEdit {
                WorkoutSplitCreationView(split: splitToEdit)
            } else {
                Text("Unable to load split.")
            }
        }
    }

    @ViewBuilder
    private func splitRow(for split: WorkoutSplit, isActive: Bool) -> some View {
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
                Label("Active", systemImage: "checkmark.circle.fill")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)
            } else {
                Button("Set Active", systemImage: "checkmark.circle") {
                    setActive(split)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("workoutSplitSetActiveButton")
                .accessibilityHint("Makes this split active.")
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func splitTitle(for split: WorkoutSplit) -> String {
        split.title.isEmpty ? "Untitled Split" : split.title
    }

    private func splitSubtitle(for split: WorkoutSplit) -> String {
        let count = split.days.count
        let dayText = count == 1 ? "1 day" : "\(count) days"
        switch split.mode {
        case .weekly:
            return "Weekly"
        case .rotation:
            return "Rotation · \(dayText) cycle"
        }
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
        splitToEdit = split
        showCreateSplit = true
    }
}

#Preview {
    NavigationStack {
        WorkoutSplitView()
    }
    .sampleDataConainer()
}

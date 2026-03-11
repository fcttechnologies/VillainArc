import SwiftUI
import SwiftData

struct WorkoutSplitListView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var splits: [WorkoutSplit]

    @State private var path: [WorkoutSplit]
    @State private var showSplitBuilder = false
    @State private var pendingDeletionIDs: Set<PersistentIdentifier> = []

    init(initialPath: [WorkoutSplit] = []) {
        _path = State(initialValue: initialPath)
    }

    private var visibleSplits: [WorkoutSplit] {
        splits.filter { !pendingDeletionIDs.contains($0.persistentModelID) }
    }

    private var activeSplit: WorkoutSplit? {
        visibleSplits.first { $0.isActive }
    }

    private var inactiveSplits: [WorkoutSplit] {
        visibleSplits.filter { !$0.isActive }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if !visibleSplits.isEmpty {
                    if let activeSplit {
                        Section {
                            Button {
                                dismiss()
                            } label: {
                                splitRowContent(for: activeSplit, isActive: true)
                            }
                            .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitActiveRow)
                            .accessibilityHint(AccessibilityText.workoutSplitRowHint)
                            .swipeActions(edge: .trailing) {
                                Button("Set Inactive", systemImage: "xmark", role: .destructive) {
                                    setInactive(activeSplit)
                                }
                                .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitSetInactiveButton)
                                .accessibilityHint(AccessibilityText.workoutSplitSetInactiveHint)
                            }
                        }
                        .listRowSeparator(.hidden)
                    }

                    if !inactiveSplits.isEmpty {
                        Section {
                            ForEach(inactiveSplits) { split in
                                HStack(spacing: 12) {
                                    Button {
                                        path.append(split)
                                    } label: {
                                        splitRowContent(for: split, isActive: false)
                                    }
                                    Button("Set Active", systemImage: "checkmark.circle") {
                                        withAnimation(.smooth) { setActive(split) }
                                    }
                                    .buttonStyle(.glassProminent)
                                    .fontWeight(.semibold)
                                    .labelStyle(.titleOnly)
                                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitSetActiveButton)
                                    .accessibilityHint(AccessibilityText.workoutSplitSetActiveHint)
                                }
                                .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitInactiveRow(split))
                                .accessibilityHint(AccessibilityText.workoutSplitRowHint)
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
            .listStyle(.plain)
            .overlay {
                if visibleSplits.isEmpty {
                    ContentUnavailableView(
                        "No Splits",
                        systemImage: "calendar.badge.plus",
                        description: Text("Create a workout split to plan your training routine.")
                    )
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitEmptyState)
                }
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitList)
            .navigationTitle("Workout Splits")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarSpacer(.flexible, placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) {
                    Button("Create New Split", systemImage: "plus") {
                        Haptics.selection()
                        showSplitBuilder = true
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitCreateButton)
                    .accessibilityHint(AccessibilityText.workoutSplitCreateHint)
                }
            }
            .sheet(isPresented: $showSplitBuilder) {
                SplitBuilderView { newSplit in
                    if newSplit.isActive {
                        dismiss()
                    } else {
                        path.append(newSplit)
                    }
                }
            }
            .navigationDestination(for: WorkoutSplit.self) { split in
                WorkoutSplitView(split: split)
            }
        }
    }

    // MARK: - Row Content

    private func splitRowContent(for split: WorkoutSplit, isActive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(splitTitle(for: split))
                .font(isActive ? .title : .title3)
                .bold()
                .lineLimit(1)
            Text(subtitleText(for: split, isActive: isActive))
                .font(isActive ? .title3 : .headline)
                .foregroundStyle(.secondary)
                .fontWeight(.semibold)
        }
        .fontDesign(.rounded)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func splitTitle(for split: WorkoutSplit) -> String {
        if split.title.isEmpty { return split.mode == .weekly ? "Weekly Split" : "Rotation Split" }
        return split.title
    }

    private func subtitleText(for split: WorkoutSplit, isActive: Bool) -> String {
        if isActive {
            switch split.mode {
            case .weekly:
                let offset = split.normalizedWeeklyOffset
                let behindDays = abs(offset)
                let status = behindDays == 0 ? "On schedule" : "\(behindDays) day\(behindDays == 1 ? "" : "s") behind"
                return "Weekly · \(status)"
            case .rotation:
                let count = max(1, split.sortedDays.count)
                let dayNumber = (split.todaysDayIndex ?? 0) + 1
                return "Rotation · Cycle Day \(dayNumber) of \(count)"
            }
        }
        switch split.mode {
        case .weekly: return "Weekly"
        case .rotation: return "Rotation · \(split.days?.count ?? 0) day cycle"
        }
    }

    // MARK: - Actions

    private func setActive(_ split: WorkoutSplit) {
        Haptics.selection()
        for item in visibleSplits where item !== split { item.isActive = false }
        split.isActive = true
        if split.mode == .rotation {
            split.rotationCurrentIndex = 0
            split.rotationLastUpdatedDate = Calendar.current.startOfDay(for: .now)
        }
        saveContext(context: context)
    }

    private func setInactive(_ split: WorkoutSplit) {
        Haptics.selection()
        withAnimation(.smooth) { split.isActive = false }
        saveContext(context: context)
    }

    private func deleteInactiveSplits(at offsets: IndexSet) {
        guard !offsets.isEmpty else { return }
        Haptics.selection()
        let current = inactiveSplits
        let toDelete: [WorkoutSplit] = offsets.compactMap { index in
            guard current.indices.contains(index) else { return nil }
            return current[index]
        }
        guard !toDelete.isEmpty else { return }
        pendingDeletionIDs.formUnion(toDelete.map { $0.persistentModelID })
        DispatchQueue.main.async {
            for split in toDelete { context.delete(split) }
            saveContext(context: context)
        }
    }
}

#Preview {
    WorkoutSplitListView()
        .sampleDataContainer()
}

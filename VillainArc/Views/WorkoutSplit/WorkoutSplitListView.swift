import SwiftUI
import SwiftData

struct WorkoutSplitListView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var splits: [WorkoutSplit]
    @State private var router = AppRouter.shared

    @State private var showSplitBuilder = false
    @State private var pendingDeletionIDs: Set<PersistentIdentifier> = []

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
        NavigationStack {
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
                        } header: {
                            Text("Active Split")
                                .font(.title3)
                                .bold()
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }

                    if !inactiveSplits.isEmpty {
                        Section {
                            ForEach(inactiveSplits) { split in
                                HStack(spacing: 12) {
                                    Button {
                                        dismiss()
                                        router.navigate(to: .workoutSplitDetail(split))
                                    } label: {
                                        splitRowContent(for: split, isActive: false)
                                    }
                                    Button("Set Active", systemImage: "checkmark.circle") {
                                        withAnimation(reduceMotion ? nil : .smooth) { setActive(split) }
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
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.plain)
            .sheetBackground()
            .overlay {
                if visibleSplits.isEmpty {
                    ContentUnavailableView("No Splits", systemImage: "calendar.badge.plus", description: Text("Create a workout split to plan your training routine.")
                    )
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitEmptyState)
                }
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.workoutSplitList)
            .navigationTitle("Workout Splits")
            .toolbarTitleDisplayMode(.inline)
            .sheet(isPresented: $showSplitBuilder) {
                SplitBuilderView { newSplit in
                    if newSplit.isActive {
                        dismiss()
                    } else {
                        dismiss()
                        router.navigate(to: .workoutSplitDetail(newSplit))
                    }
                }
                .presentationBackground(Color.sheetBg)
            }
        }
    }

    // MARK: - Row Content

    private func splitRowContent(for split: WorkoutSplit, isActive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(splitTitle(for: split))
                .font(isActive ? .title2 : .title3)
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
        if split.title.isEmpty { return split.mode.defaultTitle }
        return split.title
    }

    private func subtitleText(for split: WorkoutSplit, isActive: Bool) -> String {
        if isActive {
            let resolution = SplitScheduleResolver.resolve(split, context: context, syncProgress: false)
            if resolution.isPaused {
                return resolution.conditionStatusText ?? String(localized: "Paused until changed")
            }

            let base: String
            switch split.mode {
            case .weekly:
                let offset = split.normalizedWeeklyOffset
                let behindDays = abs(offset)
                let status: String
                switch behindDays {
                case 0:
                    status = String(localized: "On schedule")
                case 1:
                    status = String(localized: "1 day behind")
                default:
                    status = String(localized: "\(behindDays) days behind")
                }
                base = String(localized: "Weekly · \(status)")
            case .rotation:
                let count = max(1, split.sortedDays.count)
                let dayNumber = (resolution.dayIndex ?? 0) + 1
                base = String(localized: "Rotation · Cycle Day \(dayNumber) of \(count)")
            }

            return base
        }
        switch split.mode {
        case .weekly:
            return split.mode.displayName
        case .rotation:
            let cycleDays = split.days?.count ?? 0
            if cycleDays == 1 {
                return String(localized: "Rotation · 1 day cycle")
            }
            return String(localized: "Rotation · \(cycleDays) days cycle")
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
        SpotlightIndexer.index(workoutSplits: visibleSplits)
    }

    private func setInactive(_ split: WorkoutSplit) {
        Haptics.selection()
        withAnimation(reduceMotion ? nil : .smooth) { split.isActive = false }
        saveContext(context: context)
        SpotlightIndexer.index(workoutSplit: split)
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
        SpotlightIndexer.deleteWorkoutSplits(ids: toDelete.map(\.id))
        pendingDeletionIDs.formUnion(toDelete.map { $0.persistentModelID })
        DispatchQueue.main.async {
            for split in toDelete { context.delete(split) }
            saveContext(context: context)
        }
    }
}

#Preview(traits: .sampleData) {
    WorkoutSplitListView()
}

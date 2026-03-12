import SwiftUI
import SwiftData

struct WorkoutSplitSectionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(WorkoutSplit.active) private var activeSplits: [WorkoutSplit]
    @Query(WorkoutSplit.any) private var storedSplits: [WorkoutSplit]
    private let appRouter = AppRouter.shared

    private var activeSplit: WorkoutSplit? {
        activeSplits.first
    }

    private var hasAnySplit: Bool {
        !storedSplits.isEmpty
    }

    var body: some View {
        content
            .onAppear {
                refreshRotationIfNeeded()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                refreshRotationIfNeeded()
            }
    }

    @ViewBuilder
    private var content: some View {
        if !hasAnySplit {
            splitUnavailableView(title: "No Workout Split", description: "Create a split to plan your training days.", autoOpenBuilder: true) {
                await IntentDonations.donateCreateWorkoutSplit()
            }
                .accessibilityIdentifier(AccessibilityIdentifiers.recentWorkoutSplitEmptyState)
        } else if let activeSplit {
            if let day = activeSplit.todaysSplitDay {
                activeSplitCard(split: activeSplit, day: day)
                    .accessibilityIdentifier(AccessibilityIdentifiers.recentWorkoutSplitActiveRow)
            } else {
                splitUnavailableView(title: "No Split Day Configured", description: "Add days to your split to get started.") {
                    await IntentDonations.donateOpenWorkoutSplit()
                }
                    .accessibilityIdentifier(AccessibilityIdentifiers.recentWorkoutSplitNoDayState)
            }
        } else {
            splitUnavailableView(title: "No Active Split", description: "Set one of your splits as active.") {
                await IntentDonations.donateManageWorkoutSplits()
            }
                .accessibilityIdentifier(AccessibilityIdentifiers.recentWorkoutSplitNoActiveState)
        }
    }

    private func splitUnavailableView(title: String, description: String, autoOpenBuilder: Bool = false, onNavigate: @escaping () async -> Void = {}) -> some View {
        Button {
            appRouter.navigate(to: .workoutSplit(autoPresentBuilder: autoOpenBuilder))
            Task { await onNavigate() }
        } label: {
            SmallUnavailableView(sfIconName: "calendar.badge.exclamationmark", title: title, subtitle: description)
                .padding()
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(description)
        .accessibilityHint(AccessibilityText.workoutSplitUnavailableHint)
    }

    private func activeSplitCard(split: WorkoutSplit, day: WorkoutSplitDay) -> some View {
        let isRestDay = day.isRestDay
        let titleText = isRestDay ? "Today is your rest day" : activeSplitTitle(for: day)
        let subtitleText = isRestDay ? "Enjoy the day off." : activeSplitSubtitle(for: split)

        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(titleText)
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(subtitleText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !isRestDay, let plan = day.workoutPlan {
                Button {
                    appRouter.navigate(to: .workoutPlanDetail(plan, true))
                    Task { await IntentDonations.donateOpenTodaysPlan() }
                } label: {
                    Image(systemName: "list.clipboard")
                        .font(.title3)
                }
                .buttonStyle(.glass)
                .accessibilityIdentifier(AccessibilityIdentifiers.recentWorkoutSplitPlanButton(plan))
                .accessibilityLabel(AccessibilityText.workoutSplitPlanButtonLabel)
                .accessibilityHint(AccessibilityText.workoutSplitPlanButtonHint)
            }
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
        .contentShape(.rect)
        .onTapGesture {
            appRouter.navigate(to: .workoutSplit(autoPresentBuilder: false))
            Task { await IntentDonations.donateOpenWorkoutSplit() }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(titleText)
        .accessibilityValue(subtitleText)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(AccessibilityText.workoutSplitActiveRowHint)
    }

    private func activeSplitTitle(for day: WorkoutSplitDay) -> String {
        let name = day.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Unnamed split day" : name
    }

    private func activeSplitSubtitle(for split: WorkoutSplit) -> String {
        switch split.mode {
        case .weekly:
            return "Weekly · \(weeklyScheduleStatus(for: split))"
        case .rotation:
            let count = max(1, split.sortedDays.count)
            let dayNumber = (split.todaysDayIndex ?? 0) + 1
            return "Rotation · Cycle Day \(dayNumber) of \(count)"
        }
    }

    private func weeklyScheduleStatus(for split: WorkoutSplit) -> String {
        let offset = split.normalizedWeeklyOffset
        let behindDays = abs(offset)
        return behindDays == 0 ? "On schedule" : "\(behindDays) day\(behindDays == 1 ? "" : "s") behind"
    }

    private func refreshRotationIfNeeded() {
        guard let split = activeSplit, split.mode == .rotation else { return }
        split.refreshRotationIfNeeded(context: context)
    }
}

#Preview {
    NavigationStack {
        WorkoutSplitSectionView()
            .padding()
    }
    .sampleDataContainer()
}

#Preview {
    NavigationStack {
        WorkoutSplitSectionView()
            .padding()
    }
}

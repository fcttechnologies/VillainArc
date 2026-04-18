import SwiftUI
import SwiftData

struct WorkoutSplitSectionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(WorkoutSplit.active) private var activeSplits: [WorkoutSplit]
    @Query(WorkoutSplit.any) private var storedSplits: [WorkoutSplit]
    private let appRouter = AppRouter.shared

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
        if storedSplits.isEmpty {
            splitUnavailableView(title: String(localized: "No Workout Split"), description: String(localized: "Create a split to plan your training days."), autoOpenBuilder: true) {
                await IntentDonations.donateCreateWorkoutSplit()
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.recentWorkoutSplitEmptyState)
        } else if let activeSplit = activeSplits.first {
            let resolution = SplitScheduleResolver.resolve(activeSplit, context: context, syncProgress: false)

            if let day = resolution.splitDay {
                activeSplitCard(resolution: resolution, day: day)
                    .accessibilityIdentifier(AccessibilityIdentifiers.recentWorkoutSplitActiveRow)
            } else {
                splitUnavailableView(title: String(localized: "No Split Day Configured"), description: String(localized: "Add days to your split to get started.")) {
                    await IntentDonations.donateOpenWorkoutSplit()
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.recentWorkoutSplitNoDayState)
            }
        } else {
            splitUnavailableView(title: String(localized: "No Active Split"), description: String(localized: "Set one of your splits as active.")) {
                await IntentDonations.donateManageWorkoutSplits()
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.recentWorkoutSplitNoActiveState)
        }
    }
    
    private func splitUnavailableView(title: String, description: String, autoOpenBuilder: Bool = false, onNavigate: @escaping () async -> Void = {}) -> some View {
        Button {
            appRouter.push(to: .workoutSplit(autoPresentBuilder: autoOpenBuilder))
            Task { await onNavigate() }
        } label: {
            SmallUnavailableView(sfIconName: "calendar.badge.exclamationmark", title: title, subtitle: description)
                .padding()
                .appCardStyle()
                .tint(.primary)
        }
        .buttonStyle(.borderless)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(description)
        .accessibilityHint(AccessibilityText.workoutSplitUnavailableHint)
    }
    
    private func activeSplitCard(resolution: SplitScheduleResolution, day: WorkoutSplitDay) -> some View {
        let isPaused = resolution.isPaused
        let isRestDay = resolution.isRestDay
        let titleText = activeSplitTitle(for: resolution, day: day)
        let subtitleText = activeSplitSubtitle(for: resolution)
        
        return ZStack(alignment: .trailing) {
            Button {
                appRouter.push(to: .workoutSplit(autoPresentBuilder: false))
                Task { await IntentDonations.donateOpenWorkoutSplit() }
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(titleText)
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text(subtitleText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !isPaused, !isRestDay, day.workoutPlan != nil {
                        Color.clear
                            .frame(width: 44, height: 44)
                            .accessibilityHidden(true)
                    }
                }
                .padding()
                .appCardStyle()
                .tint(.primary)
            }
            .buttonStyle(.borderless)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(titleText)
            .accessibilityValue(subtitleText)
            .accessibilityHint(AccessibilityText.workoutSplitActiveRowHint)
            
            if !isPaused, !isRestDay, let plan = resolution.workoutPlan {
                Button {
                    appRouter.push(to: .workoutPlanDetail(plan, true))
                    Task { await IntentDonations.donateOpenTodaysPlan() }
                } label: {
                    Image(systemName: "list.clipboard")
                        .font(.title3)
                }
                .buttonStyle(.glass)
                .padding(.trailing, 12)
                .accessibilityIdentifier(AccessibilityIdentifiers.recentWorkoutSplitPlanButton(plan))
                .accessibilityLabel(AccessibilityText.workoutSplitPlanButtonLabel)
                .accessibilityHint(AccessibilityText.workoutSplitPlanButtonHint)
            }
        }
    }
    
    private func activeSplitTitle(for resolution: SplitScheduleResolution, day: WorkoutSplitDay) -> String {
        if resolution.isPaused {
            return String(localized: "Training is paused")
        }
        if resolution.isRestDay {
            return String(localized: "Today is your rest day")
        }

        let name = day.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? String(localized: "Unnamed split day") : name
    }
    
    private func activeSplitSubtitle(for resolution: SplitScheduleResolution) -> String {
        if resolution.isPaused {
            return resolution.conditionStatusText ?? String(localized: "Paused until changed")
        }

        switch resolution.split.mode {
        case .weekly:
            return String(localized: "Weekly · \(weeklyScheduleStatus(for: resolution.split))")
        case .rotation:
            let count = max(1, resolution.split.sortedDays.count)
            let dayNumber = (resolution.dayIndex ?? 0) + 1
            return String(localized: "Rotation · Cycle Day \(dayNumber) of \(count)")
        }
    }
    
    private func weeklyScheduleStatus(for split: WorkoutSplit) -> String {
        let offset = split.normalizedWeeklyOffset
        let behindDays = abs(offset)
        switch behindDays {
        case 0:
            return String(localized: "On schedule")
        case 1:
            return String(localized: "1 day behind")
        default:
            return String(localized: "\(behindDays) days behind")
        }
    }
    
    private func refreshRotationIfNeeded() {
        guard let split = activeSplits.first else { return }
        _ = SplitScheduleResolver.resolve(split, context: context)
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        WorkoutSplitSectionView()
            .padding()
    }
}

#Preview {
    NavigationStack {
        WorkoutSplitSectionView()
            .padding()
    }
}
